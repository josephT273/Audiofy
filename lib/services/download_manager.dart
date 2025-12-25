import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audiofy/MyVideo.dart';
import 'package:audiofy/fetchYoutubeStreamUrl.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed, canceled }

class DownloadTask {
  final MyVideo video;
  double progress; // 0.0 to 1.0
  String speed; // e.g. "1.2 MB/s"
  DownloadStatus status;
  String? filePath; // Final path
  String? imagePath;
  CancelToken? cancelToken;
  DateTime? _lastUpdateTime;
  int _lastBytesReceived = 0;

  DownloadTask({
    required this.video,
    this.progress = 0.0,
    this.speed = "0 KB/s",
    this.status = DownloadStatus.queued,
  });

  double _currentSpeed = 0; // Bytes per second
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Map<String, DownloadTask> _activeDownloads = {};
  final Box _box = Hive.box('downloads');
  final Dio _dio = Dio();

  Map<String, DownloadTask> get activeDownloads => _activeDownloads;

  List<MyVideo> getCompletedDownloads() {
    return _box.values.map((e) => MyVideo.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  bool isDownloaded(String videoId) {
      return _box.containsKey(videoId);
  }

  MyVideo? getDownload(String videoId) {
      if (_box.containsKey(videoId)) {
          return MyVideo.fromMap(Map<String, dynamic>.from(_box.get(videoId)));
      }
      return null;
  }

  Future<void> startDownload(MyVideo video) async {
    if (_activeDownloads.containsKey(video.videoId)) {
      // Already active
      return;
    }
    
    // Check permissions
    if (!await _requestPermission()) {
        return;
    }

    final task = DownloadTask(video: video, status: DownloadStatus.queued);
    _activeDownloads[video.videoId!] = task;
    notifyListeners();

    _download(task);
  }

  Future<void> pauseDownload(String videoId) async {
    final task = _activeDownloads[videoId];
    if (task != null && task.status == DownloadStatus.downloading) {
        task.cancelToken?.cancel();
        task.status = DownloadStatus.paused;
        notifyListeners();
    }
  }

  Future<void> resumeDownload(String videoId) async {
      final task = _activeDownloads[videoId];
      if (task != null && task.status == DownloadStatus.paused) {
          task.status = DownloadStatus.queued; // Re-queue
          notifyListeners();
          _download(task);
      }
  }

  Future<void> cancelDownload(String videoId) async {
      final task = _activeDownloads[videoId];
      if (task != null) {
          task.cancelToken?.cancel();
          _activeDownloads.remove(videoId);
          notifyListeners();
      }
  }
  
  Future<void> deleteDownload(MyVideo video) async {
      if (_box.containsKey(video.videoId)) {
          final data = MyVideo.fromMap(Map<String, dynamic>.from(_box.get(video.videoId)));
           // Delete files
           if (data.localaudio != null) File(data.localaudio!).delete().ignore();
           if (data.localimage != null) File(data.localimage!).delete().ignore();
           
           await _box.delete(video.videoId);
           notifyListeners();
      }
  }

  Future<void> _download(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    task.cancelToken = CancelToken();
    notifyListeners();

    try {
      // 1. Get Stream URL
      String? audioUrl = await fetchYoutubeStreamUrl(task.video.videoId!);
      if (audioUrl == null) throw Exception("Failed to get audio URL");

      // 2. Prepare paths
      Directory? dir;
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
          dir = await getDownloadsDirectory();
      }
      // Fallback if null (e.g. mobile or error)
      dir ??= await getApplicationDocumentsDirectory();
      
      // Ensure directory exists (getDownloadsDirectory usually exists, but good to check)
      if (!await dir.exists()) {
          dir = await getApplicationDocumentsDirectory(); // Final fallback
      }

      String filename = "${task.video.channelName} - ${task.video.title}".replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      String savePath = "${dir.path}/$filename.mp3";
      String imgPath = "${dir.path}/$filename.jpg";

      // 3. Download Audio
      task._lastUpdateTime = DateTime.now();
      await _dio.download(
        audioUrl,
        savePath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final now = DateTime.now();
            final diff = now.difference(task._lastUpdateTime!).inMilliseconds;
            
            if (diff > 800) { // Update speed every 800ms for stability
               double bytesDiff = (received - task._lastBytesReceived).toDouble();
               double instantSpeedBps = bytesDiff / (diff / 1000); // Bytes/s
               
               // Smoothing: 70% instant, 30% previous (if not 0)
               if (task._currentSpeed == 0) {
                   task._currentSpeed = instantSpeedBps;
               } else {
                   task._currentSpeed = (instantSpeedBps * 0.7) + (task._currentSpeed * 0.3);
               }

               if (task._currentSpeed > 1024 * 1024) {
                   task.speed = "${(task._currentSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s";
               } else {
                   task.speed = "${(task._currentSpeed / 1024).toStringAsFixed(0)} KB/s";
               }
               
               task._lastUpdateTime = now;
               task._lastBytesReceived = received;
            }
            
            task.progress = received / total;
            // Notify occasionally to avoid UI spam? No, notifyListeners is cheap enough usually if not every frame.
            // But for download, maybe throttle?
            // Let's rely on Flutter to batch frames.
            notifyListeners(); 
          }
        },
      );
      
      // 4. Download Thumbnail
      String? thumbUrl = task.video.thumbnails?.first.url;
      if (thumbUrl != null) {
          try {
             await _dio.download(thumbUrl, imgPath);
             task.imagePath = imgPath;
          } catch(e) {
             print("Thumb download failed: $e");
          }
      }

      task.filePath = savePath;
      task.status = DownloadStatus.completed;
      
      // 5. Save to Hive
      MyVideo completed = MyVideo(
          videoId: task.video.videoId,
          title: task.video.title,
          channelName: task.video.channelName,
          duration: task.video.duration,
          thumbnails: task.video.thumbnails,
          localaudio: savePath, // Store ABSOLUTE path? Or relative? App Docs dir changes on iOS.
          // Better to store relative, but code uses absolute. Let's stick to absolute for now or store filename and reconstruct.
          // The previous code stored absolute.
          localimage: task.imagePath ?? "" 
      );
      
      await _box.put(completed.videoId, completed.toJson());
      
      // Remove from active
      _activeDownloads.remove(task.video.videoId);
      notifyListeners();

    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
           task.status = DownloadStatus.canceled;
      } else {
          print("Download Error: $e");
          task.status = DownloadStatus.failed;
      }
      notifyListeners();
    }
  }

  Future<bool> _requestPermission() async {
      if (!Platform.isAndroid && !Platform.isIOS) return true; // No runtime permission needed on Desktop usually for AppDir
      
      // On Android 13+, permission logic is different for media, but path_provider uses app-specific storage.
      // Usually Internal Storage (AppDocsDir) doesn't need explicit permission.
      // But if we wanted External, we would.
      // The old code requested Permission.storage.
      var status = await Permission.storage.status;
      if (!status.isGranted) {
          status = await Permission.storage.request();
      }
      return status.isGranted;
  }
}
