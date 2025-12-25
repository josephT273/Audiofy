// File: lib/youtubePage.dart
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:youtube_scrape_api/models/video.dart';
import 'package:youtube_scrape_api/models/video_data.dart';
import 'package:youtube_scrape_api/youtube_scrape_api.dart';
import 'videoComponent.dart';
import 'thumbnailUtils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'connectivityProvider.dart';
import 'main.dart';
import 'MyVideo.dart';
import 'colors.dart';
import 'services/search_service.dart';

class YoutubeScreen extends StatefulWidget {
  const YoutubeScreen({super.key});

  @override
  _YoutubeScreenState createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MyVideo> _videos = [];
  bool _isLoading = false;
  bool _isSearching = false;
  final FocusNode _searchFocus = FocusNode();
  List<String> _history = [];
  bool _showHistory = false;
  final SearchService _searchService = SearchService();

  @override
  void initState() {
    super.initState();
    _history = _searchService.getHistory();
    _searchFocus.addListener(_onFocusChange);
    
    // Check history for initial load
    if (_history.isNotEmpty) {
        // Pick up to 2 random unique items to mix things up
        final random = List<String>.from(_history)..shuffle();
        final queries = random.take(2).toList();
        searchYoutubeMixed(queries);
    } else {
        fetchTrendingYoutube();
    }
  }

  void searchYoutubeMixed(List<String> queries) async {
      setState(() {
          _isLoading = true;
      });
      
      List<MyVideo> allVideos = [];
      
      for (var query in queries) {
          try {
             List videos = await _searchService.search(query);
             List<Video> temp = videos.whereType<Video>().toList();
             for (var videoData in temp) {
                 allVideos.add(processVideoThumbnails(videoData));
             }
          } catch(e) {
              print("Error fetching for $query: $e");
          }
      }
      
      // Shuffle the combined results for a "Feed" feel
      allVideos.shuffle();
      
      setState(() {
          _videos = allVideos;
          _isLoading = false;
      });
  }

  void _onFocusChange() {
    if (_searchFocus.hasFocus) {
      setState(() {
        _showHistory = true;
        _history = _searchService.getHistory();
      });
    } else {
      // Small delay to allow tap on history item to register before hiding
      Future.delayed(Duration(milliseconds: 200), () {
        if (mounted && !_searchFocus.hasFocus) {
           setState(() {
             _showHistory = false;
           });
        }
      });
    }
  }

  Future<void> _handleRefresh() async {
    fetchTrendingYoutube();
  }

  void fetchTrendingYoutube() async {
    setState(() {
      _isLoading = true;
    });
    YoutubeDataApi youtubeDataApi = YoutubeDataApi();
    List<Video> videos = await youtubeDataApi.fetchTrendingVideo();
    List<MyVideo> processedVideos = [];
    for (var videoData in videos) {
      MyVideo videoWithHighestThumbnail = processVideoThumbnails(videoData);
      processedVideos.add(videoWithHighestThumbnail);
    }
    setState(() {
      _videos = processedVideos;
      _isLoading = false;
    });
  }

  void searchYoutube(String query) async {
    if (query.isEmpty) return;
    
    _searchFocus.unfocus();
    setState(() {
      _isSearching = true;
      _showHistory = false;
    });

    await _searchService.addToHistory(query);

    if (_searchService.isYoutubeUrl(query)) {
        String? id = _searchService.extractVideoId(query);
         if (id != null) {
            // If it's a URL, maybe just play it directly or fetch single video?
            // For now let's treat it as a search result if API supports it, 
            // OR fetch video data and show it.
            // But common flow is search -> list.
            // Let's rely on standard search first, catch errors later.
            // actually youtube scrape api search might not handle ID well, let's see.
         }
    }
    
    List videos = await _searchService.search(query);
    List<Video> temp = videos.whereType<Video>().toList();
    List<MyVideo> processedVideos = [];
    for (var videoData in temp) {
      MyVideo videoWithHighestThumbnail = processVideoThumbnails(videoData);
      processedVideos.add(videoWithHighestThumbnail);
    }
    setState(() {
      _videos = processedVideos;
      _isSearching = false;
    });
  }

  void _deleteHistoryItem(String item) async {
      await _searchService.removeFromHistory(item);
      setState(() {
          _history = _searchService.getHistory();
      });
  }
  
  void _clearHistory() async {
      await _searchService.clearHistory();
      setState(() {
          _history = [];
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.removeListener(_onFocusChange);
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isOnline = Provider.of<NetworkProvider>(context).isOnline;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    hintText: 'Search YouTube or paste URL...',
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.8)),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SvgPicture.asset(
                        'assets/icons/youtube.svg',
                        height: 24,
                        color: Colors.white,
                      ),
                    ),
                    suffixIcon: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.clear, color: Colors.white),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                ),
                              IconButton(
                                icon: Icon(Icons.search, color: Colors.white),
                                onPressed: () => searchYoutube(_searchController.text),
                              ),
                            ],
                          ),
                  ),
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (text) {
                    setState(() {});
                  },
                  onSubmitted: (query) {
                    searchYoutube(query);
                  },
                  textInputAction: TextInputAction.search,
                ),
                if (_showHistory && _history.isNotEmpty)
                  Container(
                      margin: EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)]
                      ),
                      constraints: BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _history.length + 1,
                          itemBuilder: (context, index) {
                              if (index == _history.length) {
                                  return InkWell(
                                      onTap: _clearHistory,
                                      child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Center(child: Text("Clear Search History", style: TextStyle(color: Colors.redAccent)))
                                      )
                                  );
                              }
                              final item = _history[index];
                              return ListTile(
                                  leading: Icon(Icons.history, color: Colors.grey),
                                  title: Text(item, style: TextStyle(color: Colors.white)),
                                  trailing: IconButton(
                                      icon: Icon(Icons.close, size: 18, color: Colors.grey),
                                      onPressed: () => _deleteHistoryItem(item),
                                  ),
                                  onTap: () {
                                      _searchController.text = item;
                                      searchYoutube(item);
                                  },
                              );
                          }
                      )
                  )
              ],
            ),
          ),
          Expanded(
            child: isOnline
                ? LiquidPullToRefresh(
              onRefresh: _handleRefresh,
              color: AppColors.primaryColor,
              animSpeedFactor: 3,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 20.0,
                  childAspectRatio: 0.85,  // Adjusted for taller cards (200px image + text) 
                ),
                padding: EdgeInsets.all(16),
                itemCount: _isLoading ? 10 : _videos.length,
                itemBuilder: (context, index) {
                  if (_isLoading) {
                    return Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[700]!,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    );
                  } else {
                    final video = _videos[index];
                    return VideoComponent(video: video);
                  }
                },
              ),
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "You're offline. Go to downloads.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}