import 'dart:async';
import 'dart:io';

import 'package:audiofy/channelVideosPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart'; // Replace with the actual path
// import 'downloadUtils.dart'; // Removed legacy
import 'services/download_manager.dart';
import 'favoriteUtils.dart';
import 'connectivityProvider.dart';
import 'MyVideo.dart';
import 'colors.dart';

import 'services/playlist_service.dart'; // Add this import

class VideoComponent extends StatefulWidget {
  final MyVideo video;

  VideoComponent({required this.video});

  @override
  _VideoComponentState createState() => _VideoComponentState();
}

class _VideoComponentState extends State<VideoComponent> {
  late Future<List<bool>> _future;
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _future = Future.wait([
      isFavorites(widget.video),
      // isDownloaded handled by DownloadManager now
    ]);
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel(); // Cancel any ongoing download subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = Provider.of<Playing>(context, listen: false);
    bool isOnline = Provider.of<NetworkProvider>(context).isOnline;
    // Listen to DownloadManager updates
    final downloadManager = Provider.of<DownloadManager>(context);
    final task = downloadManager.activeDownloads[widget.video.videoId];
    bool isDownloading = task != null;
    double progress = task?.progress ?? 0.0;
    bool isDownloaded = downloadManager.isDownloaded(widget.video.videoId!);

    return FutureBuilder<List<bool>>(
      future: _future,
      builder: (context, snapshot) {
        // Note: snapshot logic primarily for 'isFavorites' now.
        // 'isDownloaded' is real-time from manager.

        bool _isLiked = false;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          _isLiked = snapshot.data![0];
        }

        // Check if this video is the currently playing video
        final isCurrentVideo = playing.video.videoId == widget.video.videoId;

        return GestureDetector(
          onTap: () {
            if (playing.queue.isEmpty) {
              playing.assign(widget.video, true);
            } else {
              playing.playNext(widget.video);
            }
          },
          child: Container(
            // height: 200, // Removed to allow GridView aspect ratio to dictate height without overflow
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(15),
              border: isCurrentVideo
                  ? Border.all(
                      color: AppColors
                          .primaryColor, // Highlight border if current video
                      width: 2,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(15),
                          bottom: Radius.circular(15),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: (widget.video.localimage != null &&
                                  File(widget.video.localimage!).existsSync())
                              ? Image.file(
                                  File(widget.video.localimage!),
                                  fit: BoxFit.cover,
                                )
                              : (isOnline &&
                                      widget.video.thumbnails != null &&
                                      widget.video.thumbnails!.isNotEmpty)
                                  ? Image.network(
                                      widget.video.thumbnails![0].url!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[800],
                                      child: Icon(Icons.music_note,
                                          color: Colors.white)),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 20,
                          ),
                          onSelected: (String value) {
                            switch (value) {
                              case 'add_to_queue':
                                playing.addToQueue(widget.video);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Added to Queue')));
                                break;
                              case 'add_to_favorites':
                                saveToFavorites(widget.video);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Added to favorites')));
                                break;
                              case 'remove_from_favorites':
                                removeFavorites(widget.video);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Removed from favorites')));
                                break;
                              case 'add_to_downloads':
                                downloadManager.startDownload(widget.video);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Download started')));
                                break;
                              case 'remove_from_downloads':
                                downloadManager.deleteDownload(widget.video);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Deleted from downloads')));
                                break;
                              case 'cancel_download':
                                downloadManager
                                    .cancelDownload(widget.video.videoId!);
                                break;
                              case 'add_to_playlist': // New case
                                _showAddToPlaylistDialog(context, widget.video);
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem<String>(
                                value: 'add_to_queue',
                                child: Text('Add to Queue'),
                              ),
                              PopupMenuItem<String>(
                                // New menu item
                                value: 'add_to_playlist',
                                child: Text('Add to Playlist'),
                              ),
                              _isLiked
                                  ? PopupMenuItem<String>(
                                      value: 'remove_from_favorites',
                                      child: Text('Remove from favorites'),
                                    )
                                  : PopupMenuItem<String>(
                                      value: 'add_to_favorites',
                                      child: Text('Add to favorites'),
                                    ),
                              if (isDownloading)
                                PopupMenuItem<String>(
                                  value: 'cancel_download',
                                  child: Text('Cancel Download'),
                                )
                              else if (isDownloaded)
                                PopupMenuItem<String>(
                                  value: 'remove_from_downloads',
                                  child: Text('Remove from downloads'),
                                )
                              else
                                PopupMenuItem<String>(
                                  value: 'add_to_downloads',
                                  child: Text('Download'),
                                ),
                            ];
                          },
                        ),
                      ),
                      if (widget.video.duration != null &&
                          widget.video.duration!.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.video.duration ?? '',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (isCurrentVideo) // Show play icon if current video
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Icon(
                            Icons.play_arrow,
                            color: AppColors.primaryColor,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isDownloading)
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.black87,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.title ?? 'No title',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior
                            .opaque, // Makes the widget capture the tap
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChannelVideosPage(
                                videoId: widget.video.videoId!,
                                channelName: widget.video.channelName ?? '',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          widget.video.channelName ?? 'Unknown channel',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, MyVideo video) async {
    final PlaylistService _service = PlaylistService();
    List<Playlist> playlists = await _service.getPlaylists();
    final TextEditingController _newPlaylistNameController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text("Add to Playlist", style: TextStyle(color: Colors.white)),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (playlists.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return ListTile(
                          leading: Icon(Icons.playlist_add,
                              color: AppColors.primaryColor),
                          title: Text(playlist.name,
                              style: TextStyle(color: Colors.white)),
                          onTap: () async {
                            await _service.addVideoToPlaylist(
                                playlist.name, video);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Added to ${playlist.name}")),
                            );
                          },
                        );
                      },
                    ),
                  ),
                if (playlists.isNotEmpty) Divider(color: Colors.grey),
                TextField(
                  controller: _newPlaylistNameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "New Playlist Name",
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryColor)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (_newPlaylistNameController.text.isNotEmpty) {
                  final newPlaylist = Playlist(
                    name: _newPlaylistNameController.text,
                    videos: [video],
                  );
                  await _service.savePlaylist(newPlaylist);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text("Created and added to '${newPlaylist.name}'")),
                  );
                }
              },
              child: Text("Create",
                  style: TextStyle(color: AppColors.primaryColor)),
            ),
          ],
        );
      },
    );
  }
}
