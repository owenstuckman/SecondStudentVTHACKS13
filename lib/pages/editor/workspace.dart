// lib/pages/editor/workspace.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'editor/editor.dart';
import 'file_system/file_system_viewer.dart';

class EditorWorkspace extends StatefulWidget {
  const EditorWorkspace({super.key});

  @override
  State<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends State<EditorWorkspace> {
  final GlobalKey _editorKey = GlobalKey();

  double _leftWidth = 300;
  bool _showSidebar = true;

  @override
  void initState() {
    super.initState();
    _ensureWorkspacePath();          // <- NEW: make sure a sane default exists
    _restoreLayoutPrefs();
  }

  /// Choose a default, writable workspace per platform and persist it if missing.
  Future<void> _ensureWorkspacePath() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('path_to_files');
    if (existing != null && existing.trim().isNotEmpty) return;

    String path;
    if (kIsWeb) {
      // No native FS. Your FileStorage page can swap to IndexedDB later.
      path = 'web://workspace';
    } else if (Platform.isMacOS) {
      // ~/Library/Application Support/<bundle-id>/SecondStudent/workspace
      final support = await getApplicationSupportDirectory();
      final ws = Directory(p.join(support.path, 'SecondStudent', 'workspace'));
      if (!await ws.exists()) await ws.create(recursive: true);
      path = ws.path;
    } else if (Platform.isWindows || Platform.isLinux) {
      // App documents dir (writable). If you prefer real "Documents", add a helper or another plugin.
      final docs = await getApplicationDocumentsDirectory();
      final ws = Directory(p.join(docs.path, 'SecondStudent', 'workspace'));
      if (!await ws.exists()) await ws.create(recursive: true);
      path = ws.path;
    } else if (Platform.isIOS || Platform.isAndroid) {
      final docs = await getApplicationDocumentsDirectory();
      final ws = Directory(p.join(docs.path, 'workspace'));
      if (!await ws.exists()) await ws.create(recursive: true);
      path = ws.path;
    } else {
      final tmp = await getTemporaryDirectory();
      final ws = Directory(p.join(tmp.path, 'workspace'));
      if (!await ws.exists()) await ws.create(recursive: true);
      path = ws.path;
    }

    await prefs.setString('path_to_files', path);
  }

  Future<void> _restoreLayoutPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _leftWidth = (prefs.getDouble('workspace_left_width') ?? 300).clamp(220, 600);
      _showSidebar = prefs.getBool('workspace_show_sidebar') ?? true;
    });
  }

  Future<void> _persistLayoutPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('workspace_left_width', _leftWidth);
    await prefs.setBool('workspace_show_sidebar', _showSidebar);
  }

  Future<void> _onFileSelected(File file) async {
    try {
      final json = await file.readAsString();
      final state = _editorKey.currentState;
      if (state == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Editor not ready yet.')));
        return;
      }
      (state as dynamic).loadFromJsonString(json, sourcePath: file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final divider = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        setState(() {
          _leftWidth = (_leftWidth + d.delta.dx).clamp(220, 600);
        });
        _persistLayoutPrefs();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: SizedBox(
          width: 8,
          child: Center(
            child: Container(
              width: 2,
              height: 36,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('SecondStudent — Workspace'),
        actions: [
          IconButton(
            tooltip: _showSidebar ? 'Hide sidebar' : 'Show sidebar',
            icon: Icon(_showSidebar ? Icons.view_sidebar : Icons.view_sidebar_outlined),
            onPressed: () {
              setState(() => _showSidebar = !_showSidebar);
              _persistLayoutPrefs();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (_showSidebar)
            SizedBox(
              width: _leftWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: FileSystemViewer(
                  onFileSelected: _onFileSelected,
                  onFileRenamed: (oldFile, newFile) {
                    final state = _editorKey.currentState;
                    if (state == null) return;
                    try {
                      (state as dynamic).updateCurrentFilePath(newFile.path);
                    } catch (_) {}
                  },
                ),
              ),
            ),
          if (_showSidebar) divider,
          Expanded(child: EditorScreen(key: _editorKey)),
        ],
      ),
    );
  }
}
