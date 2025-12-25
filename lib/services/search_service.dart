import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_scrape_api/youtube_scrape_api.dart';

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final Box _historyBox = Hive.box('search_history');
  final YoutubeDataApi _api = YoutubeDataApi();
  final _controller = StreamController<List<String>>.broadcast();

  Stream<List<String>> get historyStream => _controller.stream;

  List<String> getHistory() {
    return _historyBox.get('history', defaultValue: <String>[]).cast<String>();
  }

  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    List<String> history = getHistory();
    history.remove(query);
    history.insert(0, query);
    if (history.length > 50) {
      history = history.sublist(0, 50);
    }
    await _historyBox.put('history', history);
    _controller.add(history);
  }

  Future<void> removeFromHistory(String query) async {
    List<String> history = getHistory();
    history.remove(query);
    await _historyBox.put('history', history);
    _controller.add(history);
  }

  Future<void> clearHistory() async {
    await _historyBox.delete('history');
    _controller.add([]);
  }

  Future<List<dynamic>> search(String query) async {
    query = query.trim();
    if (isYoutubeUrl(query)) {
      // 1. Try Video ID
      String? id = extractVideoId(query);
      if (id != null) {
         try {
             var videoData = await _api.fetchVideoData(id);
             if (videoData?.video != null) {
                 return [videoData!.video];
             }
         } catch (e) {
             print("Error scraping URL ID $id: $e");
         }
      }
      
    }
    
    // Fallback to standard search
    return await _api.fetchSearchVideo(query);
  }

  Future<List<String>> getSuggestions(String query) async {
     return await _api.fetchSuggestions(query);
  }

  bool isYoutubeUrl(String text) {
    final t = text.toLowerCase();
    return t.contains('youtube.com/') || t.contains('youtu.be/') || t.contains('youtube.com/shorts/');
  }
  
  String? extractVideoId(String text) {
      for (var exp in [
        RegExp(r'v=([\w\-]{11})'),
        RegExp(r'youtu\.be\/([\w\-]{11})'),
        RegExp(r'embed\/([\w\-]{11})'),
        RegExp(r'v\/([\w\-]{11})'),
        RegExp(r'shorts\/([\w\-]{11})'),
      ]) {
        Match? match = exp.firstMatch(text);
        if (match != null && match.groupCount >= 1) return match.group(1);
      }
      return null;
  }

  String? extractPlaylistId(String text) {
      RegExp exp = RegExp(r'list=([\w\-]+)');
      Match? match = exp.firstMatch(text);
      if (match != null && match.groupCount >= 1) return match.group(1);
      return null;
  }
}
