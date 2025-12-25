import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'services/playlist_service.dart';
import 'videoComponent.dart';
import 'colors.dart';
import 'package:just_audio/just_audio.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  late Future<List<Playlist>> _playlistsFuture;
  final PlaylistService _playlistService = PlaylistService();
  Playlist? _selectedPlaylist;

  @override
  void initState() {
    super.initState();
    // Initialize with a pending future to avoid LateInitializationError
    _playlistsFuture = _playlistService.initializeDefaultPlaylist().then((_) {
        return _playlistService.getPlaylists();
    });
  }

  Future<void> _initAndLoad() async {
    await _playlistService.initializeDefaultPlaylist();
    if (mounted) {
       setState(() {
          _playlistsFuture = _playlistService.getPlaylists();
       });
    }
  }

  void _loadPlaylists() {
    setState(() {
      _playlistsFuture = _playlistService.getPlaylists();
    });
  }

  Future<void> _refreshSelectedPlaylist() async {
    if (_selectedPlaylist != null) {
      final updated = await _playlistService.getPlaylist(_selectedPlaylist!.name);
      if (updated != null) {
        setState(() {
          _selectedPlaylist = updated;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedPlaylist != null) {
      return _buildPlaylistDetails(_selectedPlaylist!);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<Playlist>>(
        future: _playlistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No playlists found.", style: TextStyle(color: Colors.grey)));
          } else {
            final playlists = snapshot.data!;
            return ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final isWatchLater = playlist.name == 'Watch Later';
                return Card(
                  color: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                          isWatchLater ? Icons.watch_later : Icons.playlist_play,
                          color: AppColors.primaryColor),
                    ),
                    title: Text(playlist.name,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${playlist.videos.length} items",
                        style: TextStyle(color: Colors.grey)),
                    onTap: () {
                      setState(() {
                        _selectedPlaylist = playlist;
                      });
                    },
                    trailing: isWatchLater
                        ? null
                        : IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.grey),
                            onPressed: () {
                              _showDeleteConfirmationDialog(
                                  context, playlist.name);
                            },
                          ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          _showCreatePlaylistDialog(context);
        },
      ),
    );
  }

  Widget _buildPlaylistDetails(Playlist playlist) {
    return Consumer<Playing>(
      builder: (context, playing, child) {
        final isThisPlaylistPlaying = playing.currentPlaylistName == playlist.name;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                setState(() {
                  _selectedPlaylist = null;
                });
                _loadPlaylists();
              },
            ),
            title: Text(playlist.name, style: TextStyle(color: Colors.white)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (playlist.videos.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Playlist is empty")),
                      );
                      return;
                    }

                    if (isThisPlaylistPlaying) {
                      if (playing.isPlaying) {
                        playing.pause();
                      } else {
                        // If finished or stopped, check processingState or just play
                        // But just_audio stop() resets to start.
                        // If naturally finished, we might need to seek to beginning.
                        if (playing.audioPlayer.processingState == ProcessingState.completed) {
                            playing.seekAudio(Duration.zero);
                            playing.play();
                        } else {
                            playing.play();
                        }
                      }
                    } else {
                      playing.setQueue(playlist.videos,
                          initialIndex: 0, playlistName: playlist.name);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Playing ${playlist.name}")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: Icon(
                    (isThisPlaylistPlaying && playing.isPlaying)
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 20,
                  ),
                  label: Text(
                    (isThisPlaylistPlaying && playing.isPlaying) ? 'Pause' : 'Play All',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: playlist.videos.isEmpty
              ? Center(
                  child: Text(
                    "No songs in this playlist.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: playlist.videos.length,
                  itemBuilder: (context, index) {
                    final video = playlist.videos[index];
                    final isCurrentVideo = isThisPlaylistPlaying &&
                        playing.video.videoId == video.videoId;

                    return GestureDetector(
                      onTap: () {
                        playing.setQueue(playlist.videos,
                            initialIndex: index, playlistName: playlist.name);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: isCurrentVideo
                              ? Border.all(color: AppColors.primaryColor, width: 2)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            AbsorbPointer(child: VideoComponent(video: video)),
                            if (isCurrentVideo && playing.isPlaying)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Icon(Icons.graphic_eq,
                                    color: AppColors.primaryColor),
                              ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: IconButton(
                                icon: Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () async {
                                  await _playlistService.removeVideoFromPlaylist(
                                      playlist.name, video.videoId!);
                                  _refreshSelectedPlaylist();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Removed from playlist")),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text("Create Playlist", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _controller,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Playlist Name",
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryColor)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (_controller.text.isNotEmpty) {
                  await _playlistService.savePlaylist(Playlist(name: _controller.text, videos: []));
                  _loadPlaylists();
                  Navigator.pop(context);
                }
              },
              child: Text("Create", style: TextStyle(color: AppColors.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String playlistName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text("Delete Playlist", style: TextStyle(color: Colors.white)),
          content: Text("Are you sure you want to delete the playlist '$playlistName'?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await _playlistService.deletePlaylist(playlistName);
                _loadPlaylists();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Playlist '$playlistName' deleted.")),
                );
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
