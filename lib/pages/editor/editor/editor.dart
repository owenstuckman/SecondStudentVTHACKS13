// lib/editor.dart — Quill-backed editor with JSON load/save and external load API

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Custom blocks: helpers (normalize/insert/addEditNote, Notes builder, etc.)
import 'package:secondstudent/pages/editor/custom_blocks/customblocks.dart';
import 'package:secondstudent/pages/editor/custom_blocks/pdf_block.dart';
import 'package:secondstudent/pages/editor/custom_blocks/page_link_block.dart';
import 'package:secondstudent/pages/editor/custom_blocks/page_link_service.dart';
import 'package:secondstudent/pages/editor/custom_blocks/readonly_block.dart';
import 'package:secondstudent/pages/editor/custom_blocks/table_block.dart';
import 'package:secondstudent/pages/editor/editor/table_editor.dart';


// Iframe builder lives here (per your note)
import 'package:secondstudent/pages/editor/custom_blocks/iframe_block.dart';

import '../slash_menu/slash_menu.dart';
import '../slash_menu/slash_menu_action.dart';
import '../slash_menu/custom_slash_menu_items.dart';
import '../slash_menu/default_slash_menu_items.dart';
import 'receive_blocks.dart';
import '../../../globals/database.dart';
import 'package:secondstudent/pages/editor/sync.dart';

import '../template.dart';

