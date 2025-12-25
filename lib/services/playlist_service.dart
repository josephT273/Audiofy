import 'package:hive/hive.dart';
import '../MyVideo.dart';

class Playlist {
  String name;
  List<MyVideo> videos;

  Playlist({required this.name, required this.videos});

  // toJson and fromJson for Hive
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'videos': videos.map((v) => v.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      name: json['name'] as String,
      videos: (json['videos'] as List)
          .map((v) => MyVideo.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList(),
    );
  }
}

class PlaylistService {
  static const String _boxName = 'playlists';

  Future<void> savePlaylist(Playlist playlist) async {
    final box = Hive.box(_boxName);
    await box.put(playlist.name, playlist.toJson());
  }

  Future<List<Playlist>> getPlaylists() async {
    final box = Hive.box(_boxName);
    return box.values
        .map((p) => Playlist.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
  }

  Future<Playlist?> getPlaylist(String name) async {
    final box = Hive.box(_boxName);
    final playlistJson = box.get(name);
    if (playlistJson != null) {
      return Playlist.fromJson(Map<String, dynamic>.from(playlistJson as Map));
    }
    return null;
  }

  Future<void> deletePlaylist(String name) async {
    if (name == 'Watch Later') return;
    final box = Hive.box(_boxName);
    await box.delete(name);
  }

  Future<void> renamePlaylist(String oldName, String newName) async {
    if (oldName == 'Watch Later' || newName == 'Watch Later') return;
    final playlist = await getPlaylist(oldName);
    if (playlist != null) {
      await deletePlaylist(oldName);
      await savePlaylist(Playlist(name: newName, videos: playlist.videos));
    }
  }

  Future<void> initializeDefaultPlaylist() async {
    final box = Hive.box(_boxName);
    if (!box.containsKey('Watch Later')) {
      final watchLater = Playlist(name: 'Watch Later', videos: []);
      await savePlaylist(watchLater);
    }
  }

  Future<void> addVideoToPlaylist(String playlistName, MyVideo video) async {
    final playlist = await getPlaylist(playlistName);
    if (playlist != null) {
      if (!playlist.videos.any((v) => v.videoId == video.videoId)) {
        playlist.videos.add(video);
        await savePlaylist(playlist);
      }
    }
  }

  Future<void> removeVideoFromPlaylist(String playlistName, String videoId) async {
    final playlist = await getPlaylist(playlistName);
    if (playlist != null) {
      playlist.videos.removeWhere((v) => v.videoId == videoId);
      await savePlaylist(playlist);
    }
  }
}
