import 'package:flutter/widgets.dart' show HtmlElementView, Widget;
import 'package:web/web.dart' as html;
import 'dart:ui_web' as ui;

Widget buildHtmlIFrame(String url, double height) {
  final viewType = 'iframe-${url.hashCode}-${height.toInt()}';
  try {
    ui.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final el = html.HTMLIFrameElement()
        ..src = url
        ..style.border = '0'
        ..allowFullscreen = true
        ..allow = 'clipboard-read; clipboard-write; microphone; camera; fullscreen';
      return el;
    });
  } catch (_) {}
  return HtmlElementView(viewType: viewType);
}


