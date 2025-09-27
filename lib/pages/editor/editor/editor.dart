// lib/editor.dart — Quill-backed editor with JSON load/save and external load API

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Custom blocks: helpers (normalize/insert/addEditNote, Notes builder, etc.)
import 'package:secondstudent/pages/editor/custom_blocks/customblocks.dart';

// Iframe builder lives here (per your note)
import 'package:secondstudent/pages/editor/custom_blocks/iframe_block.dart';

import '../slash_menu/slash_menu.dart';
import '../slash_menu/slash_menu_action.dart';
import '../slash_menu/custom_slash_menu_items.dart';
import '../slash_menu/default_slash_menu_items.dart';
import 'receive_blocks.dart';

import '../template.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const String _prefsKey = 'editor_doc_delta';

  late quill.QuillController _controller;
  StreamSubscription? _docSub;

  // Track the file currently open in the editor. If null, Save warns the user.
  String? _currentFilePath;

  // Slash menu state
  bool _isSlashMenuOpen = false;
  String _slashQuery = '';
  final ValueNotifier<int> _slashSelectionIndex = ValueNotifier<int>(0);

  // Custom blocks facade
  final cb = CustomBlocks();

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    _attachDocListener();
    _bootstrapDoc(); // load saved or start with template
  }

  @override
  void dispose() {
    _docSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _attachDocListener() {
    _docSub?.cancel();
    _docSub = _controller.document.changes.listen((_) {
      _saveToPrefs();
      _maybeUpdateSlashMenu();
    });
  }

  /// Load from prefs; if nothing valid, fall back to starter template.
  Future<void> _bootstrapDoc() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final ops = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final doc = quill.Document.fromJson(ops);
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _attachDocListener();
        if (mounted) setState(() {});
        return;
      } catch (_) {
        // ignore malformed stored data and fall through to starter
      }
    }
    _newFromStarter();
  }

  /// Replace the current document with the starter template.
  void _newFromStarter() {
    final doc = quill.Document.fromJson(Template.starterDelta);
    _controller = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _currentFilePath = null; // new untitled doc
    _attachDocListener();
    if (mounted) setState(() {});
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final ops = _controller.document.toDelta().toJson();
    await prefs.setString(_prefsKey, jsonEncode(ops));
  }

  /// Export current doc’s Delta JSON (as bytes).
  Uint8List _exportDeltaBytes() {
    final ops = _controller.document.toDelta().toJson();
    final jsonStr = jsonEncode(ops);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  /// Load JSON (Quill Delta array) into the editor.
  /// Optionally records the file path so "Save" writes back to it.
  void loadFromJsonString(String json, {String? sourcePath}) {
    try {
      final ops = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      final doc = quill.Document.fromJson(ops);
      setState(() {
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _currentFilePath = sourcePath;
      });
      _attachDocListener();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sourcePath == null
                  ? 'Loaded JSON'
                  : 'Loaded ${_basename(sourcePath)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load JSON: $e')));
      }
    }
  }

  /// Save back to the current file path (set when opening from the file viewer).
  Future<void> saveToCurrentFile() async {
    if (_currentFilePath == null || _currentFilePath!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No file bound. Open a JSON file from the list first.',
            ),
          ),
        );
      }
      return;
    }
    try {
      final jsonString = utf8.decode(_exportDeltaBytes());
      final file = File(_currentFilePath!);
      await file.writeAsString(jsonString);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${_basename(file.path)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  String _basename(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }

  // ---------------- Slash menu helpers ----------------

  List<SlashMenuItemData> get _allSlashItemsMerged {
    final defaults = DefaultSlashMeuItems().defaultSlashMenuItems;
    final customs = CustomSlashMenuItems().items;
    return [...defaults, const SlashMenuItemData.separator(), ...customs];
  }

  List<SlashMenuItemData> get _filteredSlashItems {
    final q = _slashQuery.trim().toLowerCase();
    final defaults = DefaultSlashMeuItems().defaultSlashMenuItems;
    final customs = CustomSlashMenuItems().items;

    bool match(SlashMenuItemData it) {
      if (it.isLabel || it.isSeparator) return false;
      if (q.isEmpty) return true;
      return it.title.toLowerCase().contains(q) ||
          it.subtitle.toLowerCase().contains(q);
    }

    final d = defaults.where(match).toList();
    final c = customs.where(match).toList();

    if (q.isEmpty) {
      if (d.isEmpty) return c;
      if (c.isEmpty) return d;
      return [...d, const SlashMenuItemData.separator(), ...c];
    } else {
      if (d.isEmpty && c.isEmpty) return [];
      if (d.isEmpty) return c;
      if (c.isEmpty) return d;
      return [...d, const SlashMenuItemData.separator(), ...c];
    }
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
    final int lineStart =
        text.lastIndexOf('\n', (caret - 1).clamp(0, text.length - 1)) + 1;
    final String lineBeforeCaret = text.substring(lineStart, caret);

    if (lineBeforeCaret.startsWith('/')) {
      final query = lineBeforeCaret.substring(1);
      _openSlashMenu(query);
      if (_filteredSlashItems.isEmpty) {
        _slashSelectionIndex.value = 0;
      } else {
        _slashSelectionIndex.value = _slashSelectionIndex.value.clamp(
          0,
          _filteredSlashItems.length - 1,
        );
      }
    } else {
      _closeSlashMenu();
    }
  }

  void _onSlashSelect(SlashMenuAction action) async {
    final selection = _controller.selection;
    if (!selection.isValid) {
      _closeSlashMenu();
      return;
    }
    final text = _controller.document.toPlainText();
    final caret = selection.baseOffset;
    final int lineStart =
        text.lastIndexOf('\n', (caret - 1).clamp(0, text.length - 1)) + 1;
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

    if (!selection.isValid) {
      _closeSlashMenu();
      return;
    }

    // Execute the action if it exists in the map, passing the controller
    if (ReceiveBlocks().actionMap.containsKey(action)) {
      await ReceiveBlocks().actionMap[action]!(
        context,
        _controller,
      ); // Pass the controller to the action
    }

    // ensure to check the case switch
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
      final next =
          (_slashSelectionIndex.value - 1 + filtered.length) % filtered.length;
      _slashSelectionIndex.value = next;
      return KeyEventResult.handled;
    } else if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter) {
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
    // Expose the editor API so the file viewer can call loadFromJsonString(...)
    attachEditorApi(context, _EditorApiImpl(this));

    final filteredItems = _filteredSlashItems;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: Column(
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                FilledButton.tonal(
                  onPressed: _newFromStarter,
                  child: const Text('New File'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: saveToCurrentFile,
                  child: const Text('Save'),
                ),
                const SizedBox(width: 12),
                if (_currentFilePath != null)
                  Flexible(
                    child: Text(
                      'Editing: ${_basename(_currentFilePath!)}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Positioned.fill(
                    child: quill.QuillEditor.basic(
                      controller: _controller,
                      config: quill.QuillEditorConfig(
                        showCursor: true,
                        scrollable: true,
                        autoFocus: true,
                        placeholder: 'Type / to open the command menu.',
                        embedBuilders: [
                          // From lib/pages/editor/custom_blocks/iframe_block.dart
                          const IframeEmbedBuilder(),
                          // From customblocks.dart barrel
                          NotesEmbedBuilder(
                            onTapEdit: (ctx, {document, existingOffset}) =>
                                cb.addEditNote(
                                  ctx,
                                  controller: _controller,
                                  document: document,
                                  existingOffset: existingOffset,
                                ),
                          ),
                          ...FlutterQuillEmbeds.editorBuilders(
                            imageEmbedConfig: QuillEditorImageEmbedConfig(
                              imageProviderBuilder: (context, imageUrl) {
                                if (imageUrl.startsWith('assets/')) {
                                  return AssetImage(imageUrl);
                                }
                                return null;
                              },
                            ),
                            videoEmbedConfig:
                                const QuillEditorVideoEmbedConfig(),
                          ),
                        ],
                        textInputAction: TextInputAction.newline,
                      ),
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

  // Call this when a file the editor is currently bound to gets renamed.
  void updateCurrentFilePath(String newPath) {
    setState(() {
      _currentFilePath = newPath;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File renamed. Now editing: ${_basename(newPath)}'),
      ),
    );
  }
}

// ================= Editor API injector (to allow external load) =================

/// Editor API the host (workspace/file viewer) can call.
abstract class _EditorScreenApi {
  void loadFromJson(String json, String filePath);
}

/// Lightweight inherited widget to expose an API to the editor.
class _EditorApiInjector extends InheritedWidget {
  final void Function(_EditorScreenApi api) onCreateApi;

  const _EditorApiInjector({
    required this.onCreateApi,
    required super.child,
    super.key,
  });

  static _EditorApiInjector? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EditorApiInjector>();

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// Extend EditorScreen’s State to register an API instance.
extension _EditorScreenApiHook on State<EditorScreen> {
  void attachEditorApi(BuildContext context, _EditorScreenApi api) {
    final injector = _EditorApiInjector.of(context);
    if (injector != null) injector.onCreateApi(api);
  }
}

/// Concrete API implementation that delegates to the editor state.
class _EditorApiImpl implements _EditorScreenApi {
  final _EditorScreenState _state;
  _EditorApiImpl(State<EditorScreen> s) : _state = s as _EditorScreenState;

  @override
  void loadFromJson(String json, String filePath) {
    _state.loadFromJsonString(json, sourcePath: filePath);
  }
}
