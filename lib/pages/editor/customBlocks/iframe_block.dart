// at top of file
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:secondstudent/pages/editor/customblocks.dart';
import 'package:flutter_quill/src/editor/widgets/proxy.dart' show EmbedProxy;

// Conditional import to avoid web-only APIs on macOS/desktop/mobile
import 'iframe_html_view_stub.dart'
    if (dart.library.html) 'iframe_html_view_web.dart';

class IframeEmbedBuilder implements EmbedBuilder {
  const IframeEmbedBuilder();

  @override
  String get key => IframeBlockEmbed.kType;

  @override
  bool get expanded => true;

  // 👇 Important: return EmbedProxy so Quill hit-testing treats this as an embed.
  @override
  WidgetSpan buildWidgetSpan(Widget child) =>
      WidgetSpan(child: EmbedProxy(child));

  @override
  String toPlainText(Embed node) {
    final m = IframeBlockEmbed.fromRaw(node.value.data).dataMap;
    return '[iframe ${m['url'] ?? ''}]';
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    try {
      final m = IframeBlockEmbed.fromRaw(embedContext.node.value.data).dataMap;
      final url = (m['url'] ?? '').toString();
      final height =
          (m['height'] is num) ? (m['height'] as num).toDouble() : 420.0;
      if (url.isEmpty) return _errorBox(context, 'Empty iframe URL');

      // allowlist (expand as you like)
      const allowed = [
        'app.excalidraw.com',
        'excalidraw.com',
        'docs.google.com',
        'drive.google.com',
        'www.youtube.com',
        'player.vimeo.com',
      ];
      final hostOk = () {
        try {
          return allowed.any((h) => Uri.parse(url).host.endsWith(h));
        } catch (_) {
          return false;
        }
      }();
      if (!hostOk) return _errorBox(context, 'Blocked host:\n$url');

      // Build the actual view (web uses <iframe>, others use WebView)
      final view = kIsWeb
          ? buildHtmlIFrame(url, height)
          : _buildPlatformWebView(url, height, context);

      // 👇 Wrap with EmbedProxy AND unfocus editor on pointer down so gestures pass through
      return EmbedProxy(
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            final scope = FocusScope.of(context);
            if (scope.hasFocus) scope.unfocus();
          },
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
    } catch (e) {
      return _errorBox(context, 'Embed failed:\n$e');
    }
  }

  Widget _buildPlatformWebView(String url, double height, BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      // Avoid setBackgroundColor on macOS (throws: "opaque is not implemented")
      ..loadRequest(Uri.parse(url));
    return WebViewWidget(controller: controller);
  }

  Widget _errorBox(BuildContext context, String msg) => Container(
        height: 140,
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.error),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(msg, textAlign: TextAlign.center),
      );
}