/**

need to somehow import this: 
/.secondstudent/customblocks/execs.dart

 */

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    this.onFileSelected,
    this.initialJson,
    this.fileLabel,
  });

  final Future<void> Function(File file)? onFileSelected;
  final String? initialJson;
  final String? fileLabel;

  @override
  State<EditorScreen> createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen> {
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

    if (widget.initialJson != null && widget.initialJson!.isNotEmpty) {
      // try load initial json override
      try {
        loadFromJsonString(widget.initialJson!, sourcePath: widget.fileLabel);
      } catch (_) {
        _bootstrapDoc();
      }
    } else {
      _bootstrapDoc(); // load saved or start with template
    }
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

  /// Save back to the current file path (set when opening from the file viewer).
  Future<void> syncToCurrentFile(String filePath) async {
    final user = supabase.auth.getUser();
    if (user == null) {
      return;
    }

    Sync().syncFile(filePath);
  }

  String _basename(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }

  Future<String?> _promptForUrl(
    BuildContext context, {
    required String label,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Helper method to open a JSON file into the editor
  Future<void> _openJsonIntoEditor(String absPath) async {
    final json = await File(absPath).readAsString();
    loadFromJsonString(json, sourcePath: absPath);
  }

  // ---------------- Slash menu helpers ----------------

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
        _controller.replaceText(
          index,
          0,
          '\n---\n',
          const TextSelection.collapsed(offset: 0),
        );
        break;
      case SlashMenuAction.codeBlock:
        _controller.formatSelection(quill.Attribute.codeBlock);
        break;

      case SlashMenuAction.addEditNote:
        await cb.addEditNote(
          context,
          controller: _controller,
          document: _controller.document,
          existingOffset: _controller.selection.isValid
              ? _controller.selection.start
              : null,
        );
        break;

      case SlashMenuAction.pageLink:
        await PageLinkBlock.insertAtSelection(
          context: context,
          controller: _controller,
          pickJsonAbsolutePath: (ctx) async {
            // Use the file picker from PageLinkService
            final file = await PageLinkService.pickWorkspaceJson(ctx);
            return file?.path;
          },
        );
        break;

      case SlashMenuAction.image:
        _promptForUrl(context, label: 'Image URL').then((url) {
          if (url == null || url.isEmpty) return;
          final idx = _controller.selection.baseOffset;
          _controller.replaceText(
            idx,
            0,
            quill.BlockEmbed.image(url),
            const TextSelection.collapsed(offset: 0),
          );
        });
        break;

      case SlashMenuAction.video:
        _promptForUrl(context, label: 'Video URL').then((url) {
          if (url == null || url.isEmpty) return;
          final idx = _controller.selection.baseOffset;
          _controller.replaceText(
            idx,
            0,
            quill.BlockEmbed.video(url),
            const TextSelection.collapsed(offset: 0),
          );
        });
        break;

      case SlashMenuAction.iframeExcalidraw:
        _promptForUrl(context, label: 'Excalidraw room/share URL').then((url) {
          if (url == null || url.isEmpty) return;
          cb.insertIframe(
            _controller,
            url,
            height: 560,
          ); // helper normalizes & inserts
        });
        break;

      case SlashMenuAction.iframeGoogleDoc:
        _promptForUrl(
          context,
          label: 'Google Doc (published) or Drive preview URL',
        ).then((url) {
          if (url == null || url.isEmpty) return;
          final normalized = cb.normalizeGoogle(url);
          if (normalized == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Use a published-to-web or /preview Google link.',
                ),
              ),
            );
            return;
          }
          cb.insertIframe(_controller, normalized, height: 560);
        });
        break;

      case SlashMenuAction.embedPdf:
        _promptForUrl(
          context,
          label: 'PDF URL (https://), data: URI, or assets/path.pdf',
        ).then((url) {
          if (url == null || url.isEmpty) return;
          final insertAt = _controller.selection.isValid
              ? _controller.selection.start
              : _controller.document.length;
          final block = quill.BlockEmbed.custom(
            PdfBlockEmbed(url: url, height: 560),
          );
          _controller.replaceText(
            insertAt,
            0,
            block,
            TextSelection.collapsed(offset: insertAt + 1),
          );
          _controller.replaceText(
            insertAt + 1,
            0,
            '\n',
            TextSelection.collapsed(offset: insertAt + 2),
          );
        });
        break;
      case SlashMenuAction.table:
        final insertAt = _controller.selection.isValid
            ? _controller.selection.start
            : _controller.document.length;
        final block = quill.BlockEmbed.custom(
          TableBlockEmbed(
            rows: const [
              ['Header 1', 'Header 2'],
              ['Row 1 Col 1', 'Row 1 Col 2'],
            ],
            headerRow: true,
            colAlign: const ['left', 'center'],
          ),
        );
        _controller.replaceText(
          insertAt,
          0,
          block,
          TextSelection.collapsed(offset: insertAt + 1),
        );
        _controller.replaceText(
          insertAt + 1,
          0,
          '\n',
          TextSelection.collapsed(offset: insertAt + 2),
        );
        break;
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
                        linkActionPickerDelegate:
                            (ctx, link, isReadOnly) async =>
                                quill.LinkMenuAction.launch,
                        onLaunchUrl: (url) async {
                          // Handle file:// URLs for page links
                          if (url.startsWith('file://')) {
                            final rel = url.substring('file://'.length);
                            final root = await Workspace.root();
                            if (root != null && root.isNotEmpty) {
                              final abs = Workspace.toAbsolute(root, rel);
                              final file = File(abs);
                              if (await file.exists()) {
                                final json = await file.readAsString();
                                loadFromJsonString(json, sourcePath: abs);
                                return;
                              }
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Page not found: $rel')),
                            );
                            return;
                          }

                          // Handle other URLs externally
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            try {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {}
                          }
                        },
                        embedBuilders: [
                          TableEmbedBuilder(
                            onEdit:
                                (
                                  context, {
                                  required nodeOffset,
                                  required currentRows,
                                  required headerRow,
                                  required colAlign,
                                }) => editTableBlock(
                                  context,
                                  controller: _controller,
                                  nodeOffset: nodeOffset,
                                  currentRows: currentRows,
                                  headerRow: headerRow,
                                  colAlign: colAlign,
                                ),
                          ),
                          PageLinkBlockBuilder(
                            onOpenJson: _openJsonIntoEditor,
                            onFileSelected: widget.onFileSelected,
                          ),
                          const PdfEmbedBuilder(),
                          const IframeEmbedBuilder(),
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
                                if (imageUrl.startsWith('assets/'))
                                  return AssetImage(imageUrl);
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

  const _EditorApiInjector({required this.onCreateApi, required super.child});

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
  final EditorScreenState _state;
  _EditorApiImpl(State<EditorScreen> s) : _state = s as EditorScreenState;

  @override
  void loadFromJson(String json, String filePath) {
    _state.loadFromJsonString(json, sourcePath: filePath);
  }
}
