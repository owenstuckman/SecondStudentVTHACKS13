import 'package:flutter/widgets.dart' show SizedBox, Widget;

Widget buildHtmlIFrame(String url, double height) {
  // Non-web platforms: caller should not use this path, but return a placeholder.
  return const SizedBox.shrink();
}


