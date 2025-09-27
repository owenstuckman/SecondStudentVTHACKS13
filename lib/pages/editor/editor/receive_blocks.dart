// lib/pages/editor/editor_actions.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextSelection
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../slash_menu/slash_menu_action.dart';
import 'package:secondstudent/pages/editor/custom_blocks/customblocks.dart';

typedef EditorAction = FutureOr<void> Function(
  BuildContext context,
  quill.QuillController controller,
);

class ReceiveBlocks {
  ReceiveBlocks();

  // Custom blocks facade (helpers for notes/iframe normalizers, etc.)
  final cb = CustomBlocks();

  Future<String?> _promptForUrl(
    BuildContext context, {
    required String label,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(label),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'https://...'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );
  }

  // Keep this as late final so closures can capture 'this'.
  late final Map<SlashMenuAction, EditorAction> actionMap = {
    SlashMenuAction.paragraph: (context, controller) {
      controller.formatSelection(quill.Attribute.header);
      controller.formatSelection(quill.Attribute.list);
    },

    SlashMenuAction.heading1: (context, controller) =>
        controller.formatSelection(quill.Attribute.h1),

    SlashMenuAction.heading2: (context, controller) =>
        controller.formatSelection(quill.Attribute.h2),

    SlashMenuAction.heading3: (context, controller) =>
        controller.formatSelection(quill.Attribute.h3),

    SlashMenuAction.bulletList: (context, controller) =>
        controller.formatSelection(quill.Attribute.ul),

    SlashMenuAction.numberedList: (context, controller) =>
        controller.formatSelection(quill.Attribute.ol),

    SlashMenuAction.toDoList: (context, controller) =>
        controller.formatSelection(quill.Attribute.unchecked),

    SlashMenuAction.divider: (context, controller) {
      final int index = controller.selection.baseOffset;
      controller.replaceText(
        index,
        0,
        '\n---\n',
        const TextSelection.collapsed(offset: 0),
      );
    },

    SlashMenuAction.codeBlock: (context, controller) =>
        controller.formatSelection(quill.Attribute.codeBlock),

    SlashMenuAction.addEditNote: (context, controller) async {
      await cb.addEditNote(
        context,
        controller: controller,
        document: controller.document,
        existingOffset:
            controller.selection.isValid ? controller.selection.start : null,
      );
    },

    SlashMenuAction.image: (context, controller) {
      _promptForUrl(context, label: 'Image URL').then((url) {
        if (url == null || url.isEmpty) return;
        final idx = controller.selection.baseOffset;
        controller.replaceText(
          idx,
          0,
          quill.BlockEmbed.image(url),
          const TextSelection.collapsed(offset: 0),
        );
      });
    },

    SlashMenuAction.video: (context, controller) {
      _promptForUrl(context, label: 'Video URL').then((url) {
        if (url == null || url.isEmpty) return;
        final idx = controller.selection.baseOffset;
        controller.replaceText(
          idx,
          0,
          quill.BlockEmbed.video(url),
          const TextSelection.collapsed(offset: 0),
        );
      });
    },

    SlashMenuAction.iframeExcalidraw: (context, controller) {
      _promptForUrl(context, label: 'Excalidraw room/share URL').then((url) {
        if (url == null || url.isEmpty) return;
        cb.insertIframe(
          controller,
          url,
          height: 560, // helper normalizes & inserts
        );
      });
    },

    SlashMenuAction.iframeGoogleDoc: (context, controller) {
      _promptForUrl(
        context,
        label: 'Google Doc (published) or Drive preview URL',
      ).then((url) {
        if (url == null || url.isEmpty) return;
        final normalized = cb.normalizeGoogle(url);
        if (normalized == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Use a published-to-web or /preview Google link.'),
            ),
          );
          return;
        }
        cb.insertIframe(controller, normalized, height: 560);
      });
    },
  };

/*
  // If you want to add actions at runtime from an external source:
  Future<void> fetchExternalActions() async {
    final externalActions = await getExternalActionsFromDatabase();

    // Merge or override existing actions
    for (final entry in externalActions.entries) {
      actionMap[entry.key] = entry.value;
    }
  }
*/

/*
  // Example: simulate fetching actions from a DB / remote config.
  Future<Map<SlashMenuAction, EditorAction>> getExternalActionsFromDatabase() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return {
      // Replace these with real actions (and ensure the enum values exist)
      SlashMenuAction.customAction1: (context, controller) async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('customAction1 executed')),
        );
      },
      SlashMenuAction.customAction2: (context, controller) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('customAction2 executed')),
        );
      },
    };
  }
*/
}
