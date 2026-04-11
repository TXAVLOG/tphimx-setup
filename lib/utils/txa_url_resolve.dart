import 'package:http/http.dart' as http;

class TxaUrlResolve {
  /// Main resolve function
  static Future<Map<String, dynamic>> resolve(String url) async {
    if (url.isEmpty || !url.startsWith('http')) {
      return {'success': false, 'error': 'Invalid URL'};
    }

    if (url.contains('github.com')) {
      return await resolveGitHub(url);
    }

    if (url.contains('mediafire.com')) {
      return await resolveMediaFire(url);
    }

    if (url.contains('drive.google.com')) {
      return await resolveGoogleDrive(url);
    }

    return {'success': true, 'url': url, 'type': 'direct'};
  }

  /// Resolve GitHub URL
  static Future<Map<String, dynamic>> resolveGitHub(String url) async {
    try {
      if (url.contains('/blob/')) {
        final String direct = url
            .replaceFirst('github.com', 'raw.githubusercontent.com')
            .replaceFirst('/blob/', '/');
        return {'success': true, 'url': direct, 'type': 'github-raw'};
      }

      if (url.contains('/releases/download/')) {
        return {'success': true, 'url': url, 'type': 'github-release'};
      }

      return {'success': true, 'url': url, 'type': 'github'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Resolve MediaFire URL (Basic implementation - scraping direct link)
  static Future<Map<String, dynamic>> resolveMediaFire(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final String html = response.body;

      // Extract direct download link
      final RegExp matchRegex = RegExp(r'''https?://download\.mediafire\.com/[^\s"'>]+''');
      final RegExpMatch? match = matchRegex.firstMatch(html);
      
      if (match != null) {
        final String? directUrl = match.group(0);
        if (directUrl != null) {
          return {'success': true, 'url': directUrl, 'type': 'mediafire-direct'};
        }
      }

      final RegExp buttonRegex = RegExp(r'''href="(https?://[^"]+)"[^>]*id="downloadButton"''');
      final RegExpMatch? buttonMatch = buttonRegex.firstMatch(html);
      
      if (buttonMatch != null) {
        final String? buttonUrl = buttonMatch.group(1);
        if (buttonUrl != null) {
          return {'success': true, 'url': buttonUrl, 'type': 'mediafire-button'};
        }
      }

      throw Exception('Download link not found');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Resolve Google Drive URL
  static Future<Map<String, dynamic>> resolveGoogleDrive(String url) async {
    try {
      final RegExp fileIdRegex = RegExp(r'[-\w]{25,}');
      final RegExpMatch? fileIdMatch = fileIdRegex.firstMatch(url);
      
      if (fileIdMatch == null) {
        throw Exception('Invalid Google Drive file ID');
      }

      final String? fileId = fileIdMatch.group(0);
      if (fileId == null) {
        throw Exception('File ID extraction failed');
      }
      
      final String directUrl = 'https://drive.google.com/uc?export=download&id=$fileId';

      return {'success': true, 'url': directUrl, 'type': 'gdrive'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
