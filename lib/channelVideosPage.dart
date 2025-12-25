import 'package:audiofy/bottomPlayer.dart';
import 'package:audiofy/downloadsPage.dart';
import 'package:audiofy/favoritePage.dart';
import 'package:audiofy/main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'MyVideo.dart';
import 'videoComponent.dart';
import 'fetchYoutubeStreamUrl.dart';

class ChannelVideosPage extends StatefulWidget {
  final String videoId;
  final String channelName;
  static String channelAvatar =
      'https://t3.ftcdn.net/jpg/03/53/11/00/360_F_353110097_nbpmfn9iHlxef4EDIhXB1tdTD0lcWhG9.jpg';
  static String channelArt = '';
  static String totalVideos = '0', totalSubscribers = '0';
  const ChannelVideosPage(
      {super.key, required this.videoId, required this.channelName});

  @override
  _ChannelVideosPageState createState() => _ChannelVideosPageState();
}

class _ChannelVideosPageState extends State<ChannelVideosPage> {
  List<MyVideo> channelVideos = [];
  bool _isLoading = true; // Loading state
  int _selectedIndex = 0;
  List<Widget> get _pages =>
      [channelVideoScreen(), FavoriteScreen(), DownloadScreen()];

  @override
  void initState() {
    super.initState();
    _fetchChannelVideos();
  }

  Future<void> _fetchChannelVideos() async {
    print('object called');
    setState(() {
      _isLoading = true;
    });
    final scrapedVideos = await fetchVideosFromChannel(widget.videoId);
    setState(() {
      channelVideos = scrapedVideos
          .where((v) => v.title != null && v.title!.isNotEmpty)
          .map((v) {
        return MyVideo(
          videoId: v.videoId,
          duration: v.duration,
          title: v.title,
          channelName: v.channelName,
          views: v.views,
          uploadDate: v.uploadDate,
          thumbnails: v.thumbnails,
        );
      }).toList();
      _isLoading = false;
    });
  }

  void _onItemTapped(int index, BuildContext context) {
    setState(() {
      if (_selectedIndex == 0 && index == 0) {
        Navigator.pop(context);
      }
      _selectedIndex = index;
    });
  }

  Widget _buildCountInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        SizedBox(width: 8),
        Text(text,
            style: GoogleFonts.roboto(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            )),
      ],
    );
  }

  Widget channelVideoScreen() {
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: Colors.red))
        : channelVideos.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.video_library_outlined,
                        size: 60, color: Colors.white54),
                    SizedBox(height: 20),
                    Text('No Videos Available',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 10),
                    Text('This channel hasn\'t uploaded any content yet',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.white70)),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(ChannelVideosPage.channelArt),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.6), BlendMode.darken),
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(25),
                        bottomRight: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: NetworkImage(
                                    ChannelVideosPage.channelAvatar),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.channelName,
                                    style: GoogleFonts.robotoCondensed(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Video Collection',
                                    style: GoogleFonts.roboto(
                                      fontSize: 16,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            _buildCountInfo(Icons.video_library,
                                ChannelVideosPage.totalVideos),
                            SizedBox(width: 20),
                            _buildCountInfo(Icons.person_outline,
                                ChannelVideosPage.totalSubscribers),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 600 ? 3 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: channelVideos.length,
                        itemBuilder: (context, index) {
                          return VideoComponent(video: channelVideos[index]);
                        },
                      ),
                    ),
                  ),
                ],
              );
  }

  @override
  Widget build(BuildContext context) {
    final playing = context.watch<Playing>();
    return Scaffold(
      appBar: CustomAppBar(),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _pages[_selectedIndex],
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
          // BottomPlayer overlay
          if (playing.video.title != null && playing.isPlayerVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom:
                  kBottomNavigationBarHeight, // adjust to sit above the nav bar
              child: BottomPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // adjust if needed
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Channel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_sharp),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_for_offline_rounded),
            label: 'Downloads',
          ),
        ],
        onTap: (index) => _onItemTapped(index, context),
      ),
    );
  }
}
