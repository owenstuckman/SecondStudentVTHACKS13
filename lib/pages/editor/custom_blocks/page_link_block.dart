// lib/pages/editor/custom_blocks/page_link_block.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// ================= Workspace helpers =================

class Workspace {
  static const String _prefsKey = 'path_to_files';

  static Future<String?> root() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static String toRelative(String root, String absPath) {
    final normRoot = Directory(root).absolute.path;
    final normAbs  = File(absPath).absolute.path;

    if (normAbs == normRoot) return '';
    final prefix = '$normRoot${Platform.pathSeparator}';
    return normAbs.startsWith(prefix) ? normAbs.substring(prefix.length) : normAbs;
  }

  static String toAbsolute(String root, String relPath) {
    return p.normalize(p.join(Directory(root).absolute.path, relPath));
  }
}

/// ================= Embed model =================

/// Embed payload:
/// {
///   "rel": "notes/algorithms.json", // workspace-relative path
///   "title": "algorithms.json"      // display title (defaults to basename(rel))
/// }
class PageLinkBlockEmbed extends quill.CustomBlockEmbed {
  static const String kType = 'pagelink';

  PageLinkBlockEmbed({
    required String rel,
    String? title,
  }) : super(
          kType,
          jsonEncode(<String, dynamic>{"rel": rel, if (title != null) "title": title}),
        );

  static PageLinkBlockEmbed fromJson(Map<String, dynamic> json) {
    final rel = (json['rel'] as String?) ?? '';
    final title = json['title'] as String?;
    return PageLinkBlockEmbed(rel: rel, title: title);
  }
}

/// ================= Insert helper =================

class PageLinkBlock {
  /// Opens a file picker from your own UI layer and returns the absolute path.
  /// You can wire this to your existing picker (returns `String? absPath`).
  ///
  /// Provide your own implementation here if you want a richer picker.
  static Future<String?> _pickJsonPath(BuildContext context) async {
    // TODO: Replace with your existing workspace picker.
    // For now, return null to indicate "not chosen".
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hook up _pickJsonPath to your picker.')),
    );
    return null;
  }

  /// Call this from a toolbar/command to insert the block at the current caret.
  static Future<void> insertAtSelection({
    required BuildContext context,
    required quill.QuillController controller,
    Future<String?> Function(BuildContext ctx)? pickJsonAbsolutePath,
  }) async {
    final root = await Workspace.root();
    if (root == null || root.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a workspace folder first.')),
      );
      return;
    }

    final pick = pickJsonAbsolutePath ?? _pickJsonPath;
    final abs = await pick(context);
    if (abs == null) return;

    final rel = Workspace.toRelative(root, abs);
    final title = p.basename(rel);

    // Get current selection and ensure it's valid
    final sel = controller.selection;
    if (!sel.isValid) return;
    
    int insertIndex = sel.baseOffset.clamp(0, controller.document.length);
    final docLen = controller.document.length;

    // Create the embed
    final embed = quill.BlockEmbed.custom(
      PageLinkBlockEmbed(rel: rel, title: title),
    );

    // Insert the embed with proper line breaks
    final textBefore = insertIndex > 0 ? controller.document.toPlainText().substring(0, insertIndex) : '';
    final textAfter = insertIndex < docLen ? controller.document.toPlainText().substring(insertIndex) : '';
    
    // Ensure we have proper line breaks around the embed
    final needsLeadingNL = textBefore.isEmpty || !textBefore.endsWith('\n');
    final needsTrailingNL = textAfter.isEmpty || !textAfter.startsWith('\n');
    
    // Insert leading newline if needed
    if (needsLeadingNL) {
      controller.replaceText(insertIndex, sel.end - sel.start, '\n', 
        TextSelection.collapsed(offset: insertIndex + 1));
      insertIndex += 1;
    }
    
    // Insert the embed
    controller.replaceText(insertIndex, 0, embed, 
      TextSelection.collapsed(offset: insertIndex + 1));
    insertIndex += 1;
    
    // Insert trailing newline if needed
    if (needsTrailingNL) {
      controller.replaceText(insertIndex, 0, '\n', 
        TextSelection.collapsed(offset: insertIndex + 1));
    }
  }

  /// Resolve and open on tap.
  static Future<void> open({
    required BuildContext context,
    required String rel,
    required Future<void> Function(String absPath) onOpenJson,
    Future<void> Function(File file)? onFileSelected,
  }) async {
    final root = await Workspace.root();
    if (root == null || root.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a workspace folder first.')),
      );
      return;
    }
    final abs = Workspace.toAbsolute(root, rel);
    final f = File(abs);
    if (!await f.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Page not found: $rel')),
      );
      return;
    }
    
    // Use the workspace file selection if available, otherwise fallback
    if (onFileSelected != null) {
      await onFileSelected(f);
    } else {
      await onOpenJson(abs);
    }
  }

}

/// ================= Embed builder (render) =================

class PageLinkBlockBuilder extends quill.EmbedBuilder {
  PageLinkBlockBuilder({
    required this.onOpenJson,
    this.onFileSelected,
    this.icon,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(12),
    this.titleStyle,
    this.subtitleStyle,
  });

  /// Called when the card is tapped.
  final Future<void> Function(String absPath) onOpenJson;
  final Future<void> Function(File file)? onFileSelected;

  final IconData? icon;
  final double borderRadius;
  final EdgeInsets padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  String get key => PageLinkBlockEmbed.kType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    // Pull data
    final data = embedContext.node.value.data;
    final rel = (data is Map && data['rel'] is String) ? data['rel'] as String : '';
    final title = (data is Map && data['title'] is String)
        ? data['title'] as String
        : (rel.isNotEmpty ? p.basename(rel) : 'Untitled');

    return _PageLinkCard(
      rel: rel,
      title: title,
      icon: icon,
      borderRadius: borderRadius,
      padding: padding,
      titleStyle: titleStyle ?? embedContext.textStyle.copyWith(fontWeight: FontWeight.w600),
      subtitleStyle: subtitleStyle ??
          embedContext.textStyle.copyWith(
            fontSize: (embedContext.textStyle.fontSize ?? 16) * 0.85,
            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
      onTap: () async {
        // Open the file using workspace file selection if available
        await PageLinkBlock.open(
          context: context,
          rel: rel,
          onOpenJson: onOpenJson,
          onFileSelected: onFileSelected,
        );
      },
      readOnly: embedContext.readOnly,
    );
  }
}

class _PageLinkCard extends StatelessWidget {
  const _PageLinkCard({
    required this.rel,
    required this.title,
    required this.onTap,
    required this.readOnly,
    this.icon,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(12),
    this.titleStyle,
    this.subtitleStyle,
  });

  final String rel;
  final String title;
  final VoidCallback onTap;
  final bool readOnly;

  final IconData? icon;
  final double borderRadius;
  final EdgeInsets padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.35),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.link, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title (file name or provided title)
                Text(title, style: titleStyle, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                // Subtitle (relative path)
                Text(rel, style: subtitleStyle, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    );

    // In readOnly mode, just an InkWell. In edit mode, still tappable.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
