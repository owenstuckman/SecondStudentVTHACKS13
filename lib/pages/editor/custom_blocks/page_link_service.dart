import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class PageLinkService {
  /// Key used across the app to store the workspace root folder.
  static const String workspacePrefsKey = 'path_to_files';

  /// Read workspace root from SharedPreferences.
  static Future<String?> workspaceRoot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(workspacePrefsKey);
  }

  /// Compute workspace-relative path. Falls back to absolute if outside root.
  static String toRelative(String workspaceRoot, String absolutePath) {
    final root = Directory(workspaceRoot).absolute.path;
    final abs  = File(absolutePath).absolute.path;

    if (abs == root) return '';
    final sep = Platform.pathSeparator;
    final prefix = '$root$sep';
    return abs.startsWith(prefix) ? abs.substring(prefix.length) : abs;
  }

  /// List all .json files under workspace (non-hidden dirs).
  static Future<List<File>> listWorkspaceJsonFiles() async {
    final root = await workspaceRoot();
    if (root == null || root.isEmpty) return const [];
    final rootDir = Directory(root);
    if (!await rootDir.exists()) return const [];

    final List<File> out = [];
    final stack = <Directory>[rootDir];
    while (stack.isNotEmpty) {
      final d = stack.removeLast();
      try {
        for (final e in d.listSync(followLinks: false)) {
          if (e is Directory) {
            final name = p.basename(e.path);
            if (name.startsWith('.')) continue;
            stack.add(e);
          } else if (e is File && e.path.toLowerCase().endsWith('.json')) {
            out.add(e);
          }
        }
      } catch (_) {/* ignore */}
    }
    out.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return out;
  }

  /// Dialog to pick a JSON file inside the workspace.
  static Future<File?> pickWorkspaceJson(BuildContext context) async {
    final files = await listWorkspaceJsonFiles();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No JSON files in workspace yet.')),
      );
      return null;
    }
    final root = await workspaceRoot();
    if (root == null) return null;

    File? selected;
    final filterCtl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        List<File> filtered = files;

        void applyFilter() {
          final q = filterCtl.text.trim().toLowerCase();
          filtered = q.isEmpty
              ? files
              : files.where((f) => f.path.toLowerCase().contains(q)).toList();
          (ctx as Element).markNeedsBuild();
        }

        filterCtl.addListener(applyFilter);

        return AlertDialog(
          title: const Text('Link to page'),
          content: SizedBox(
            width: 520,
            height: 360,
            child: Column(
              children: [
                TextField(
                  controller: filterCtl,
                  decoration: const InputDecoration(
                    hintText: 'Search files…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Scrollbar(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final f = filtered[i];
                        final rel = toRelative(root, f.path);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(rel, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            selected = f;
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    filterCtl.dispose();
    return selected;
  }

  /// Insert a link to another workspace JSON file at the current selection.
  static Future<void> insertPageLink({
    required BuildContext context,
    required quill.QuillController controller,
  }) async {
    final root = await workspaceRoot();
    if (root == null || root.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a workspace folder first.')),
      );
      return;
    }

    final file = await pickWorkspaceJson(context);
    if (file == null) return;

    final rel = toRelative(root, file.path);
    final display = p.basename(rel);
    final idx = controller.selection.baseOffset.clamp(0, controller.document.length);

    final linkAttr = quill.LinkAttribute('file://$rel');
    controller.replaceText(
      idx,
      0,
      display,
      TextSelection.collapsed(offset: idx + display.length),
    );
    controller.formatText(idx, display.length, linkAttr);
  }

  /// Handle a launched URL from the editor. Returns true if handled.
  /// If it's our file:// link, resolves and calls [onOpenJson(absPath)].
  static Future<bool> handleLaunchUrl(
    String url, {
    required Future<void> Function(String absPath) onOpenJson,
    required BuildContext context,
  }) async {
    if (!url.startsWith('file://')) return false;

    final rel = url.substring('file://'.length);
    final root = await workspaceRoot();
    if (root == null || root.isEmpty) return true;

    final abs = p.normalize(p.join(Directory(root).absolute.path, rel));
    final file = File(abs);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Page not found: $rel')),
      );
      return true;
    }

    try {
      await onOpenJson(abs);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open link: $e')),
      );
    }
    return true;
  }
}
