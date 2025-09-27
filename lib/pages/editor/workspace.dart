// lib/workspace.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'editor.dart';
import 'file_system_viewer.dart';

class EditorWorkspace extends StatefulWidget {
  const EditorWorkspace({super.key});

  @override
  State<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends State<EditorWorkspace> {
  // We’ll use a GlobalKey so we can call loadFromJsonString(...) on the editor state.
  final GlobalKey _editorKey = GlobalKey();

  // Sidebar (file list) width and visibility
  double _leftWidth = 300;
  bool _showSidebar = true;

  @override
  void initState() {
    super.initState();
    _restoreLayoutPrefs();
  }

  Future<void> _restoreLayoutPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _leftWidth = (prefs.getDouble('workspace_left_width') ?? 300).clamp(
        220,
        600,
      );
      _showSidebar = prefs.getBool('workspace_show_sidebar') ?? true;
    });
  }

  Future<void> _persistLayoutPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('workspace_left_width', _leftWidth);
    await prefs.setBool('workspace_show_sidebar', _showSidebar);
  }

  // Optional: quick way to set/change the workspace folder path in SharedPreferences.
  Future<void> _promptSetFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('path_to_files') ?? '';
    final controller = TextEditingController(text: current);

    final newPath = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set Workspace Folder Path'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: r'/Users/you/Documents/secondstudent',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newPath == null) return;

    try {
      // Basic existence check (desktop/mobile). On mobile you typically point to app docs dir.
      final dir = Directory(newPath);
      if (!await dir.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folder does not exist. Please create it first.'),
          ),
        );
        return;
      }
      await prefs.setString('path_to_files', newPath);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Workspace set to $newPath')));
      // Rebuild will cause FileSystemViewer to re-read prefs on init; use its Refresh button otherwise.
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error setting folder: $e')));
    }
  }

  Future<void> _onFileSelected(File file) async {
    try {
      final json = await file.readAsString();
      final state = _editorKey.currentState;
      if (state == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Editor not ready yet.')));
        return;
      }
      // Call the editor’s public method via dynamic (state class is private).
      // ignore: avoid_dynamic_calls
      (state as dynamic).loadFromJsonString(json, sourcePath: file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
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
            icon: Icon(
              _showSidebar ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            ),
            onPressed: () {
              setState(() => _showSidebar = !_showSidebar);
              _persistLayoutPrefs();
            },
          ),
          IconButton(
            tooltip: 'Set folder path',
            icon: const Icon(Icons.folder_open),
            onPressed: _promptSetFolderPath,
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
                // inside build(...) where FileSystemViewer is created
                child: FileSystemViewer(
                  onFileSelected: _onFileSelected,
                  onFileRenamed: (oldFile, newFile) {
                    final state = _editorKey.currentState;
                    if (state == null) return;
                    // ignore: avoid_dynamic_calls
                    final dynamic s = state;
                    // If the editor has a public method to update its bound path, call it:
                    try {
                      s.updateCurrentFilePath(newFile.path);
                    } catch (_) {
                      // Fallback: if no method exists, you could reload the doc instead:
                      // final json = await newFile.readAsString();
                      // s.loadFromJsonString(json, sourcePath: newFile.path);
                    }
                  },
                ),
              ),
            ),
          if (_showSidebar) divider,
          // Right pane: Editor fills remaining space
          Expanded(child: EditorScreen(key: _editorKey)),
        ],
      ),
    );
  }
}
