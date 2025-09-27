import 'dart:convert';
import 'package:http/http.dart' as http;

class CanvasFullQuery {
  static Future<List<dynamic>> fetchAllPages(
    Uri initialUrl,
    Map<String, String> headers,
  ) async {
    final List<dynamic> all = [];
    Uri? url = initialUrl;
    while (url != null) {
      try {
        final response = await http.get(url, headers: headers);
        if (response.statusCode != 200) break;
        final body = jsonDecode(response.body);
        if (body is List) {
          all.addAll(body);
        }
        url = _nextLinkFromHeader(response.headers['link']);
      } catch (_) {
        break;
      }
    }
    return all;
  }

  static Uri? _nextLinkFromHeader(String? linkHeader) {
    if (linkHeader == null) return null;
    final parts = linkHeader.split(',');
    for (final rawPart in parts) {
      final part = rawPart.trim();
      final urlMatch = RegExp(r'<([^>]+)>').firstMatch(part);
      final relMatch = RegExp(r'rel="([^"]+)"').firstMatch(part);
      if (urlMatch != null && relMatch != null) {
        final rel = relMatch.group(1);
        if (rel == 'next') {
          final urlStr = urlMatch.group(1);
          if (urlStr != null) return Uri.parse(urlStr);
        }
      }
    }
    return null;
  }
}
