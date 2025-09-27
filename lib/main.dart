import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import 'slash_menu.dart';
import 'slash_menu_action.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  final FocusNode _editorFocusNode = FocusNode();

  final GlobalKey _docLayoutKey = GlobalKey();

  final ValueNotifier<_SlashMenuState> _slashMenuState = ValueNotifier(_SlashMenuHidden());
  final ValueNotifier<int> _slashMenuSelectionIndex = ValueNotifier(0);

  DocumentKeyboardAction get _slashCommandKeyboardAction => ({
        required SuperEditorContext editContext,
        required KeyEvent keyEvent,
      }) {
        if (keyEvent is! KeyDownEvent) {
          return ExecutionInstruction.continueExecution;
        }

        final currentState = _slashMenuState.value;
        if (currentState is _SlashMenuVisible) {
          if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
            _hideSlashMenu(insertSlashOnDismiss: true);
            return ExecutionInstruction.haltExecution;
          }

          final itemCount = defaultSlashMenuItems.length;
          if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown && itemCount > 0) {
            _slashMenuSelectionIndex.value = (_slashMenuSelectionIndex.value + 1) % itemCount;
            return ExecutionInstruction.haltExecution;
          }

          if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp && itemCount > 0) {
            _slashMenuSelectionIndex.value = (_slashMenuSelectionIndex.value - 1 + itemCount) % itemCount;
            return ExecutionInstruction.haltExecution;
          }

          if (keyEvent.logicalKey == LogicalKeyboardKey.enter && itemCount > 0) {
            _finalizeSlashSelection(defaultSlashMenuItems[_slashMenuSelectionIndex.value].action);
            return ExecutionInstruction.haltExecution;
          }
        }

        if (keyEvent.logicalKey == LogicalKeyboardKey.slash && keyEvent.character == '/') {
          final selection = editContext.composer.selection;
          if (selection == null || !selection.isCollapsed) {
            return ExecutionInstruction.continueExecution;
          }

          final extent = selection.extent;
          final node = editContext.document.getNodeById(extent.nodeId);
          if (node is! ParagraphNode) {
            return ExecutionInstruction.continueExecution;
          }

          final nodePosition = extent.nodePosition;
          if (nodePosition is! TextNodePosition || nodePosition.offset != 0) {
            return ExecutionInstruction.continueExecution;
          }

          final caretRect =
              editContext.documentLayout.getRectForPosition(editContext.composer.selection!.extent);
          if (caretRect == null) {
            return ExecutionInstruction.continueExecution;
          }

          final anchor = Offset(caretRect.left, caretRect.bottom + 8);
          _showSlashMenu(anchor, editContext.composer.selection!.extent);
          return ExecutionInstruction.haltExecution;
        }

        if (_slashMenuState.value is _SlashMenuVisible) {
          _hideSlashMenu();
        }

        return ExecutionInstruction.continueExecution;
      };

  @override
  void initState() {
    super.initState();
    final initialParagraphId = Editor.createNodeId();
    _document = MutableDocument(
      nodes: [
        ParagraphNode(
          id: initialParagraphId,
          text: AttributedText(),
        ),
      ],
    );
    _composer = MutableDocumentComposer(
      initialSelection: DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: initialParagraphId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
    );
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );
    _composer.selectionNotifier.addListener(_handleSelectionChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _editorFocusNode.requestFocus();
      }
    });
  }

  void _handleSelectionChange() {
    final state = _slashMenuState.value;
    if (state is _SlashMenuVisible &&
        _composer.selection?.extent != state.triggerPosition) {
      _hideSlashMenu();
    }
  }

  void _showSlashMenu(Offset anchor, DocumentPosition triggerPosition) {
    _slashMenuSelectionIndex.value = 0;
    _slashMenuState.value = _SlashMenuVisible(
      anchor,
      triggerPosition,
    );
  }

  void _hideSlashMenu({bool insertSlashOnDismiss = false}) {
    final state = _slashMenuState.value;
    if (state is _SlashMenuVisible && insertSlashOnDismiss) {
      _insertSlashAtPosition(state.triggerPosition);
    }
    _slashMenuState.value = _SlashMenuHidden();
  }

  void _insertSlashAtPosition(DocumentPosition position) {
    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: position),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      InsertCharacterAtCaretRequest(character: '/'),
    ]);
  }

  void _finalizeSlashSelection(SlashMenuAction action) {
    final state = _slashMenuState.value;
    if (state is! _SlashMenuVisible) {
      return;
    }

    _applySlashMenuAction(action, state.triggerPosition);
    _slashMenuState.value = _SlashMenuHidden();
  }

  void _applySlashMenuAction(
      SlashMenuAction action, DocumentPosition triggerPosition) {
    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: triggerPosition),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);

    final nodeId = triggerPosition.nodeId;
    final node = _document.getNodeById(nodeId);

    switch (action) {
      case SlashMenuAction.paragraph:
        if (node is ParagraphNode) {
          _editor.execute([
            ChangeParagraphBlockTypeRequest(
              nodeId: node.id,
              blockType: null,
            ),
          ]);
        }
        break;
      case SlashMenuAction.heading1:
        if (node is ParagraphNode) {
          _editor.execute([
            ChangeParagraphBlockTypeRequest(
              nodeId: node.id,
              blockType: header1Attribution,
            ),
          ]);
        }
        break;
      case SlashMenuAction.heading2:
        if (node is ParagraphNode) {
          _editor.execute([
            ChangeParagraphBlockTypeRequest(
              nodeId: node.id,
              blockType: header2Attribution,
            ),
          ]);
        }
        break;
      case SlashMenuAction.heading3:
        if (node is ParagraphNode) {
          _editor.execute([
            ChangeParagraphBlockTypeRequest(
              nodeId: node.id,
              blockType: header3Attribution,
            ),
          ]);
        }
        break;
      case SlashMenuAction.bulletList:
        if (node is ParagraphNode) {
          _editor.execute([
            ReplaceNodeRequest(
              existingNodeId: node.id,
              newNode: ListItemNode.unordered(
                id: node.id,
                text: node.text,
              ),
            ),
          ]);
        }
        break;
      case SlashMenuAction.numberedList:
        if (node is ParagraphNode) {
          _editor.execute([
            ReplaceNodeRequest(
              existingNodeId: node.id,
              newNode: ListItemNode.ordered(
                id: node.id,
                text: node.text,
              ),
            ),
          ]);
        }
        break;
      case SlashMenuAction.quote:
        if (node is ParagraphNode) {
          _editor.execute([
            ChangeParagraphBlockTypeRequest(
              nodeId: node.id,
              blockType: blockquoteAttribution,
            ),
          ]);
        }
        break;
      case SlashMenuAction.divider:
        _editor.execute([
          InsertNodeAtCaretRequest(
            node: HorizontalRuleNode(id: Editor.createNodeId()),
          ),
        ]);
        break;
    }

    _hideSlashMenu();
  }

  @override
  void dispose() {
    _composer.selectionNotifier.removeListener(_handleSelectionChange);
    _editor.dispose();
    _composer.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SecondStudent')),
        body: Stack(
          children: [
            SuperEditor(
              editor: _editor,
              documentLayoutKey: _docLayoutKey,
              inputSource: TextInputSource.keyboard,
              focusNode: _editorFocusNode,
              keyboardActions: [
                _slashCommandKeyboardAction,
                ...defaultKeyboardActions,
              ],
            ),
            ValueListenableBuilder<_SlashMenuState>(
              valueListenable: _slashMenuState,
              builder: (context, state, _) {
                if (state is! _SlashMenuVisible) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: state.anchor.dx,
                  top: state.anchor.dy,
                  child: SlashMenu(
                    items: defaultSlashMenuItems,
                    selectionIndexListenable: _slashMenuSelectionIndex,
                    onSelect: _finalizeSlashSelection,
                    onDismiss: () => _hideSlashMenu(insertSlashOnDismiss: true),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

abstract class _SlashMenuState {
  const _SlashMenuState();
}

class _SlashMenuHidden extends _SlashMenuState {
  const _SlashMenuHidden();
}

class _SlashMenuVisible extends _SlashMenuState {
  const _SlashMenuVisible(this.anchor, this.triggerPosition);

  final Offset anchor;
  final DocumentPosition triggerPosition;
}

void main() {
  runApp(const MyApp());
}
