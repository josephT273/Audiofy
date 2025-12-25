import 'package:http/http.dart' as http;
import 'dart:convert';

class InvidiousService {
  // Public Invidious instances (privacy-focused YouTube frontends)
  // Updated with more reliable instances for Android compatibility
  static const instances = [
    'https://invidious.Private.coffee',
    'https://iv.ggtyler.dev',
    'https://invidious.io.lol',
    'https://inv.tux.pizza',
    'https://invidious.nerdvpn.de',
  ];

  /// Fetch stream URL from Invidious API as fallback
  Future<String?> getStreamUrl(String videoId) async {
    for (var instance in instances) {
      try {
        print('Trying Invidious instance: $instance');
        final response = await http.get(
          Uri.parse('$instance/api/v1/videos/$videoId'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final audioFormats = data['adaptiveFormats'] as List;

          // Filter for audio-only formats
          final audioOnly = audioFormats
              .where((f) => f['type'].toString().contains('audio'))
              .toList();

          if (audioOnly.isEmpty) {
            print('No audio formats found on $instance');
            continue;
          }

          // Get highest quality audio
          final audio = audioOnly.reduce(
              (a, b) => (a['bitrate'] ?? 0) > (b['bitrate'] ?? 0) ? a : b);

          final url = audio['url'];
          print(
              'Successfully fetched from Invidious (bitrate: ${audio['bitrate']})');
          return url;
        } else {
          print(
              'Invidious instance $instance returned status ${response.statusCode}');
        }
      } catch (e) {
        print('Invidious instance $instance failed: $e');
      }
    }

    print('All Invidious instances failed');
    return null;
  }
}
