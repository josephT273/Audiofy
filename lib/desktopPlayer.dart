import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'colors.dart';
import 'youtubeAudioStream.dart'; // For full screen player

class DesktopPlayer extends StatelessWidget {
  const DesktopPlayer({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    // Optional hours
    if (duration.inHours > 0) {
        return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final playing = context.watch<Playing>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ALBUM ART (Flexible + Constrained)
          Flexible(
            flex: 3,
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                 maxHeight: MediaQuery.of(context).size.height * 0.35, 
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                     if (playing.video.videoId == null) return;
                     Navigator.push(
                        context, 
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => YoutubeAudioPlayer(videoId: playing.video.videoId!),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              const begin = Offset(0.0, 1.0);
                              const end = Offset.zero;
                              final tween = Tween(begin: begin, end: end);
                              final offsetAnimation = animation.drive(tween);
                              return SlideTransition(position: offsetAnimation, child: child);
                          },
                          transitionDuration: Duration(milliseconds: 300),
                        )
                     );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                           playing.video.thumbnails != null
                          ? Image.network(
                              playing.video.thumbnails!.first.url!,
                              fit: BoxFit.cover,
                            )
                          : Container(color: Colors.grey),
                          
                          if (playing.isloading)
                            Container(
                                color: Colors.black54,
                                child: Center(child: CircularProgressIndicator(color: Colors.white))
                            )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // TITLE & INFO
          Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                Text(
                  playing.video.title ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  playing.video.channelName ?? "",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
             ]
          ),

          const SizedBox(height: 10),

          // SLIDER & CONTROLS
          Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                 SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primaryColor,
                          inactiveTrackColor: Colors.grey[800],
                          thumbColor: Colors.white,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                          trackHeight: 2,
                      ),
                      child: Slider(
                        value: playing.position.inSeconds.toDouble(),
                        max: playing.duration.inSeconds.toDouble().clamp(1, double.infinity),
                        onChanged: (v) {
                          playing.seekAudio(Duration(seconds: v.toInt()));
                        },
                      ),
                  ),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                              Text(_formatDuration(playing.position), style: TextStyle(color: Colors.grey, fontSize: 11)),
                              Text(_formatDuration(playing.duration), style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                      )
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        color: Colors.white,
                        onPressed: playing.previous,
                      ),
                      IconButton(
                        icon: Icon(
                          playing.isPlaying ? Icons.pause_circle : Icons.play_circle,
                          size: 40,
                        ),
                        color: Colors.white,
                        onPressed: () {
                          playing.isPlaying ? playing.pause() : playing.play();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        color: Colors.white,
                        onPressed: playing.next,
                      ),
                    ],
                  ),
             ]
          ),
          
          const SizedBox(height: 10),
          
          // QUEUE
          Row(
            children: [
               Icon(Icons.queue_music, color: Colors.grey, size: 18),
               SizedBox(width: 8),
               Text("Queue (${playing.queue.length})", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          Divider(color: Colors.white12),

          Expanded(
            flex: 4,
            child: ListView.separated(
              itemCount: playing.queue.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                   final video = playing.queue[index];
                   final isPlaying = video.videoId == playing.video.videoId;
                   return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      dense: true,
                      selected: isPlaying,
                      selectedTileColor: Colors.white10,
                      leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: (video.thumbnails != null && video.thumbnails!.isNotEmpty) 
                             ? Image.network(video.thumbnails!.first.url!, width: 40, height: 40, fit: BoxFit.cover)
                             : Container(width: 40, height: 40, color: Colors.grey[900])
                      ),
                      title: Text(
                          video.title ?? "Unknown", 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isPlaying ? AppColors.primaryColor : Colors.white70,
                              fontSize: 13
                          )
                      ),
                      subtitle: Text(
                          video.channelName ?? "", 
                          maxLines: 1, 
                          style: TextStyle(color: Colors.grey, fontSize: 11)
                      ),
                      onTap: () {
                          playing.assign(video, false); 
                      },
                      trailing: IconButton(
                          icon: Icon(Icons.close, size: 16, color: Colors.white30),
                          onPressed: () => playing.removeFromQueue(video),
                      ),
                   );
              },
            ),
          ),
          
          // BOTTOM CONTROLS (Shuffle/Loop)
          Container(
             padding: EdgeInsets.only(top: 8),
             child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle),
                    color: playing.isShuffling ? Colors.green : Colors.white,
                    onPressed: playing.toggleShuffle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.repeat),
                    color: playing.isLooping != 0 ? Colors.green : Colors.white,
                    onPressed: playing.toggleLooping,
                  ),
                ],
             ),
          ),
        ],
      ),
    );
  }
}
