// lib/pages/editor/workspace.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'editor/editor.dart';
import 'editor/pdf_viewer_pane.dart';
import 'file_system/file_system_viewer.dart';

class EditorWorkspace extends StatefulWidget {
  const EditorWorkspace({super.key});

  @override
  State<EditorWorkspace> createState() => EditorWorkspaceState();
}

class EditorWorkspaceState extends State<EditorWorkspace> {
  final GlobalKey _editorKey = GlobalKey();

  double _leftWidth = 300;
  bool _showSidebar = true;

  File? _currentFile;
  File? get currentFile => _currentFile;
  bool get _showingPdf =>
      _currentFile != null && _currentFile!.path.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    _ensureWorkspacePath();
    _restoreLayoutPrefs();
  }

  Future<void> _ensureWorkspacePath() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('path_to_files');
    if (existing != null && existing.trim().isNotEmpty) return;

    String path;
    if (kIsWeb) {
      path = 'web://workspace';
    } else if (Platform.isMacOS) {
      final support = await getApplicationSupportDirectory();
      final ws = Directory(p.join(support.path, 'SecondStudent', 'workspace'));
      if (!await ws.exists()) await ws.create(recursive: true);
      path = ws.path;
    } else if (Platform.isWindows || Platform.isLinux) {
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
      _leftWidth = prefs.getDouble('workspace_left_width') ?? 300;
      _showSidebar = prefs.getBool('workspace_show_sidebar') ?? true;
    });
  }

  Future<void> _persistLayoutPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('workspace_left_width', _leftWidth);
    await prefs.setBool('workspace_show_sidebar', _showSidebar);
  }

  Future<void> _onFileSelected(File file) async {
    setState(() {
      _currentFile = file;
    });
    
    // Load the file into the editor
    final editorState = _editorKey.currentState as EditorScreenState?;
    if (editorState != null) {
      try {
        final json = await file.readAsString();
        editorState.loadFromJsonString(json, sourcePath: file.path);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
      }
    }
  }

  // Expose save and sync methods
  Future<void> saveCurrentFile() async {
    final editorState = _editorKey.currentState as EditorScreenState?;
    if (editorState != null) {
      await editorState.saveToCurrentFile();
    }
  }

  Future<void> syncCurrentFile() async {
    final editorState = _editorKey.currentState as EditorScreenState?;
    if (editorState != null && _currentFile != null) {
      await editorState.syncToCurrentFile(_currentFile!.path);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unsupported file type')));
  }

  @override
  Widget build(BuildContext context) {
    final leftDivider = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        setState(() {
          _leftWidth = (_leftWidth + details.delta.dx).clamp(200, 500);
        });
        _persistLayoutPrefs();
      },
      child: Container(
        width: 8,
        height: double.infinity,
        alignment: Alignment.center,
        child: Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );

    return Row(
            children: [
              // File system viewer on the left
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
                    child: _buildFileSystemViewer(),
                  ),
                ),
              if (_showSidebar) leftDivider,

              // Editor in the middle
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EditorScreen(
                      key: _editorKey,
                      onFileSelected: _onFileSelected,
                    ),
                    if (_currentFile == null)
                      const IgnorePointer(
                        child: Center(
                          child: Text('Select a JSON or PDF from the left.'),
                        ),
                      ),
                    if (_showingPdf)
                      kIsWeb
                          ? const Center(
                              child: Text(
                                'Web PDF viewing from local paths is not supported yet.',
                              ),
                            )
                          : PdfViewerPane(file: _currentFile!),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildFileSystemViewer() {
    return FileSystemViewer(
      onFileSelected: _onFileSelected,
    );
  }
}
