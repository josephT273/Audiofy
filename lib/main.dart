import 'package:path_provider/path_provider.dart';
import 'package:audiofy/playlistsPage.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:ffi' hide Size; // Add ffi
import 'package:ffi/ffi.dart'; // Add ffi package
import 'package:flutter/foundation.dart';
import 'package:audiofy/desktopPlayer.dart';
import 'package:audiofy/downloadsPage.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart'; // Switch to just_audio_media_kit
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:youtube_scrape_api/models/thumbnail.dart';
import 'package:youtube_scrape_api/models/video_data.dart';
import 'package:youtube_scrape_api/youtube_scrape_api.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'fetchYoutubeStreamUrl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as ytex;
import 'youtubePage.dart';
import 'favoritePage.dart';
import 'historyPage.dart';
import 'bottomPlayer.dart';
import 'package:just_audio/just_audio.dart';
import 'services/history_service.dart';
import 'youtubeAudioStream.dart';
import 'connectivityProvider.dart';
import 'MyVideo.dart';
import 'colors.dart';
import 'services/download_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initHive();

  // Add Linux support for just_audio
  // Add Linux support for just_audio
  if (!kIsWeb && Platform.isLinux) {
    JustAudioMediaKit.ensureInitialized();
    // Enable media_kit logging for Linux debugging
    // JustAudioMediaKit.logLevel = MPVLogLevel.debug;

    // Fix for "Non-C locale detected" crash
    try {
      final libc = DynamicLibrary.open('libc.so.6');
      final setlocale = libc.lookupFunction<
          Pointer<Char> Function(Int32, Pointer<Char>),
          Pointer<Char> Function(int, Pointer<Char>)>('setlocale');

      // LC_NUMERIC is 1 on Linux
      final culture = 'C'.toNativeUtf8();
      setlocale(1, culture.cast<Char>());
      malloc.free(culture);
      print("Locale set to C for LC_NUMERIC");
    } catch (e) {
      print("Failed to set locale: $e");
    }
  }

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => LikeNotifier()),
    ChangeNotifierProvider(create: (_) => Playing()),
    ChangeNotifierProvider(create: (_) => NetworkProvider()),
    ChangeNotifierProvider(create: (_) => DownloadManager()),
  ], child: const MyApp()));
}

Future<void> _initHive() async {
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  await Hive.openBox('settings');
  await Hive.openBox('search_history');
  await Hive.openBox('watch_history');
  await Hive.openBox('downloads');
  await Hive.openBox('playlists');
}

