// Iframe embed for FlutterQuill: web uses <iframe>, mobile/desktop use webview_flutter.
//
// Usage (when creating the editor):
// quill.QuillEditor.basic(
//   controller: controller,
//   config: quill.QuillEditorConfig(
//     embedBuilders: [
//       const IframeEmbedBuilder(),
//       // ...other builders
//     ],
//   ),
// );

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_quill/src/editor/widgets/proxy.dart' show EmbedProxy;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:secondstudent/pages/editor/custom_blocks/customblocks.dart';

// Conditional import: actual <iframe> view on web, no-op elsewhere.
import 'iframe_html_view_stub.dart'
    if (dart.library.html) 'iframe_html_view_web.dart';

class IframeEmbedBuilder implements quill.EmbedBuilder {
  const IframeEmbedBuilder();

  @override
  String get key => 'iframe'; // Fixed the undefined name error

  @override
  bool get expanded => true;

  // Ensure Quill treats this as an embed (hit-testing/selection).
  @override
  WidgetSpan buildWidgetSpan(Widget child) =>
      WidgetSpan(child: EmbedProxy(child));

  @override
  String toPlainText(quill.Embed node) {
    final m = _fromRaw(node.value.data); // Updated to use a defined method
    return '[iframe ${m['url'] ?? ''}]';
  }

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    try {
      final m = _fromRaw(
        embedContext.node.value.data,
      ); // Updated to use a defined method
      final rawUrl = (m['url'] ?? '').toString().trim();
      final height = (m['height'] is num)
          ? (m['height'] as num).toDouble()
          : 420.0;

      if (rawUrl.isEmpty) return _errorBox(context, 'Empty iframe URL');

      final url = _toEmbeddableUrl(rawUrl);

      // Allowlist hosts (expand as you like).
      const allowed = <String>[
        'app.excalidraw.com',
        'excalidraw.com',
        'docs.google.com',
        'drive.google.com',
        'www.youtube.com',
        'youtube.com',
        'youtu.be',
        'player.vimeo.com',
        'vimeo.com',
      ];
      final hostOk = () {
        try {
          final host = Uri.parse(url).host.toLowerCase();
          return allowed.any((h) => host == h || host.endsWith('.$h'));
        } catch (_) {
          return false;
        }
      }();
      if (!hostOk) {
        return _errorBox(context, 'Blocked host:\n$url');
      }

      final view = kIsWeb
          ? buildHtmlIFrame(url, height)
          : _buildPlatformWebView(url, height, context);

      // On web we can clip nicely; on platform views avoid clipping to prevent black boxes.
      if (kIsWeb) {
        return EmbedProxy(
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => FocusScope.of(context).unfocus(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: view,
                ),
              ),
            ),
          ),
        );
      } else {
        return EmbedProxy(
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => FocusScope.of(context).unfocus(),
            child: SizedBox(height: height, child: view),
          ),
        );
      }
    } catch (e) {
      return _errorBox(context, 'Embed failed:\n$e');
    }
  }

  // Method to convert raw data to a usable format
  Map<String, dynamic> _fromRaw(String raw) {
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  // Normalize common share URLs to embeddable endpoints.
  String _toEmbeddableUrl(String raw) {
    Uri u;
    try {
      u = Uri.parse(raw);
    } catch (_) {
      return raw;
    }

    // YouTube: watch/shorts/share -> /embed/ID
    if (u.host.contains('youtube.com') ||
        u.host == 'youtu.be' ||
        u.host == 'www.youtu.be') {
      String? id;
      if (u.host.contains('youtube.com')) {
        id = u.queryParameters['v'];
        // shorts/{id}
        if (id == null && u.pathSegments.contains('shorts')) {
          final i = u.pathSegments.indexOf('shorts');
          if (i >= 0 && i + 1 < u.pathSegments.length)
            id = u.pathSegments[i + 1];
        }
        // embed/{id} already okay
        if (u.pathSegments.contains('embed') && u.pathSegments.isNotEmpty) {
          return raw;
        }
      } else {
        // youtu.be/{id}
        if (u.pathSegments.isNotEmpty) id = u.pathSegments.first;
      }
      if (id != null && id.isNotEmpty)
        return 'https://www.youtube.com/embed/$id';
    }

    // Vimeo: vimeo.com/{id} -> player.vimeo.com/video/{id}
    if (u.host.contains('vimeo.com') && !u.host.contains('player.')) {
      final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
      final id = segs.isNotEmpty ? segs.last : null;
      if (id != null && int.tryParse(id) != null) {
        return 'https://player.vimeo.com/video/$id';
      }
    }

    // Google Docs/Sheets/Slides: /{app}/d/{id}/... -> /{app}/d/{id}/preview
    if (u.host.endsWith('docs.google.com')) {
      final segs = u.pathSegments;
      final dIndex = segs.indexOf('d');
      if (dIndex > 0 && dIndex + 1 < segs.length) {
        final id = segs[dIndex + 1];
        final app = segs.first; // document | spreadsheets | presentation
        return 'https://docs.google.com/$app/d/$id/preview';
      }
    }

    // Google Drive: /file/d/{id}/view -> /file/d/{id}/preview
    if (u.host.endsWith('drive.google.com')) {
      final segs = u.pathSegments;
      final idx = segs.indexOf('d');
      if (idx >= 0 && idx + 1 < segs.length) {
        final id = segs[idx + 1];
        return 'https://drive.google.com/file/d/$id/preview';
      }
    }

    // Excalidraw: ensure ?embed=1
    if (u.host.endsWith('excalidraw.com')) {
      final m = Map<String, String>.from(u.queryParameters);
      m['embed'] = '1';
      return u.replace(queryParameters: m).toString();
    }

    return raw; // default: hope it’s embeddable
  }

  Widget _buildPlatformWebView(
    String url,
    double height,
    BuildContext context,
  ) {
    // webview_flutter supports Android/iOS/macOS; gate others.
    if (Platform.isWindows || Platform.isLinux) {
      return _errorBox(context, 'WebView not supported on this platform');
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent) // Fix for background color
      ..enableZoom(true)
      ..loadRequest(Uri.parse(url));
    return WebViewWidget(controller: controller);
  }

  Widget _errorBox(BuildContext context, String msg) => Container(
    height: 160,
    padding: const EdgeInsets.all(12),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.error),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(msg, textAlign: TextAlign.center),
  );
}
