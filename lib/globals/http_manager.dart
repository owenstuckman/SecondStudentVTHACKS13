import 'package:url_launcher/url_launcher.dart';

import 'package:http/http.dart' as http;

class HttpManager {

  static void launchURL(String link) async {
    final Uri url = Uri.parse(link);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  static Future<String?> getIp() async {
    const String getIpUrl = "https://api.ipify.org/";
    final response = await http.get(Uri.parse(getIpUrl));
    final responseText = response.body;
    return responseText;
  }
}