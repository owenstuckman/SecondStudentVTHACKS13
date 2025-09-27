import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

class NotesBlockEmbed extends CustomBlockEmbed {
  const NotesBlockEmbed(String value) : super(noteType, value);

  static const String noteType = 'notes';

  static NotesBlockEmbed fromDocument(Document document) {
    try {
      if (document.toDelta().isEmpty) {
        throw Exception('Document is empty');
      }
      return NotesBlockEmbed(jsonEncode(document.toDelta().toJson()));
    } catch (e) {
      print('Error creating NotesBlockEmbed from Document: $e');
      return const NotesBlockEmbed(''); // Return a default or empty embed
    }
  }

  Document get document {
    try {
      return Document.fromJson(jsonDecode(data));
    } catch (e) {
      print('Error decoding NotesBlockEmbed data: $e');
      return Document(); // Return an empty document on error
    }
  }
}

class NotesEmbedBuilder extends EmbedBuilder {
  NotesEmbedBuilder({required this.addEditNote});

  Future<void> Function(BuildContext context, {Document? document}) addEditNote;

  @override
  String get key => 'notes';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    try {
      final notes = NotesBlockEmbed(embedContext.node.value.data).document;

      return Material(
        color: Colors.transparent,
        child: ListTile(
          title: Text(
            notes.toPlainText().replaceAll('\n', ' '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          leading: const Icon(Icons.notes),
          onTap: () => addEditNote(context, document: notes),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.grey),
          ),
        ),
      );
    } catch (e) {
      print('Error rendering NotesEmbedBuilder: $e');
      return Container(); // Return an empty container or an error widget
    }
  }
}

Future<void> addEditNote(BuildContext context, {Document? document}) async {
  final isEditing = document != null;
  final controller = QuillController(
    document: document ?? Document(),
    selection: const TextSelection.collapsed(offset: 0),
  );

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      titlePadding: const EdgeInsets.only(left: 16, top: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${isEditing ? 'Edit' : 'Add'} note'),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          )
        ],
      ),
      content: QuillEditor.basic(
        controller: controller,
        config: const QuillEditorConfig(),
      ),
    ),
  );

  if (controller.document.isEmpty()) return;

  final block = BlockEmbed.custom(
    NotesBlockEmbed.fromDocument(controller.document),
  );
  final index = controller.selection.baseOffset;
  final length = controller.selection.extentOffset - index;

  if (isEditing) {
    final offset = getEmbedNode(controller, controller.selection.start).offset;
    controller.replaceText(
        offset, 1, block, TextSelection.collapsed(offset: offset));
  } else {
    controller.replaceText(index, length, block, null);
  }
}