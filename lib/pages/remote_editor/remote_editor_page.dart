import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:secondstudent/pages/editor/editor/editor.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

class RemoteEditorPage extends StatefulWidget {
  final String fileUrl;
  final Map<String, String>? headers;
  final String fileName;
  const RemoteEditorPage({
    super.key,
    required this.fileUrl,
    this.headers,
    required this.fileName,
  });

  @override
  State<RemoteEditorPage> createState() => _RemoteEditorPageState();
}

class _RemoteEditorPageState extends State<RemoteEditorPage> {
  String? _json;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final resp = await http.get(
        Uri.parse(widget.fileUrl),
        headers: widget.headers,
      );
      if (resp.statusCode == 200) {
        _json = utf8.decode(resp.bodyBytes);
      } else {
        _error = 'HTTP ${resp.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: Center(child: Text('Error: $_error')),
      );
    }
    String jsonToLoad = _json ?? '';
    if (!(widget.fileName.toLowerCase().endsWith('.json'))) {
      // convert plain text/markdown into a simple delta JSON
      jsonToLoad = jsonEncode([
        {'insert': jsonToLoad + '\n'},
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: EditorScreen(initialJson: jsonToLoad, fileLabel: widget.fileName),
    );
  }
}