class Playing with ChangeNotifier {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  MyVideo _video = MyVideo();
  List<MyVideo> _queue = [];
  ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []); // Initialize playlist
  List<ytex.ClosedCaption> captions = [];
  String currentCaption = "no caption fo this media";

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _isLooping = 0;
  bool _isShuffling = false;
  bool _isloading = false;
  bool _isPlayerVisible = true;
  bool _recordedHistory = false;

  bool get isloading => _isloading;

  bool get isShuffling => _isShuffling;

  bool get isPlayerVisible => _isPlayerVisible;

  ConcatenatingAudioSource get playlist => _playlist;

  Duration get duration => _duration;

  Duration get position => _position;

  MyVideo get video => _video;

  AudioPlayer get audioPlayer => _audioPlayer;

  bool get isPlaying => _isPlaying;

  List<MyVideo> get queue => _queue;

  int get isLooping => _isLooping;

  Playing() {
    _initAudioPlayer();
  }
  void hidePlayer() {
    _isPlayerVisible = false;
    notifyListeners();
  }

  void showPlayer() {
    _isPlayerVisible = true;
    notifyListeners();
  }

  void setIsPlaying(bool isit) {
    if (isit) {
      play();
    } else {
      pause();
    }
    _isPlaying = isit;
    notifyListeners();
  }

  void _initAudioPlayer() {
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        notifyListeners();
      }
    });

    _audioPlayer.positionStream.listen((position) {
      _position = position;

      if (captions.isNotEmpty) {
        currentCaption = getCaptionAtTime(captions, position);
      } else {
        currentCaption = "No caption for this media";
      }

      // History Logic
      if (!_recordedHistory &&
          position.inSeconds >= 30 &&
          _video.videoId != null) {
        // Ensure video has title before saving
        if (_video.title != null && _video.title!.isNotEmpty) {
          HistoryService().addToHistory(_video);
          _recordedHistory = true;
          print("Added to history: ${_video.title}");
        }
      }
      notifyListeners();
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      notifyListeners();

      print(
          "Player state: ${playerState.processingState}, playing: ${playerState.playing}");

      if (playerState.processingState == ProcessingState.completed) {
        if (_isLooping == 1) {
          seekAudio(Duration.zero);
          play();
        } else if (_isLooping == 2 && _queue.isNotEmpty) {
          _audioPlayer.seek(Duration.zero, index: 0);
        } else if (_queue.isNotEmpty) {
          next();
        } else {
          _isPlaying = false;
          notifyListeners();
        }
      }
    });

    _audioPlayer.currentIndexStream.listen((index) async {
      if (index != null && index >= 0 && index < _queue.length) {
        _video = _queue[index];
        _recordedHistory = false; // Reset for new track
        captions = (await fetchYoutubeClosedCaptions(
            _video.videoId!)); // Sync _video with the current track
        notifyListeners();
      }
    });
  }

  Future<void> toggleShuffle() async {
    _isShuffling = !_isShuffling;
    await _audioPlayer
        .setShuffleModeEnabled(_isShuffling); // Use just_audio's shuffle
    notifyListeners();
  }

  Future<void> toggleLooping() async {
    _isLooping = (_isLooping + 1) % 3;
    if (_isLooping == 0) {
      await _audioPlayer.setLoopMode(LoopMode.off);
    } else if (_isLooping == 1) {
      await _audioPlayer.setLoopMode(LoopMode.one);
    } else if (_isLooping == 2) {
      await _audioPlayer.setLoopMode(LoopMode.all);
    }
    notifyListeners();
  }

  Future<void> playNext(MyVideo v) async {
    _isloading = true;
    notifyListeners();

    try {
      // 1. If queue is empty, just assign
      if (_queue.isEmpty) {
        await assign(v, true);
        return;
      }

      // 2. Insert immediately after current song
      int currentIndex = _audioPlayer.currentIndex ?? 0;
      int insertIndex = currentIndex + 1;

      // Prevent out of bounds
      if (insertIndex > _queue.length) {
        insertIndex = _queue.length;
      }

      // 3. Add to _queue
      _queue.insert(insertIndex, v);

      // 4. Add to _playlist
      AudioSource audioSource = await createAudioSource(v);
      await _playlist.insert(insertIndex, audioSource);

      notifyListeners();

      // 5. Play immediately
      await _audioPlayer.seek(Duration.zero, index: insertIndex);
      await play();

      _isloading = false;
      notifyListeners();
    } catch (e) {
      print("Error in playNext: $e");
      _isloading = false;
      notifyListeners();
    }
  }

  Future<void> assign(MyVideo v, bool clear) async {
    _isloading = true;
    _isPlayerVisible = true;
    notifyListeners();

    try {
      if (clear) {
        // Hard reset for the audio player and queue
        currentPlaylistName = null; // Clear playlist context
        await _audioPlayer.stop();
        _queue.clear();
        _queue.add(v);
        _video = v;
        notifyListeners();

        AudioSource audioSource = await createAudioSource(v);
        _playlist = ConcatenatingAudioSource(children: [audioSource]);
        await _audioPlayer.setAudioSource(_playlist);
      } else {
        // if video is not in queue, add it
        if (!_queue.any((element) => element.videoId == v.videoId)) {
          _queue.add(v);
          notifyListeners();
          AudioSource audioSource = await createAudioSource(v);
          await _playlist.add(audioSource);
        }

        int index = _queue.indexWhere((video) => video.videoId == v.videoId);
        if (index != -1) {
          _video = v;
          await _audioPlayer.seek(Duration.zero, index: index);
        } else {
          print("Video not found in the playlist.");
          _isloading = false;
          notifyListeners();
          return;
        }
      }

      _recordedHistory = false;
      resetPosition();

      _isloading = false;
      notifyListeners();
      await play();
    } catch (e) {
      print("Error in assign: $e");
      _isloading = false;
      notifyListeners();
    }
  }

  Future<void> addToQueue(MyVideo v) async {
    if (_queue.isEmpty) {
      print("empty");
      await assign(v, true);
      notifyListeners();
      return;
    }

    _queue.add(v); // Add video to the queue

    AudioSource audioSource = await createAudioSource(v);
    await _playlist.add(audioSource); // Add audio source to the playlist
    notifyListeners();
  }

  Future<void> removeFromQueue(MyVideo video) async {
    final index = _queue.indexOf(video);
    if (index != -1) {
      _queue.removeAt(index); // Remove video from the queue
      await _playlist.removeAt(index); // Remove audio source from the playlist

      // If the removed video was the current video, update _video
      if (_video.videoId == video.videoId) {
        if (_queue.isNotEmpty) {
          _video = _queue[_audioPlayer.currentIndex ?? 0];
        } else {
          _video = MyVideo(); // Reset _video if the queue is empty
        }
      }

      notifyListeners();
    }
  }

  Future<void> clearQueue() async {
    currentPlaylistName = null; // Clear playlist context
    _queue.clear(); // Clear the queue
    _playlist = ConcatenatingAudioSource(children: []); // Clear the playlist
    await _audioPlayer.setAudioSource(_playlist);

    _video = MyVideo(); // Reset _video
    notifyListeners();
  }

  String? currentPlaylistName;

  Future<void> setQueue(List<MyVideo> videos,
      {int initialIndex = 0, String? playlistName}) async {
    if (videos.isEmpty) {
      print("Warning: setQueue called with empty videos list");
      await clearQueue();
      return;
    }

    print(
        "DEBUG: setQueue called with ${videos.length} videos. Initial Index: $initialIndex");

    _isloading = true;
    _isPlayerVisible = true; // Ensure player is visible
    currentPlaylistName = playlistName;
    notifyListeners();

    // 1. Clear current playback state
    await _audioPlayer.stop();
    _queue.clear();
    _playlist = ConcatenatingAudioSource(children: []);

    // 2. Populate _queue immediately for UI
    _queue.addAll(videos);
    _video = videos[initialIndex];
    notifyListeners();

    // 3. Find the first playable video starting from initialIndex
    int foundIndex = -1;
    for (int i = initialIndex; i < videos.length; i++) {
      try {
        print("Attempting to load initial video: ${videos[i].title}");
        AudioSource initialSource = await createAudioSource(videos[i]);
        await _playlist.add(initialSource);
        _video = videos[i]; // Update video only if successful
        foundIndex = i;
        notifyListeners();
        break; // Found a working video
      } catch (e) {
        print("Skipping failed video: ${videos[i].title}. Error: $e");
        // Continue to next video
      }
    }

    if (foundIndex == -1) {
      print("All videos in playlist failed to load.");
      _isloading = false;
      notifyListeners();
      return;
    }

    try {
      // Set the audio source with the first song before playing
      await _audioPlayer.setAudioSource(_playlist);

      // Start playing
      await play();
      _isloading = false;
      notifyListeners();

      // 4. Load remaining videos in the background
      for (int i = 0; i < videos.length; i++) {
        if (i == foundIndex) continue;

        MyVideo v = videos[i];
        try {
          print(
              "Preloading background video ($i/${videos.length - 1}): ${v.title}");
          AudioSource source = await createAudioSource(v);
          await _playlist.insert(i, source);
        } catch (e) {
          print("Failed to preload ${v.title}, skipping. Error: $e");
        }
      }
    } catch (e) {
      print("Error in setQueue: $e");
      _isloading = false;
      notifyListeners();
    }
  }

  Future<void> next() async {
    if (_queue.isNotEmpty) {
      _isloading = true;
      notifyListeners();
      await _audioPlayer.seekToNext();
      _isloading = false;
      notifyListeners();
    }
  }

  Future<void> previous() async {
    if (_queue.isNotEmpty) {
      _isloading = true;
      int currentPosition = _position.inSeconds;
      if (currentPosition > 3) {
        await seekAudio(Duration.zero);
      } else {
        await _audioPlayer.seekToPrevious();
      }
      _isloading = false;
      notifyListeners();
    }
  }

  void updateDuration(Duration d) {
    _duration = d;
    notifyListeners();
  }

  void updatePosition(Duration p) {
    _position = p;
    notifyListeners();
  }

  void resetPosition() {
    _position = Duration.zero;
    notifyListeners();
  }

  void resetDuration() {
    _duration = Duration.zero;
    notifyListeners();
  }

  void resetAllDurationAndPosition() {
    _position = Duration.zero;
    notifyListeners();
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<void> streamAudio(String url) async {
    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await play();
    } catch (e) {
      print('Error streaming audio: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> play() async {
    await _audioPlayer.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> seekAudio(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<AudioSource> createAudioSource(MyVideo v) async {
    // Use DownloadManager singleton
    final downloadManager = DownloadManager();
    var local = downloadManager.isDownloaded(v.videoId!);

    if (local) {
      v = downloadManager.getDownload(v.videoId!)!;
      if (v.localaudio == null || !File(v.localaudio!).existsSync()) {
        print("Local file missing for ${v.title}, falling back to stream");
        // Fallback to stream if file missing
        return _createStreamSource(v);
      }

      return AudioSource.uri(
        Uri.file(v.localaudio!),
        tag: MediaItem(
          id: v.videoId!,
          album: v.channelName ?? "Unknown Channel",
          title: v.title ?? "Unknown Title",
          artUri: v.thumbnails != null && v.thumbnails!.isNotEmpty
              ? Uri.file(v.localimage ?? "")
              : null,
        ),
      );
    } else {
      return _createStreamSource(v);
    }
  }

  Future<AudioSource> _createStreamSource(MyVideo v) async {
    print("Fetching stream URL for ${v.videoId}...");
    try {
      var url = await fetchYoutubeStreamUrl(v.videoId!);
      print("Stream URL fetched: $url");

      return AudioSource.uri(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'
        },
        tag: MediaItem(
          id: v.videoId!,
          album: v.channelName ?? "Unknown",
          title: v.title ?? "Unknown",
          artUri: v.thumbnails != null &&
                  v.thumbnails!.isNotEmpty &&
                  v.thumbnails![0].url != null
              ? Uri.parse(v.thumbnails![0].url!)
              : null,
        ),
      );
    } catch (e) {
      print("Error fetching stream URL: $e");
      throw e;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class Thumbnail2 {
  String? url;
  int? width, height;
  Thumbnail2({this.url, this.width, this.height});
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription _intentSub;
  final _sharedFiles = <SharedMediaFile>[];

  @override
  void initState() {
    super.initState();

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);

        if (_sharedFiles.isNotEmpty) {
          final videoId =
              _sharedFiles.first.path.split('watch?v=').last.split('&').first;
          addSharedVideo(videoId);
        }

        print(_sharedFiles.map((f) => f.toMap()));
      });
    });

    // ReceiveSharingIntent.instance.getInitialMedia().then((value) {
    //   setState(() {
    //     _sharedFiles.clear();
    //     _sharedFiles.addAll(value);
    //     print(_sharedFiles.map((f) => f.toMap()));

    //     // Tell the library that we are done processing the intent.
    //     ReceiveSharingIntent.instance.reset();
    //   });
    // });
  }

  Future<void> addSharedVideo(String videoId) async {
    YoutubeDataApi youtubeDataApi = YoutubeDataApi();
    VideoData? sharedVideo = await youtubeDataApi.fetchVideoData(videoId);
    Provider.of<Playing>(context, listen: false).assign(
        MyVideo(
            videoId: videoId,
            channelName: sharedVideo?.video?.channelName,
            title: sharedVideo!.video?.title,
            thumbnails: [
              Thumbnail(
                  url: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                  width: 720,
                  height: 404)
            ]),
        true);
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black87,
          brightness: Brightness.dark,
        ).copyWith(
          surface: Colors.black87,
          primary: Colors.black87,
        ),
        useMaterial3: true,
      ),
      home: YouTubeTwitchTabs(),
    );
  }
}

