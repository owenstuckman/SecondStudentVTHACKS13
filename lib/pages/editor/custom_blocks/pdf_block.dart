// lib/pages/editor/customBlocks/pdf_block.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/src/editor/widgets/proxy.dart' show EmbedProxy;
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Conditional import: real <iframe> on web, stub elsewhere
import 'iframe_webview.dart'
  if (dart.library.html) 'iframe_html_view_web.dart';

/// ==== Embed payload ==========================================================
/// Stores a URL (http/https, assets/, or data: URI), optional initial page, height.
class PdfBlockEmbed extends CustomBlockEmbed {
  PdfBlockEmbed({required String url, int? page, double height = 560})
      : super(kType, jsonEncode({'url': url, 'page': page, 'height': height}));

  static const String kType = 'pdf';

  static PdfBlockEmbed fromRaw(dynamic raw) {
    // raw can be String (json) or Map
    Map<String, dynamic> m;
    if (raw is String) {
      m = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } else if (raw is Map<String, dynamic>) {
      m = raw;
    } else {
      m = const {};
    }
    return PdfBlockEmbed(
      url: (m['url'] ?? '').toString(),
      page: (m['page'] is num) ? (m['page'] as num).toInt() : null,
      height: (m['height'] is num) ? (m['height'] as num).toDouble() : 560.0,
    );
  }

  Map<String, dynamic> get dataMap {
    try {
      if (data is String) return jsonDecode(data) as Map<String, dynamic>;
      if (data is Map<String, dynamic>) return data as Map<String, dynamic>;
    } catch (_) {}
    return const {'url': '', 'height': 560.0, 'page': null};
  }

  String get url => (dataMap['url'] ?? '').toString();
  double get height =>
      (dataMap['height'] is num) ? (dataMap['height'] as num).toDouble() : 560.0;
  int? get page =>
      (dataMap['page'] is num) ? (dataMap['page'] as num).toInt() : null;
}

/// ==== Builder ================================================================
class PdfEmbedBuilder implements EmbedBuilder {
  const PdfEmbedBuilder();

  @override
  String get key => PdfBlockEmbed.kType;

  @override
  bool get expanded => true;

  @override
  WidgetSpan buildWidgetSpan(Widget child) =>
      WidgetSpan(child: EmbedProxy(child));

  @override
  String toPlainText(Embed node) {
    final m = PdfBlockEmbed.fromRaw(node.value.data).dataMap;
    return '[pdf ${m['url'] ?? ''}]';
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    try {
      final m = PdfBlockEmbed.fromRaw(embedContext.node.value.data);
      final url = m.url;
      final height = m.height;
      final initialPage = m.page ?? 1;

      if (url.isEmpty) return _errorBox(context, 'Empty PDF URL');

      // Allowlist (optional)
      const allowed = [
        'drive.google.com',
        'docs.google.com',
        'github.com',
        'raw.githubusercontent.com',
        'cdn.',
      ];
      final hostOk = () {
        try {
          final host = Uri.parse(url).host;
          if (url.startsWith('assets/') || url.startsWith('data:')) return true;
          if (host.isEmpty) return false;
          return allowed.any((h) => host == h || host.endsWith(h));
        } catch (_) {
          return false;
        }
      }();
      if (!hostOk) {
        // You can relax this if you want any host.
        // return _errorBox(context, 'Blocked host for PDF:\n$url');
      }

      // On Web we use a native <iframe> (fast & simplest).
      if (kIsWeb) {
        final viewer = _buildWebIFrame(url, height);
        return EmbedProxy(
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => FocusScope.of(context).unfocus(),
            child: SizedBox(height: height, child: viewer),
          ),
        );
      }

      // On native we render pages with pdfx (zoom/pinch and controls).
      return EmbedProxy(
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SizedBox(
            height: height,
            child: _PdfNativeViewer(url: url, initialPage: initialPage),
          ),
        ),
      );
    } catch (e) {
      return _errorBox(context, 'PDF embed failed:\n$e');
    }
  }

  Widget _buildWebIFrame(String url, double height) {
    // Most browsers render PDFs inline if the server allows it.
    // If a host blocks inline PDFs (e.g., X-Frame-Options), the user can click "Open".
    // Reuse your existing view-factory helper from the iframe block.
    return buildHtmlIFrame(url, height);
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

/// ==== Native viewer widget (iOS/Android/macOS/Windows) ======================
class _PdfNativeViewer extends StatefulWidget {
  const _PdfNativeViewer({
    required this.url,
    required this.initialPage,
  });

  final String url;
  final int initialPage;

  @override
  State<_PdfNativeViewer> createState() => _PdfNativeViewerState();
}

class _PdfNativeViewerState extends State<_PdfNativeViewer> {
  PdfControllerPinch? _controller;
  int _pages = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final bytes = await _loadBytes(widget.url);

      // Controller expects a Future<PdfDocument>
      final futureDoc = PdfDocument.openData(bytes);

      // Resolve once to get page count
      final doc = await futureDoc;
      _pages = doc.pagesCount;

      setState(() {
        _controller = PdfControllerPinch(
          document: PdfDocument.openData(bytes), // pass Future, not resolved doc
          initialPage: widget.initialPage,
        );
      });
    } catch (e) {
      debugPrint('PDF load error: $e');
      setState(() => _controller = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return _LoadingOrError(url: widget.url);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        SizedBox(
          height: 40,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final p = c.pageListenable.value;
                  if (p > 1) c.jumpToPage(p - 1);
                },
              ),
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final p = c.pageListenable.value;
                  if (p < _pages) c.jumpToPage(p + 1);
                },
              ),
              ValueListenableBuilder<int>(
                valueListenable: c.pageListenable,
                builder: (_, page, __) => Text(
                  '$page / $_pages',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Open externally',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => launchUrlString(
                  widget.url,
                  mode: LaunchMode.platformDefault,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PdfViewPinch(
            controller: c,
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              pageLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, err) => Center(
                child:
                    Text('Failed to render PDF\n$err', textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List> _loadBytes(String url) async {
    if (url.startsWith('assets/')) {
      final data = await rootBundle.load(url);
      return data.buffer.asUint8List();
    }
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final header = url.substring(0, comma);
      final b64 = url.substring(comma + 1);
      if (header.contains(';base64')) {
        return Uint8List.fromList(base64Decode(b64));
      }
      return Uint8List.fromList(utf8.encode(Uri.decodeFull(b64)));
    }
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text('Loading PDF…', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
