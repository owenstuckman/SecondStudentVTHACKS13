import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:secondstudent/pages/editor/custom_blocks/iframe_block.dart';


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
}) {
  final normalizedUrl = _normalizeUrlForEmbedding(url);
  final embed = quill.BlockEmbed.custom(
    IframeBlockEmbed(url: normalizedUrl, height: height),
  );

  final doc = controller.document;
  final sel = controller.selection;
  if (!sel.isValid) return;

  // Where to insert
  int insertAt = sel.baseOffset.clamp(0, doc.length);

  // Peek around the caret to decide if we need line breaks
  final plain = doc.toPlainText();
  final beforeChar = insertAt > 0 ? plain[insertAt - 1] : '\n';
  final afterChar  = insertAt < plain.length ? plain[insertAt] : '\n';

  final needsLeadingNL  = beforeChar != '\n';
  final needsTrailingNL = afterChar  != '\n';

  // Leading newline (so the embed is on its own line)
  if (needsLeadingNL) {
    controller.replaceText(
      insertAt,
      0,
      '\n',
      TextSelection.collapsed(offset: insertAt + 1),
    );
    insertAt += 1;
  }

  // Insert the embed
  controller.replaceText(
    insertAt,
    0,
    embed,
    TextSelection.collapsed(offset: insertAt + 1),
  );
  insertAt += 1;

  // Trailing newline so the caret lands under the block
  if (addTrailingNewline && needsTrailingNL) {
    controller.replaceText(
      insertAt,
      0,
      '\n',
      TextSelection.collapsed(offset: insertAt + 1),
    );
  }
}


  /// Use the builder's URL normalization logic instead of duplicating it
  String _normalizeUrlForEmbedding(String raw) {
    // Create a temporary builder instance to access its URL normalization logic
    const builder = IframeEmbedBuilder();
    return builder.toEmbeddableUrl(raw);
  }
}
