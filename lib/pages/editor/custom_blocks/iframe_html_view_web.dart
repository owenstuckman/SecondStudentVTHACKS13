// Web implementation: render a real <iframe> inside HtmlElementView.

import 'package:flutter/widgets.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui' as ui;

Widget buildHtmlIFrame(String url, double height) {
  final viewType = 'iframe-${DateTime.now().microsecondsSinceEpoch}';

  // Register a factory that creates <iframe>.
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final el = html.IFrameElement()
      ..src = url
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
      ..allowFullscreen = true;
    return el;
  });

  return SizedBox(
    height: height,
    width: double.infinity,
    child: HtmlElementView(viewType: viewType),
  );
}
