import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/src/editor/widgets/proxy.dart' show EmbedProxy;

// Import webview for all platforms
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Wrapper for the Quill custom block payload.
class IframeBlockEmbed extends quill.CustomBlockEmbed {
  static const String kType = 'iframe';
  IframeBlockEmbed({required String url, required double height})
      : super(kType, jsonEncode({'url': url, 'height': height}));

  static IframeBlockEmbed fromRaw(String raw) {
    Map<String, dynamic> m;
    try { m = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { m = {}; }
    final url = (m['url'] as String?) ?? '';
    final height = (m['height'] is num) ? (m['height'] as num).toDouble() : 420.0;
    return IframeBlockEmbed(url: url, height: height);
  }
}

class IframeEmbedBuilder implements quill.EmbedBuilder {
  const IframeEmbedBuilder();

  @override
  String get key => IframeBlockEmbed.kType;

  @override
  bool get expanded => true;

  @override
  WidgetSpan buildWidgetSpan(Widget child) => WidgetSpan(child: EmbedProxy(child));

  @override
  String toPlainText(quill.Embed node) {
    final m = _fromRaw(node.value.data);
    return '[iframe ${m['url'] ?? ''}]';
    }

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    try {
      final m = _fromRaw(embedContext.node.value.data);
      final rawUrl = (m['url'] ?? '').toString().trim();
      final height = (m['height'] is num) ? (m['height'] as num).toDouble() : 420.0;
      if (rawUrl.isEmpty) return _errorBox(context, 'Empty iframe URL');

      final url = toEmbeddableUrl(rawUrl);

      const allowed = <String>[
        'app.excalidraw.com','excalidraw.com',
        'docs.google.com','drive.google.com',
        'www.youtube.com','youtube.com','youtu.be',
        'player.vimeo.com','vimeo.com',
      ];
      final hostOk = () {
        try {
          final h = Uri.parse(url).host.toLowerCase();
          return allowed.any((x) => h == x || h.endsWith('.$x'));
        } catch (_) { return false; }
      }();
      if (!hostOk) return _errorBox(context, 'Blocked host:\n$url');

      final view = SizedBox(height: height, child: _UnifiedIframe(url: url));

      return EmbedProxy(
        Listener(
          behavior: HitTestBehavior.translucent,
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
    } catch (e) {
      return _errorBox(context, 'Embed failed:\n$e');
    }
  }

  Map<String, dynamic> _fromRaw(String raw) {
    try { return json.decode(raw) as Map<String, dynamic>; } catch (_) { return {}; }
  }

  String toEmbeddableUrl(String raw) {
    Uri u; try { u = Uri.parse(raw); } catch (_) { return raw; }
    // YouTube
    if (u.host.contains('youtube.com') || u.host == 'youtu.be' || u.host == 'www.youtu.be') {
      String? id;
      if (u.host.contains('youtube.com')) {
        id = u.queryParameters['v'];
        if (id == null && u.pathSegments.contains('shorts')) {
          final i = u.pathSegments.indexOf('shorts');
          if (i >= 0 && i + 1 < u.pathSegments.length) id = u.pathSegments[i + 1];
        }
        if (u.pathSegments.contains('embed')) return raw;
      } else if (u.pathSegments.isNotEmpty) {
        id = u.pathSegments.first;
      }
      if (id != null && id.isNotEmpty) return 'https://www.youtube.com/embed/$id';
    }
    // Vimeo
    if (u.host.contains('vimeo.com') && !u.host.contains('player.')) {
      final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
      final id = segs.isNotEmpty ? segs.last : null;
      if (id != null && int.tryParse(id) != null) {
        return 'https://player.vimeo.com/video/$id';
      }
    }
    // Google Docs
    if (u.host.endsWith('docs.google.com')) {
      final segs = u.pathSegments;
      final dIndex = segs.indexOf('d');
      if (dIndex > 0 && dIndex + 1 < segs.length) {
        final id = segs[dIndex + 1];
        final app = segs.first;
        return 'https://docs.google.com/$app/d/$id/preview';
      }
    }
    // Google Drive
    if (u.host.endsWith('drive.google.com')) {
      final segs = u.pathSegments;
      final idx = segs.indexOf('d');
      if (idx >= 0 && idx + 1 < segs.length) {
        final id = segs[idx + 1];
        return 'https://drive.google.com/file/d/$id/preview';
      }
    }
    // Excalidraw
    if (u.host.endsWith('excalidraw.com')) {
      final m = Map<String, String>.from(u.queryParameters);
      m['embed'] = '1';
      return u.replace(queryParameters: m).toString();
    }
    return raw;
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

class _UnifiedIframe extends StatefulWidget {
  final String url;
  
  const _UnifiedIframe({required this.url});

  @override
  State<_UnifiedIframe> createState() => _UnifiedIframeState();
}

class _UnifiedIframeState extends State<_UnifiedIframe> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupWebView();
  }

  void _setupWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
          onWebResourceError: (e) => debugPrint('Web error: ${e.description}'),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