class YouTubeTwitchTabs extends StatefulWidget {
  const YouTubeTwitchTabs({super.key});

  @override
  _YouTubeTwitchTabsState createState() => _YouTubeTwitchTabsState();
}

class _YouTubeTwitchTabsState extends State<YouTubeTwitchTabs> {
  int _selectedIndex = 0;
  double _playerWidth = 400.0;

  Widget _getPage() {
    switch (_selectedIndex) {
      case 0:
        return const YoutubeScreen();
      case 1:
        return const FavoriteScreen();
      case 2:
        return const DownloadScreen();
      case 3:
        return const HistoryScreen();
      case 4:
        return const PlaylistsScreen();
      default:
        return const YoutubeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = context.watch<Playing>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        if (isDesktop) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: const CustomAppBar(),
            body: Row(
              children: [
                NavigationRail(
                  extended: true,
                  backgroundColor: Colors.black,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  leading: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Image.asset('assets/icon.png', height: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "AudioBinge",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.video_library),
                      label: Text("YouTube"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text("Favorites"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.download),
                      label: Text("Downloads"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history),
                      label: Text("History"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.playlist_play),
                      label: Text("Playlists"),
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.deepPurple.shade800,
                          Colors.black,
                        ],
                      ),
                    ),
                    child: _getPage(),
                  ),
                ),
                if (playing.video.title != null)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          // Adjust width reversed since it's on the right
                          _playerWidth -= details.delta.dx;
                          // Clamp width
                          if (_playerWidth < 300) _playerWidth = 300;
                          if (_playerWidth > 600) _playerWidth = 600;
                        });
                      },
                      child: Container(
                        width: 8,
                        color: Colors.black,
                        child: Center(
                            child: Container(width: 1, color: Colors.white24)),
                      ),
                    ),
                  ),
                if (playing.video.title != null)
                  SizedBox(
                    width: _playerWidth,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        border: Border(left: BorderSide(color: Colors.white12)),
                      ),
                      child: const DesktopPlayer(),
                    ),
                  )
              ],
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          appBar: const CustomAppBar(),
          body: Stack(
            children: [
              _getPage(),
              if (playing.video.title != null && playing.isPlayerVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: kBottomNavigationBarHeight + 6,
                  child: Dismissible(
                    key: const Key("bottom_player"),
                    direction: DismissDirection.horizontal,
                    onDismissed: (_) {
                      playing.hidePlayer();
                      playing.stop();
                    },
                    child: const BottomPlayer(),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
                backgroundColor: Colors.black.withOpacity(0.6),
                selectedItemColor: AppColors.primaryColor,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.video_library),
                    label: "YouTube",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.favorite),
                    label: "Favorites",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.download),
                    label: "Downloads",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history),
                    label: "History",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.playlist_play),
                    label: "Playlists",
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Extracted Custom AppBar
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false, // Hide the back button
      title: Row(
        children: [
          // App Logo
          Image.asset(
            'assets/icon.png',
            height: 40, // Adjusted for better proportions
            width: 40,
          ),
          SizedBox(width: 10), // Spacing between logo and title
          // App Title
          Text(
            "Audiofy",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
