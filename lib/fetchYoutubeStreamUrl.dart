import 'package:audiofy/channelVideosPage.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import 'package:youtube_scrape_api/models/video.dart';
import 'package:youtube_scrape_api/youtube_scrape_api.dart' as scraper;

Future<String> fetchYoutubeStreamUrl(String id) async {
  final yt = YoutubeExplode();
  try {
    StreamManifest? manifest;
    // Try multiple clients for better compatibility
    final List<List<YoutubeApiClient>> clients = [
      [YoutubeApiClient.ios],
      [YoutubeApiClient.androidVr],
      [YoutubeApiClient.android],
      [YoutubeApiClient.tv],
    ];

    for (final clientList in clients) {
      try {
        manifest =
            await yt.videos.streams.getManifest(id, ytClients: clientList);
        if (manifest.audioOnly.isNotEmpty) break;
      } catch (e) {
        print('Client failed, trying next... $e');
      }
    }

    if (manifest == null || manifest.audioOnly.isEmpty) {
      throw Exception('No audio streams found for video $id');
    }

    final audio = manifest.audioOnly.withHighestBitrate();
    return audio.url.toString();
  } finally {
    yt.close();
  }
}

Future<Stream<List<int>>> fetchAcutalStream(String id) async {
  final yt = YoutubeExplode();
  final manifest = await yt.videos.streams.getManifest(id,
      // You can also pass a list of preferred clients, otherwise the library will handle it:
      ytClients: [
        YoutubeApiClient.androidVr,
        YoutubeApiClient.android,
        YoutubeApiClient.tv,
        YoutubeApiClient.ios,
      ]);

  // Print all the available streams.
  print('fetched url');
  final audio = manifest.audioOnly.withHighestBitrate();
  var stream = yt.videos.streams.get(audio);
  yt.close();
  return stream;
}

Future<List<ClosedCaption>> fetchYoutubeClosedCaptions(String id) async {
  var yt = YoutubeExplode();

  var trackManifest = await yt.videos.closedCaptions.getManifest(id);

  var trackInfo = trackManifest.getByLanguage('en'); // Get english caption.

  // Get the actual closed caption track.
  if (trackInfo.isNotEmpty) {
    var track = await yt.videos.closedCaptions.get(trackInfo.first);
    var captions = track.captions;
    return captions;
  }
  return [];
}

String getCaptionAtTime(List<ClosedCaption> captions, Duration time) {
  for (var caption in captions) {
    if (time.inMilliseconds <= caption.end.inMilliseconds) {
      return caption.text;
    }
  }
  return "";
}

Future<List<Video>> fetchVideosFromChannel(String videoId) async {
  try {
    // Ensure the channel name starts with '@'

    var channelId = await scraper.YoutubeDataApi().fetchVideoData(videoId);

    var channelVids = await scraper.YoutubeDataApi()
        .fetchChannelData(channelId?.video?.channelId ?? "");
    if (channelVids == null) {
      print("No data returned for channel '$videoId'");
      return [];
    }
    print(
        "Fetched ${channelVids.videosList.length} videos for channel '$videoId'");
    ChannelVideosPage.channelAvatar = channelVids.channel.avatar!;
    ChannelVideosPage.channelArt = channelVids.channel.banner!;
    ChannelVideosPage.totalSubscribers = channelVids.channel.subscribers!;
    ChannelVideosPage.totalVideos = channelVids.channel.videoCounts!;
    return channelVids.videosList;
  } catch (e) {
    print("Error fetching videos for channel '$videoId': $e");
    return [];
  }
}
