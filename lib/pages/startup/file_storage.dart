// lib/pages/startup/file_storage.dart
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:secondstudent/pages/startup/home_page.dart';

class FileStorage extends StatelessWidget {
  const FileStorage({super.key});

  @override
  Widget build(BuildContext context) => const _FolderSelectorWidget();
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers (no duplicates)
// ─────────────────────────────────────────────────────────────────────────────

String _prettyPath(String path) {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && home.isNotEmpty) {
    final normHome = Directory(home).absolute.path;
    final normPath = Directory(path).absolute.path;
    if (normPath.startsWith(normHome)) {
      return normPath.replaceFirst(normHome, '~');
    }
  }
  return path;
}

/// Best guess for a user's Documents folder on desktop.
Future<Directory> _desktopDocumentsDir() async {
  if (Platform.isWindows) {
    final user = Platform.environment['USERPROFILE'];
    if (user != null && user.isNotEmpty) {
      final docs = Directory(p.join(user, 'Documents'));
      if (await docs.exists()) return docs;
      return Directory(user);
    }
    return Directory('C:\\');
  }

  // macOS / Linux
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    final docs = Directory(p.join(home, 'Downloads'));
    if (await docs.exists()) return docs;
    return Directory(home);
  }

  // Fallback
  return Directory.current;
}

/// Our recommended workspace location (human-friendly).
Future<Directory> _recommendedWorkspace() async {
  if (kIsWeb) {
    // Temporary stub for web; replace with IndexedDB later.
    return Directory.systemTemp.createTemp('secondstudent_web_workspace_');
  }

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    final docs = await _desktopDocumentsDir();
    final ws = Directory(p.join(docs.path, 'SecondStudent', 'workspace'));
    if (!await ws.exists()) {
      await ws.create(recursive: true);
    }
    return ws;
  }

  if (Platform.isAndroid || Platform.isIOS) {
    final docs = await getApplicationDocumentsDirectory();
    final ws = Directory(p.join(docs.path, 'workspace'));
    if (!await ws.exists()) {
      await ws.create(recursive: true);
    }
    return ws;
  }

  // Last resort
  final tmp = await getTemporaryDirectory();
  final ws = Directory(p.join(tmp.path, 'workspace'));
  if (!await ws.exists()) {
    await ws.create(recursive: true);
  }
  return ws;
}

/// Starting root for the folder picker (what the user can browse).
Future<Directory> _pickerRoot() async {
  if (kIsWeb) return Directory.systemTemp;

  if (Platform.isMacOS || Platform.isLinux) {
    return _desktopDocumentsDir();
  }

  if (Platform.isWindows) {
    final user = Platform.environment['USERPROFILE'] ?? 'C:\\';
    final dir = Directory(user);
    if (await dir.exists()) return dir;
    return Directory('C:\\');
  }

  if (Platform.isAndroid || Platform.isIOS) {
    return getApplicationDocumentsDirectory();
  }

  return Directory.current;
}

/// Option A preflight: try listing the folder to detect EPERM before saving.
/// Returns `true` if accessible, `false` if EPERM (or other access errors).
Future<bool> _canAccessDirectory(String path) async {
  try {
    final dir = Directory(path);
    if (!await dir.exists()) return true; // let creation/saving proceed
    // Tiny probe: list at most 1 entry (non-recursive).
    await dir.list(followLinks: false).take(1).toList();
    return true;
  } on FileSystemException catch (e) {
    // EPERM = 1 on macOS
    if (e.osError?.errorCode == 1) return false;
    return false;
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI
// ─────────────────────────────────────────────────────────────────────────────

class _FolderSelectorWidget extends StatefulWidget {
  const _FolderSelectorWidget();

  @override
  State<_FolderSelectorWidget> createState() => _FolderSelectorWidgetState();
}

class _FolderSelectorWidgetState extends State<_FolderSelectorWidget> {
  Future<String?> _getSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('path_to_files');
  }

  Future<void> _saveAndRestart(BuildContext context, String path) async {
    // Option A: preflight check & re-prompt on EPERM.
    final ok = await _canAccessDirectory(path);
    if (!ok && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission needed'),
          content: Text(
            'macOS needs you to select the folder via the picker so the app can access it.\n\n'
            'Folder: ${_prettyPath(path)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _pickFolder(context);
              },
              child: const Text('Select Folder'),
            ),
          ],
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final normalized = Directory(path).absolute.path;
    await prefs.setString('path_to_files', normalized);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder saved: ${_prettyPath(normalized)}')),
    );

    // Return to HomePage so the workspace re-reads prefs.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomePage()),
      (route) => false,
    );
  }

  Future<void> _pickFolder(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder picker is not supported on Web.')),
      );
      return;
    }

    final root = await _pickerRoot();
    if (!await root.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Root path does not exist: ${root.path}')),
      );
      return;
    }

    final selectedPath = await FilesystemPicker.open(
      context: context,
      title: 'Select a Folder',
      fsType: FilesystemType.folder,
      rootDirectory: root,
      directory: root,
      showGoUp: true,
      pickText: 'Use this folder',
      requestPermission: () async => true, // desktop: no runtime dialog
    );

    if (selectedPath == null) return; // user cancelled
    await _saveAndRestart(context, selectedPath);
  }

  /// Create/reuse ~/Documents/SecondStudent/workspace, then ask the user
  /// to confirm THAT folder (grants access on macOS). No persistent bookmarks.
  Future<void> _useRecommended(BuildContext context) async {
    final ws = await _recommendedWorkspace();

    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final docs = await _desktopDocumentsDir();
      final selectedPath = await FilesystemPicker.open(
        context: context,
        title: 'Use Recommended Folder',
        fsType: FilesystemType.folder,
        rootDirectory: docs,   // root = ~/Documents (or HOME fallback)
        directory: ws,         // start in ~/Documents/SecondStudent/workspace
        showGoUp: true,
        pickText: 'Use this folder',
        requestPermission: () async => true,
      );

      if (selectedPath == null) return; // user cancelled
      await _saveAndRestart(context, selectedPath);
      return;
    }

    // Mobile/web fallback: just save the created path (no security-scope needed).
    await _saveAndRestart(context, ws.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folder Selector')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FutureBuilder<String?>(
                future: _getSavedPath(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final current = snap.data;
                  final text = (current == null || current.isEmpty)
                      ? 'No folder selected'
                      : 'Current File Location:\n${_prettyPath(current)}';
                  return Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _pickFolder(context),
                child: const Text('Choose a Folder…', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _useRecommended(context),
                child: const Text('Use Recommended Default'),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                const Text(
                  'Web is not using a native file system.\nAdd an IndexedDB-backed storage later.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
