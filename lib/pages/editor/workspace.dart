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
  State<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends State<EditorWorkspace> {
  final GlobalKey _editorKey = GlobalKey();

  double _leftWidth = 300;
  double _rightWidth = 300;
  bool _showSidebar = true;
  bool _drawerOpen = true;

  File? _currentFile;
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
      _leftWidth = (prefs.getDouble('workspace_left_width') ?? 300).clamp(
        220,
        600,
      );
      _rightWidth = (prefs.getDouble('workspace_right_width') ?? 300).clamp(
        220,
        600,
      );
      _showSidebar = prefs.getBool('workspace_show_sidebar') ?? true;
      _drawerOpen = prefs.getBool('workspace_drawer_open') ?? true;
    });
  }

  Future<void> _persistLayoutPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('workspace_left_width', _leftWidth);
    await prefs.setDouble('workspace_right_width', _rightWidth);
    await prefs.setBool('workspace_show_sidebar', _showSidebar);
    await prefs.setBool('workspace_drawer_open', _drawerOpen);
  }

  // --- Key change: editor stays mounted; we safely feed it JSON even after a PDF ---
  Future<void> _onFileSelected(File file) async {
    final lower = file.path.toLowerCase();
    _currentFile = file;

    if (lower.endsWith('.pdf')) {
      // Just flip the overlay; do not touch the editor.
      if (mounted) setState(() {});
      return;
    }

    if (lower.endsWith('.json')) {
      try {
        final json = await file.readAsString();

        // If the editor state isn't ready *this frame*, schedule it for next.
        void load() {
          final state = _editorKey.currentState;
          if (state != null) {
            (state as dynamic).loadFromJsonString(json, sourcePath: file.path);
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) => load());
          }
        }

        load();
        if (mounted) setState(() {}); // updates app bar title, etc.
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
      }
      return;
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

    final rightDivider = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        setState(() {
          _rightWidth = (_rightWidth - d.delta.dx).clamp(220, 600);
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
        title: Text(
          _currentFile == null
              ? 'SecondStudent — Workspace'
              : 'SecondStudent — ${p.basename(_currentFile!.path)}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // New File, Save, Sync buttons
          FilledButton.tonal(
            onPressed: () {
              // TODO: Implement new file functionality
            },
            child: const Text('New File'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              // TODO: Implement save functionality
            },
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              // TODO: Implement sync functionality
            },
            child: const Text('Sync'),
          ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: _showSidebar ? 'Hide file explorer' : 'Show file explorer',
            icon: Icon(_showSidebar ? Icons.folder : Icons.folder_outlined),
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
                // Editor stays alive even while a PDF is shown
                EditorScreen(key: _editorKey, onFileSelected: _onFileSelected),

                // Initial hint overlay if nothing selected (optional)
                if (_currentFile == null)
                  IgnorePointer(
                    child: Center(
                      child: Text('Select a JSON or PDF from the left.'),
                    ),
                  ),

                // PDF overlay on top of the editor
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

          if (_drawerOpen) rightDivider,

          // Persistent drawer on the right
          if (_drawerOpen)
            SizedBox(
              width: _rightWidth,
              child: _buildPersistentDrawer(context),
            ),
        ],
      ),
    );
  }

  Widget _buildFileSystemViewer() {
    return FileSystemViewer(
      onFileSelected: _onFileSelected,
      onFileRenamed: (oldFile, newFile) {
        if (_currentFile?.path == oldFile.path) {
          setState(() => _currentFile = newFile);
        }
        final state = _editorKey.currentState;
        if (state != null && !_showingPdf) {
          try {
            (state as dynamic).updateCurrentFilePath(newFile.path);
          } catch (_) {}
        }
      },
    );
  }

  Widget _buildPersistentDrawer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainer,
      elevation: 8,
      child: Row(
        children: [
          // CONTENT
          Expanded(
            child: Column(
              children: [
                // Header with hamburger menu and SECOND STUDENT text
                Container(
                  height: kToolbarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: _drawerOpen ? 'Hide drawer' : 'Show drawer',
                        icon: Icon(_drawerOpen ? Icons.menu : Icons.menu_open),
                        onPressed: () {
                          setState(() => _drawerOpen = !_drawerOpen);
                          _persistLayoutPrefs();
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SECOND STUDENT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // NAV ITEMS
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Editor'),
                        selected: true,
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: const Text('Calendar'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.check_box_outlined),
                        title: const Text('To-Do'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.store_outlined),
                        title: const Text('Marketplace'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: const Text('Classes'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.flash_on_outlined),
                        title: const Text('Flashcards'),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // SETTINGS
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () {},
                ),

                // FILE STORAGE LOCATION
                ListTile(
                  leading: const Icon(Icons.file_copy_outlined),
                  title: const Text('File Location'),
                  onTap: () {},
                ),
              ],
            ),
          ),

          // RESIZE HANDLE
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _rightWidth = (_rightWidth + details.delta.dx).clamp(
                    220,
                    600,
                  );
                });
                _persistLayoutPrefs();
              },
              child: Container(
                width: 10,
                height: double.infinity,
                alignment: Alignment.center,
                child: Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
