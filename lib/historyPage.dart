import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart'; // leveraging if available or use Image.network
import 'services/history_service.dart';
import 'MyVideo.dart';
import 'main.dart'; // for Playing provider
import 'colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MyVideo> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });
    // Add small delay to ensure Hive is ready or just UI feel
    await Future.delayed(Duration(milliseconds: 100));
    List<MyVideo> history = HistoryService().getHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }
  
  void _clearHistory() async {
      await HistoryService().clearHistory();
      _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Watch History', style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
            IconButton(
                icon: Icon(Icons.delete_sweep, color: Colors.white),
                onPressed: () {
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                        title: Text("Clear History"),
                        content: Text("Are you sure you want to clear your watch history?"),
                        actions: [
                            TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
                            TextButton(child: Text("Clear", style: TextStyle(color: Colors.red)), onPressed: () {
                                _clearHistory();
                                Navigator.pop(ctx);
                            })
                        ]
                    ));
                }
            )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey[700]),
                      SizedBox(height: 16),
                      Text("No history yet", style: TextStyle(color: Colors.grey, fontSize: 18))
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: 100), // Space for player
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final video = _history[index];
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: (video.thumbnails != null && 
                                video.thumbnails!.isNotEmpty && 
                                video.thumbnails!.first.url != null)
                            ? Image.network(
                                video.thumbnails!.first.url!, 
                                width: 80, 
                                height: 45, 
                                fit: BoxFit.cover,
                                errorBuilder: (c,o,s) => Container(width: 80, height: 45, color: Colors.grey[800], child: Icon(Icons.music_note, color: Colors.white))
                              )
                            : Container(width: 80, height: 45, color: Colors.grey[800], child: Icon(Icons.music_note, color: Colors.white)),
                      ),
                      title: Text(video.title ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      subtitle: Text(video.channelName ?? "Unknown Artist", style: TextStyle(color: Colors.grey)),
                      onTap: () {
                        // Play this video
                        Provider.of<Playing>(context, listen: false).assign(video, true);
                      },
                    );
                  },
                ),
    );
  }
}
