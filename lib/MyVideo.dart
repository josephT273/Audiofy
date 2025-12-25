import 'package:youtube_scrape_api/models/thumbnail.dart';
import 'package:youtube_scrape_api/models/video.dart';
class MyVideo extends Video {
  final String? localimage;
  late final String? localaudio;
  // Add more custom fields as needed

  MyVideo({
    String? videoId,
    String? duration,
    String? title,
    String? channelName,
    String? views,
    String? uploadDate,
    List<Thumbnail>? thumbnails,
    this.localimage,
    this.localaudio,
    // Add custom fields to the constructor
  }) : super(
    videoId: videoId,
    duration: duration,
    title: title,
    channelName: channelName,
    views: views,
    uploadDate: uploadDate,
    thumbnails: thumbnails,
  );

  factory MyVideo.fromMap(Map<String, dynamic>? map, {String? localimage, String? localaudio}) {
    if (map == null) return MyVideo();
    Video video = Video.fromMap(map); // Create a regular Video object first

    return MyVideo(
      videoId: video.videoId,
      duration: video.duration,
      title: video.title,
      channelName: video.channelName,
      views: video.views,
      uploadDate: video.uploadDate,
      thumbnails: video.thumbnails,
      localimage: localimage ?? map['localimage'],
      localaudio: localaudio ?? map['localaudio'],
    );
  }

  factory MyVideo.fromJson(Map<String, dynamic> json) {
    return MyVideo(
      videoId: json['videoId'],
      duration: json['duration'],
      title: json['title'],
      channelName: json['channelName'],
      views: json['views'],
      uploadDate: json['uploadDate'],
      thumbnails: (json['thumbnails'] as List<dynamic>?)
          ?.map((t) => ThumbnailJson.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
      localimage: json['localimage'],
      localaudio: json['localaudio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'duration': duration,
      'title': title,
      'channelName': channelName,
      'views': views,
      'uploadDate': uploadDate,
      'thumbnails': thumbnails?.map((t) => t.toJson()).toList(),
      'localimage': localimage,
      'localaudio': localaudio,
    };
  }
}

extension ThumbnailJson on Thumbnail {
  Map<String, dynamic> toJson() => {
        'url': url,
        'width': width,
        'height': height,
      };

  static Thumbnail fromJson(Map<String, dynamic> json) => Thumbnail(
        url: json['url'],
        width: json['width'],
        height: json['height'],
      );
}

