import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// ==== Custom "notes" block embed ===========================================
class NotesBlockEmbed extends CustomBlockEmbed {
  const NotesBlockEmbed(String value) : super(noteType, value);

  static const String noteType = 'notes';

  static NotesBlockEmbed fromDocument(Document document) {
    // Store the inner document as a JSON string (delta ops).
    final ops = document.toDelta().toJson();
    return NotesBlockEmbed(jsonEncode(ops));
  }

  Document get document {
    try {
      final ops = jsonDecode(data);
      if (ops is List) {
        return Document.fromJson(ops.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    return Document();
  }
}

/// ==== Builder to render the "notes" embed ==================================
class NotesEmbedBuilder implements EmbedBuilder {
  NotesEmbedBuilder({required this.onTapEdit});
  final Future<void> Function(
    BuildContext context, {
    Document? document,
    int? existingOffset,
  })
  onTapEdit;

  @override
  String get key => NotesBlockEmbed.noteType;

  // Satisfy older/newer EmbedBuilder contracts explicitly
  @override
  bool get expanded => true;

  @override
  WidgetSpan buildWidgetSpan(Widget widget) => WidgetSpan(child: widget);

  @override
  String toPlainText(dynamic node) => '\uFFFC';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    try {
      final doc = NotesBlockEmbed(embedContext.node.value.data).document;
      final preview = doc.toPlainText().replaceAll('\n', ' ');
      // Use the offset of this node to support "Edit"
      final nodeOffset = embedContext.node.documentOffset;

      return Material(
        color: Colors.transparent,
        child: ListTile(
          leading: const Icon(Icons.notes),
          title: Text(
            preview.isEmpty ? 'Note' : preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.grey),
          ),
          onTap: () =>
              onTapEdit(context, document: doc, existingOffset: nodeOffset),
        ),
      );
    } catch (e) {
      // Fallback if the payload is malformed
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Invalid note block'),
      );
    }
  }
}

class CustomBlocks {
  /// Add note block helper
  Future<void> addEditNote(
    BuildContext context, {
    quill.Document? document,
    int? existingOffset,
    required quill.QuillController controller,
  }) async {
    final isEditing = document != null;
    final dialogController = quill.QuillController(
      document: document ?? quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.only(left: 16, top: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isEditing ? 'Edit note' : 'Add note'),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: quill.QuillEditor.basic(
          controller: dialogController,
          config: const quill.QuillEditorConfig(),
        ),
      ),
    );

    if (dialogController.document.isEmpty()) return;

    // Serialize inner doc and create the embed
    final notesEmbed = NotesBlockEmbed.fromDocument(dialogController.document);

    if (isEditing && existingOffset != null) {
      // Replace the existing embed at its node offset
      // In v10+ each embed occupies a single character length.
      controller.replaceText(
        existingOffset,
        1,
        quill.BlockEmbed.custom(notesEmbed),
        TextSelection.collapsed(offset: existingOffset + 1),
      );
      return;
    }

    // Insert a new embed at the current caret, plus a newline
    final insertAt = controller.selection.isValid
        ? controller.selection.start
        : controller.document.length;
    controller.replaceText(
      insertAt,
      0,
      quill.BlockEmbed.custom(notesEmbed),
      TextSelection.collapsed(offset: insertAt + 1),
    );
    // Add a newline after the block so the caret ends below it
    controller.replaceText(
      insertAt + 1,
      0,
      '\n',
      TextSelection.collapsed(offset: insertAt + 2),
    );
  }

  // Excalidraw and Google doc helpers
  String normalizeExcalidraw(String url) {
    // Accepts app.excalidraw.com links. If user pasted plain excalidraw.com, fix host.
    final u = Uri.tryParse(url);
    if (u == null) return url;
    if (u.host == 'excalidraw.com') {
      return u.replace(host: 'app.excalidraw.com').toString();
    }
    return url;
  }

  /// Returns a preview/published URL, or null if we can’t make it embeddable.
  String? normalizeGoogle(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return null;

    // Case 1: already a Drive file preview link → keep
    if (u.host.endsWith('drive.google.com') && u.path.contains('/preview')) {
      return url;
    }

    // Case 2: Drive file /view?usp=...  -> swap to /preview
    if (u.host.endsWith('drive.google.com') && u.path.contains('/file/')) {
      final newPath = u.path.replaceAll('/view', '/preview');
      return u.replace(path: newPath, queryParameters: {}).toString();
    }

    // Case 3: Google Docs “publish to web” gives an embeddable /pub or /embed URL → keep
    if (u.host.endsWith('docs.google.com') &&
        (u.path.contains('/pub') || u.path.contains('/embed'))) {
      return url;
    }

    // Regular Docs /document/d/<id>/edit is usually blocked by X-Frame-Options.
    // Ask the user to use File → Share → Publish to web, then paste that link.
    return null;
  }

  void insertIframe(
    quill.QuillController controller,
    String url, {
    double height = 420,
    bool addTrailingNewline = true,
  }) {}

  /// Convert common share links to proper embeddable URLs.
  /// Uses your existing helpers where possible (normalizeGoogle/normalizeExcalidraw).
  String _toEmbeddableUrl(String raw) {
    final u = Uri.tryParse(raw);
    if (u == null) return raw;

    // Prefer your existing normalizers if you already implemented them:
    final g = normalizeGoogle(
      raw,
    ); // returns /preview links for Docs/Drive or null
    if (g != null) return g;

    final ex = normalizeExcalidraw(raw); // ensures ?embed=1 for Excalidraw
    if (ex != raw) return ex;

    // YouTube: watch/shorts/share -> /embed/ID
    if (u.host.contains('youtube.com') ||
        u.host == 'youtu.be' ||
        u.host == 'www.youtu.be') {
      String? id;
      if (u.host.contains('youtube.com')) {
        id = u.queryParameters['v'];
        if (id == null && u.pathSegments.contains('shorts')) {
          final i = u.pathSegments.indexOf('shorts');
          if (i >= 0 && i + 1 < u.pathSegments.length)
            id = u.pathSegments[i + 1];
        }
        if (u.pathSegments.contains('embed')) return raw; // already embeddable
      } else if (u.pathSegments.isNotEmpty) {
        id = u.pathSegments.first; // youtu.be/{id}
      }
      if (id != null && id.isNotEmpty) {
        return 'https://www.youtube.com/embed/$id';
      }
    }

    // Vimeo: vimeo.com/{id} -> player.vimeo.com/video/{id}
    if (u.host.contains('vimeo.com') && !u.host.contains('player.')) {
      final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
      final id = segs.isNotEmpty ? segs.last : null;
      if (id != null && int.tryParse(id) != null) {
        return 'https://player.vimeo.com/video/$id';
      }
    }

    // Default: return as-is (host must allow iframing)
    return raw;
  }
}
