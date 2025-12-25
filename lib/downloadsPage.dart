import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:youtube_scrape_api/models/video.dart';
import 'videoComponent.dart';
import 'package:shimmer/shimmer.dart';
import 'main.dart';
import 'package:provider/provider.dart';
import 'services/download_manager.dart';
import 'MyVideo.dart';
import 'colors.dart';
import 'connectivityProvider.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  _DownloadScreenState createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    // fetchDownloads(); // Removed
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Removed manual fetchDownloads as we will listen to DownloadManager directly
  // _videos and _isLoading are no longer needed for source of truth

  Future<void> _handleRefresh() async {
    setState(
        () {}); // Trigger rebuild to re-fetch from Hive if needed, though Listeners should handle it
    return Future.value();
  }

  @override
  Widget build(BuildContext context) {
    final playing = context.watch<Playing>();
    final downloadManager = context.watch<DownloadManager>();
    final completedVideos = downloadManager.getCompletedDownloads();

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _animation,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: AppColors.primaryColor,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Downloads',
                        style: GoogleFonts.roboto(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (completedVideos.isNotEmpty) SizedBox(width: 8),
                      if (completedVideos.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => playing.setQueue(completedVideos),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          icon: Icon(Icons.play_arrow, size: 16),
                          label: Text(
                            'Play All',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: LiquidPullToRefresh(
                onRefresh: _handleRefresh,
                color: AppColors.primaryColor, // Using app's yellowish color
                backgroundColor: Colors.grey[900],
                height: 100,
                animSpeedFactor: 2,
                showChildOpacityTransition: true,
                child: Column(children: [
                  // Active Downloads Section
                  Consumer<DownloadManager>(
                      builder: (context, downloadManager, child) {
                    final active =
                        downloadManager.activeDownloads.values.toList();
                    if (active.isEmpty) return SizedBox.shrink();

                    return Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Active Downloads",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              SizedBox(height: 8),
                              ...active.map((task) => Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Row(children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      child: (task.video.thumbnails
                                                      ?.isNotEmpty ==
                                                  true &&
                                              task.video.thumbnails!.first
                                                      .url !=
                                                  null)
                                          ? Image.network(
                                              task.video.thumbnails!.first.url!,
                                              fit: BoxFit.cover)
                                          : Icon(Icons.music_note,
                                              color: Colors.white),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(
                                              task.video.title ??
                                                  "Downloading...",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          SizedBox(height: 4),
                                          LinearProgressIndicator(
                                              value: task.progress,
                                              backgroundColor: Colors.black,
                                              color: AppColors.primaryColor),
                                          SizedBox(height: 4),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(task.speed,
                                                    style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 10)),
                                                Text(
                                                    "${(task.progress * 100).toStringAsFixed(0)}%",
                                                    style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 10)),
                                              ])
                                        ])),
                                    IconButton(
                                        icon: Icon(
                                            task.status == DownloadStatus.paused
                                                ? Icons.play_arrow
                                                : Icons.pause,
                                            color: Colors.white),
                                        onPressed: () {
                                          if (task.status ==
                                              DownloadStatus.paused) {
                                            downloadManager.resumeDownload(
                                                task.video.videoId!);
                                          } else {
                                            downloadManager.pauseDownload(
                                                task.video.videoId!);
                                          }
                                        }),
                                    IconButton(
                                        icon: Icon(Icons.close,
                                            color: Colors.red),
                                        onPressed: () =>
                                            downloadManager.cancelDownload(
                                                task.video.videoId!))
                                  ])))
                            ]));
                  }),
                  Expanded(
                    child: Consumer<DownloadManager>(
                      builder: (context, downloadManager, child) {
                        return _buildContent(
                            downloadManager.getCompletedDownloads());
                      },
                    ),
                  )
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<MyVideo> videos) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done_rounded,
              size: 80,
              color: Colors.grey[700],
            ),
            SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: GoogleFonts.roboto(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your downloaded tracks will appear here',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to YouTube page to find content to download
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => YouTubeTwitchTabs()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Find Tracks to Download'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 20.0,
      ),
      padding: EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return VideoComponent(video: video);
      },
    );
  }
}
