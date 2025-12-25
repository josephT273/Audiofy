import 'package:hive_flutter/hive_flutter.dart';
import 'package:audiofy/MyVideo.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  final Box _box = Hive.box('watch_history');

  List<MyVideo> getHistory() {
    // Return list sorted by lastPlayedAt (descending) if needed, 
    // but we will store them in order (add puts it at end or specific key).
    // Let's store as a list in a single key 'history_list' or as individual keys.
    // Individual keys are better for deduplication by videoId.
    
    // Strategy: Use videoId as key. Store timestamp inside.
    // To get sorted list: get all values, sort by timestamp.
    
    List<dynamic> raw = _box.values.toList();
    List<Map<String, dynamic>> parsed = raw.map((e) => Map<String, dynamic>.from(e)).toList();
    
    // Sort desc
    parsed.sort((a, b) => (b['lastPlayedAt'] as int).compareTo(a['lastPlayedAt'] as int));
    
    return parsed.map((e) => MyVideo.fromMap(e)).toList();
  }

  Future<void> addToHistory(MyVideo video) async {
    if (video.videoId == null) return;
    
    Map<String, dynamic> data = video.toJson();
    data['lastPlayedAt'] = DateTime.now().millisecondsSinceEpoch;
    
    await _box.put(video.videoId, data);
    
    // Limit to 500 items
    if (_box.length > 500) {
       // Find oldest keys and delete them.
       // This can be expensive if we strictly need last 500 by time.
       // Since we just put a new one, we can check if size > 500.
       // To delete oldest, we need to sort all keys? Hive keys are not necessarily sorted.
       // For now, let's do a cleanup occasionally or simple "delete first key".
       // If keys are videoIds, order is not guaranteed.
       
       // Optimization: Only clean up if significantly larger, e.g. > 550.
       if (_box.length > 550) {
           _pruneHistory();
       }
    }
  }
  
  void _pruneHistory() {
      // Load all, sort, remove oldest.
      List<dynamic> keys = _box.keys.toList();
      if (keys.length <= 500) return;
      
      // We need values to know time.
      List<Map<String, dynamic>> items = _box.values.map((e) => Map<String, dynamic>.from(e)).toList();
      items.sort((a, b) => (b['lastPlayedAt'] as int).compareTo(a['lastPlayedAt'] as int));
      
      // Keep first 500
      List<String> idsKeep = items.take(500).map((e) => e['videoId'] as String).toList();
      
      // Find keys to delete
      List<dynamic> toDelete = [];
      for (var key in keys) {
          if (!idsKeep.contains(key)) {
              toDelete.add(key);
          }
      }
      _box.deleteAll(toDelete);
  }

  Future<void> clearHistory() async {
    await _box.clear();
  }
}
