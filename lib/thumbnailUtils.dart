import 'package:audiobinge/MyVideo.dart';
import 'package:youtube_scrape_api/models/video.dart'; // Import your Video class
import 'package:youtube_scrape_api/models/thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

Thumbnail? getHighestQualityThumbnail(List<Thumbnail>? thumbnails) {
  if (thumbnails == null || thumbnails.isEmpty) {
    return null;
  }

  List<Thumbnail> sortedThumbnails = List.from(thumbnails);
  sortedThumbnails.sort((a, b) => b.width!.compareTo(a.width!));

  return sortedThumbnails.first;
}

MyVideo processVideoThumbnails(Video video) {
  Thumbnail? highestThumbnail = getHighestQualityThumbnail(video.thumbnails);
  if (highestThumbnail != null) {
    return MyVideo(
      videoId: video.videoId,
      duration: video.duration,
      title: video.title,
      channelName: video.channelName,
      views: video.views,
      uploadDate: video.uploadDate,
      thumbnails: [highestThumbnail],
    );
  } else {
    // Fallback: construct MyVideo with original thumbnails or empty list
    return MyVideo(
      videoId: video.videoId,
      duration: video.duration,
      title: video.title,
      channelName: video.channelName,
      views: video.views,
      uploadDate: video.uploadDate,
      thumbnails: video.thumbnails,
    );
  }
}

Widget buildTimeDisplay(Duration position, Duration duration) {
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String threeDigits(int n) => n.toString().padLeft(3, "0");

    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    String milliseconds = threeDigits(duration.inMilliseconds.remainder(1000));

    if (duration.inHours > 0) {
      return "$hours:$minutes:$seconds"; // Display hours:minutes:seconds
    } else {
      return "$minutes:$seconds"; // Display minutes:seconds
    }
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        formatDuration(position),
        style: TextStyle(color: Colors.white70),
      ),
      Text(
        formatDuration(duration),
        style: TextStyle(color: Colors.white70),
      ),
    ],
  );
}

Widget buildMarqueeVideoTitle(String title) {
  return SizedBox(
    width: double.infinity, // Take up the full width
    child: Marquee(
      text: title,
      style: TextStyle(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.2,
      ),
      scrollAxis: Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.center, // Center vertically
      blankSpace: 20.0,
      velocity: 50.0,
      pauseAfterRound: Duration(seconds: 1),
      startPadding: 10.0,
      accelerationDuration: Duration(seconds: 1),
      accelerationCurve: Curves.linear,
      decelerationDuration: Duration(milliseconds: 500),
      decelerationCurve: Curves.easeOut,
    ),
  );
}