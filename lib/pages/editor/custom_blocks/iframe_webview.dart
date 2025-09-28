// lib/pages/editor/custom_blocks/iframe_webview.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// Stub function for non-web platforms
Widget buildHtmlIFrame(String url, double height) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Center(
      child: Text('Iframe not supported on this platform'),
    ),
  );
}

class IframeWebView extends StatefulWidget {
  const IframeWebView({
    super.key,
    required this.url,
    this.gestureRecognizers,
  });

  final String url;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  @override
  State<IframeWebView> createState() => _IframeWebViewState();
}

class _IframeWebViewState extends State<IframeWebView> {
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final c = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (e) => debugPrint('Web error: ${e.description}'),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    final p = c.platform;
    if (p is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      p.setMediaPlaybackRequiresUserGesture(false);
    }

    setState(() => _controller = c);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(
          controller: _controller!,
          gestureRecognizers: widget.gestureRecognizers ??
              const <Factory<OneSequenceGestureRecognizer>>{},
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
