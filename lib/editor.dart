// lib/editor.dart — Quill-backed editor with JSON load/save
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shared_preferences/shared_preferences.dart';
import 'slash_menu.dart';
import 'slash_menu_action.dart';
import 'package:flutter/services.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const String _prefsKey = 'editor_doc_delta';

  late quill.QuillController _controller;
  // Minimal editor: Quill manages focus/scroll in basic constructor
  StreamSubscription? _docSub;

  // Slash menu state
  bool _isSlashMenuOpen = false;
  String _slashQuery = '';
  final ValueNotifier<int> _slashSelectionIndex = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    _attachDocListener();
    _loadFromPrefs();
  }

  void _attachDocListener() {
    _docSub?.cancel();
    _docSub = _controller.document.changes.listen((_) {
      _saveToPrefs();
      _maybeUpdateSlashMenu();
    });
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final List<dynamic> ops = jsonDecode(raw) as List<dynamic>;
      final newDoc = quill.Document.fromJson(ops);
      _controller = quill.QuillController(
        document: newDoc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _attachDocListener();
      if (mounted) setState(() {});
    } catch (_) {
      // ignore malformed stored data
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final ops = _controller.document.toDelta().toJson();
    await prefs.setString(_prefsKey, jsonEncode(ops));
  }

  @override
  void dispose() {
    _docSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // --- Slash menu helpers ---
  List<SlashMenuItemData> get _allSlashItems => defaultSlashMenuItems;

  List<SlashMenuItemData> get _filteredSlashItems {
    final q = _slashQuery.trim().toLowerCase();
    if (q.isEmpty) return _allSlashItems;
    return _allSlashItems
        .where((it) =>
            it.title.toLowerCase().contains(q) ||
            it.subtitle.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _openSlashMenu(String query) {
    if (!_isSlashMenuOpen) {
      setState(() {
        _isSlashMenuOpen = true;
        _slashQuery = query;
        _slashSelectionIndex.value = 0;
      });
    } else {
      setState(() {
        _slashQuery = query;
        _slashSelectionIndex.value = 0;
      });
    }
  }

  void _closeSlashMenu() {
    if (_isSlashMenuOpen) {
      setState(() {
        _isSlashMenuOpen = false;
        _slashQuery = '';
        _slashSelectionIndex.value = 0;
      });
    }
  }

  void _maybeUpdateSlashMenu() {
    final selection = _controller.selection;
    if (!selection.isValid) {
      _closeSlashMenu();
      return;
    }
    final caret = selection.baseOffset;
    if (caret < 0) {
      _closeSlashMenu();
      return;
    }
    final text = _controller.document.toPlainText();
    if (caret > text.length) {
      _closeSlashMenu();
      return;
    }
    final int lineStart = text.lastIndexOf('\n', (caret - 1).clamp(0, text.length - 1)) + 1;
    final String lineBeforeCaret = text.substring(lineStart, caret);

    if (lineBeforeCaret.startsWith('/')) {
      final query = lineBeforeCaret.substring(1);
      _openSlashMenu(query);
      if (_filteredSlashItems.isEmpty) {
        _slashSelectionIndex.value = 0;
      } else {
        _slashSelectionIndex.value = _slashSelectionIndex.value.clamp(0, _filteredSlashItems.length - 1);
      }
    } else {
      _closeSlashMenu();
    }
  }

  void _onSlashSelect(SlashMenuAction action) {
    final selection = _controller.selection;
    if (!selection.isValid) {
      _closeSlashMenu();
      return;
    }
    final text = _controller.document.toPlainText();
    final caret = selection.baseOffset;
    final int lineStart = text.lastIndexOf('\n', (caret - 1).clamp(0, text.length - 1)) + 1;
    final String lineBeforeCaret = text.substring(lineStart, caret);
    // Delete the "/..." trigger text
    if (lineBeforeCaret.startsWith('/')) {
      final int deleteLength = lineBeforeCaret.length;
      _controller.replaceText(
        lineStart,
        deleteLength,
        '',
        TextSelection.collapsed(offset: lineStart),
      );
    }

    switch (action) {
      case SlashMenuAction.paragraph:
        _controller.formatSelection(quill.Attribute.header);
        _controller.formatSelection(quill.Attribute.list);
        break;
      case SlashMenuAction.heading1:
        _controller.formatSelection(quill.Attribute.h1);
        break;
      case SlashMenuAction.heading2:
        _controller.formatSelection(quill.Attribute.h2);
        break;
      case SlashMenuAction.heading3:
        _controller.formatSelection(quill.Attribute.h3);
        break;
      case SlashMenuAction.bulletList:
        _controller.formatSelection(quill.Attribute.ul);
        break;
      case SlashMenuAction.numberedList:
        _controller.formatSelection(quill.Attribute.ol);
        break;
      case SlashMenuAction.toDoList:
        _controller.formatSelection(quill.Attribute.unchecked);
        break;
      case SlashMenuAction.divider:
        final int index = _controller.selection.baseOffset;
        // Simple text-based divider fallback
        _controller.replaceText(index, 0, '\n---\n', const TextSelection.collapsed(offset: 0));
        break;
    }

    _closeSlashMenu();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent e) {
    if (!_isSlashMenuOpen) {
      return KeyEventResult.ignored;
    }
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final filtered = _filteredSlashItems;
    if (filtered.isEmpty) return KeyEventResult.handled;
    final logicalKey = e.logicalKey;
    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      final next = (_slashSelectionIndex.value + 1) % filtered.length;
      _slashSelectionIndex.value = next;
      return KeyEventResult.handled;
    } else if (logicalKey == LogicalKeyboardKey.arrowUp) {
      final next = (_slashSelectionIndex.value - 1 + filtered.length) % filtered.length;
      _slashSelectionIndex.value = next;
      return KeyEventResult.handled;
    } else if (logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.numpadEnter) {
      _onSlashSelect(filtered[_slashSelectionIndex.value].action);
      return KeyEventResult.handled;
    } else if (logicalKey == LogicalKeyboardKey.escape) {
      _closeSlashMenu();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredSlashItems;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Positioned.fill(
                    child: quill.QuillEditor.basic(
                      controller: _controller,
                    ),
                  ),
                  if (_isSlashMenuOpen)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: SlashMenu(
                          items: filteredItems,
                          selectionIndexListenable: _slashSelectionIndex,
                          onSelect: _onSlashSelect,
                          onDismiss: _closeSlashMenu,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}