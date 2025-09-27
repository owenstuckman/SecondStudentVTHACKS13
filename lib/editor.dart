// lib/editor_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart' as se;

import 'slash_menu.dart';
import 'slash_menu_action.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final se.MutableDocument _document;
  late final se.MutableDocumentComposer _composer;
  late final se.Editor _editor;

  final FocusNode _editorFocusNode = FocusNode();
  final GlobalKey _documentLayoutKey = GlobalKey();

  final ValueNotifier<_SlashMenuState> _slashMenuState =
      ValueNotifier<_SlashMenuState>(const _SlashMenuHidden());
  final ValueNotifier<int> _slashMenuSelectionIndex = ValueNotifier<int>(0);
  Offset _slashMenuAnchor = Offset.zero;

  // ---- Bubble-sort style reordering (keyboard only) ----
  se.DocumentKeyboardAction get _reorderKeyboardAction => ({
        required se.SuperEditorContext editContext,
        required KeyEvent keyEvent,
      }) {
        if (keyEvent is! KeyDownEvent) {
          return se.ExecutionInstruction.continueExecution;
        }

        // Detect Option/Alt pressed (mac/win/linux)
        final pressed = HardwareKeyboard.instance.logicalKeysPressed;
        final altLike = pressed.contains(LogicalKeyboardKey.altLeft) ||
            pressed.contains(LogicalKeyboardKey.altRight) ||
            // also allow Meta as a backup on mac if you prefer:
            // pressed.contains(LogicalKeyboardKey.metaLeft) ||
            // pressed.contains(LogicalKeyboardKey.metaRight) ||
            false;

        if (!altLike) return se.ExecutionInstruction.continueExecution;

        final isShift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
            pressed.contains(LogicalKeyboardKey.shiftRight);

        // Alt+J/K (+ optional Shift) => move +/-1 or +/-2
        if (keyEvent.logicalKey == LogicalKeyboardKey.keyJ) {
          _moveCurrentNodeBy(isShift ? 2 : 1);
          return se.ExecutionInstruction.haltExecution;
        }
        if (keyEvent.logicalKey == LogicalKeyboardKey.keyK) {
          _moveCurrentNodeBy(isShift ? -2 : -1);
          return se.ExecutionInstruction.haltExecution;
        }

        return se.ExecutionInstruction.continueExecution;
      };

  // Core swap logic: moves the node that contains the caret by `delta` slots.
  void _moveCurrentNodeBy(int delta) {
    final selection = _composer.selection;
    if (selection == null) return;

    final nodeId = selection.extent.nodeId;
    final fromIndex = _document.getNodeIndexById(nodeId);
    if (fromIndex == -1) return;

    var toIndex = fromIndex + delta;
    // Clamp to valid range
    toIndex = toIndex.clamp(0, _document.length - 1);

    if (toIndex == fromIndex) return;

    _editor.execute([
      se.MoveNodeRequest(nodeId: nodeId, newIndex: toIndex),
    ]);

    // Keep the caret attached to the same node after the move.
    // We place it at the same logical position if possible.
    final movedNode = _document.getNodeById(nodeId);
    if (movedNode is se.TextNode) {
      // Try to preserve offset if selection was in text.
      final extentPos = selection.extent.nodePosition;
      final offset = extentPos is se.TextNodePosition ? extentPos.offset : 0;
      _editor.execute([
        se.ChangeSelectionRequest(
          se.DocumentSelection.collapsed(
            position: se.DocumentPosition(
              nodeId: movedNode.id,
              nodePosition: se.TextNodePosition(offset: offset.clamp(0, movedNode.text.text.length)),
            ),
          ),
          se.SelectionChangeType.placeCaret,
          se.SelectionReason.userInteraction,
        ),
      ]);
    } else {
      // Fallback: place caret at start of the moved node.
      _editor.execute([
        se.ChangeSelectionRequest(
          se.DocumentSelection.collapsed(
            position: se.DocumentPosition(
              nodeId: nodeId,
              nodePosition: const se.UpstreamDownstreamNodePosition.upstream(),
            ),
          ),
          se.SelectionChangeType.placeCaret,
          se.SelectionReason.userInteraction,
        ),
      ]);
    }
  }

  // ---- Slash menu open/close + actions ----
  se.DocumentKeyboardAction get _slashCommandKeyboardAction => ({
        required se.SuperEditorContext editContext,
        required KeyEvent keyEvent,
      }) {
        if (keyEvent is! KeyDownEvent) {
          return se.ExecutionInstruction.continueExecution;
        }

        final currentState = _slashMenuState.value;

        if (currentState is _SlashMenuVisible) {
          final itemCount = defaultSlashMenuItems.length;

          if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
            _hideSlashMenu(insertSlashOnDismiss: true);
            return se.ExecutionInstruction.haltExecution;
          }

          if (itemCount > 0) {
            if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
              _slashMenuSelectionIndex.value =
                  (_slashMenuSelectionIndex.value + 1) % itemCount;
              return se.ExecutionInstruction.haltExecution;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
              _slashMenuSelectionIndex.value =
                  (_slashMenuSelectionIndex.value - 1 + itemCount) % itemCount;
              return se.ExecutionInstruction.haltExecution;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
              _finalizeSlashSelection(
                defaultSlashMenuItems[_slashMenuSelectionIndex.value].action,
              );
              return se.ExecutionInstruction.haltExecution;
            }
          }
        }

        // Open slash menu only at start of a paragraph.
        if (keyEvent.logicalKey == LogicalKeyboardKey.slash &&
            keyEvent.character == '/') {
          final selection = editContext.composer.selection;
          if (selection == null || !selection.isCollapsed) {
            return se.ExecutionInstruction.continueExecution;
          }

          final extent = selection.extent;
          final node = editContext.document.getNodeById(extent.nodeId);
          if (node is! se.ParagraphNode) {
            return se.ExecutionInstruction.continueExecution;
          }

          final pos = extent.nodePosition;
          if (pos is! se.TextNodePosition || pos.offset != 0) {
            return se.ExecutionInstruction.continueExecution;
          }

          final caretRect = editContext.documentLayout.getRectForPosition(extent);
          if (caretRect == null) {
            return se.ExecutionInstruction.continueExecution;
          }

          _slashMenuAnchor = Offset(caretRect.left, caretRect.bottom);
          _showSlashMenu(extent);
          return se.ExecutionInstruction.haltExecution;
        }

        if (_slashMenuState.value is _SlashMenuVisible) {
          _hideSlashMenu();
        }

        return se.ExecutionInstruction.continueExecution;
      };

  @override
  void initState() {
    super.initState();

    final initialParagraphId = se.Editor.createNodeId();
    _document = se.MutableDocument(
      nodes: [
        se.ParagraphNode(id: initialParagraphId, text: se.AttributedText()),
      ],
    );

    _composer = se.MutableDocumentComposer(
      initialSelection: se.DocumentSelection.collapsed(
        position: se.DocumentPosition(
          nodeId: initialParagraphId,
          nodePosition: const se.TextNodePosition(offset: 0),
        ),
      ),
    );

    _editor = se.createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );

    _composer.selectionNotifier.addListener(_handleSelectionChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editorFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _composer.selectionNotifier.removeListener(_handleSelectionChange);
    _editor.dispose();
    _composer.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _handleSelectionChange() {
    final state = _slashMenuState.value;
    if (state is _SlashMenuVisible &&
        _composer.selection?.extent != state.triggerPosition) {
      _hideSlashMenu();
    }
  }

  void _showSlashMenu(se.DocumentPosition triggerPosition) {
    _slashMenuSelectionIndex.value = 0;
    _slashMenuState.value = _SlashMenuVisible(triggerPosition);
  }

  void _hideSlashMenu({bool insertSlashOnDismiss = false}) {
    final state = _slashMenuState.value;
    if (state is _SlashMenuVisible && insertSlashOnDismiss) {
      _insertSlashAtPosition(state.triggerPosition);
    }
    _slashMenuState.value = const _SlashMenuHidden();
  }

  void _insertSlashAtPosition(se.DocumentPosition position) {
    _editor.execute([
      se.ChangeSelectionRequest(
        se.DocumentSelection.collapsed(position: position),
        se.SelectionChangeType.placeCaret,
        se.SelectionReason.userInteraction,
      ),
      se.InsertCharacterAtCaretRequest(character: '/'),
    ]);
  }

  void _finalizeSlashSelection(SlashMenuAction action) {
    final state = _slashMenuState.value;
    if (state is! _SlashMenuVisible) return;
    _applySlashMenuAction(action, state.triggerPosition);
    _slashMenuState.value = const _SlashMenuHidden();
  }

  void _applySlashMenuAction(
      SlashMenuAction action, se.DocumentPosition triggerPosition) {
    _editor.execute([
      se.ChangeSelectionRequest(
        se.DocumentSelection.collapsed(position: triggerPosition),
        se.SelectionChangeType.placeCaret,
        se.SelectionReason.userInteraction,
      ),
    ]);

    final node = _document.getNodeById(triggerPosition.nodeId);

    switch (action) {
      case SlashMenuAction.paragraph:
        if (node is se.ParagraphNode) {
          _editor.execute(
            [se.ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: null)],
          );
        }
        break;

      case SlashMenuAction.heading1:
        if (node is se.ParagraphNode) {
          _editor.execute(
            [se.ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: se.header1Attribution)],
          );
        }
        break;

      case SlashMenuAction.heading2:
        if (node is se.ParagraphNode) {
          _editor.execute(
            [se.ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: se.header2Attribution)],
          );
        }
        break;

      case SlashMenuAction.heading3:
        if (node is se.ParagraphNode) {
          _editor.execute(
            [se.ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: se.header3Attribution)],
          );
        }
        break;

      case SlashMenuAction.bulletList:
        if (node is se.ParagraphNode) {
          _editor.execute([
            se.ReplaceNodeRequest(
              existingNodeId: node.id,
              newNode: se.ListItemNode.unordered(id: node.id, text: node.text),
            ),
          ]);
        }
        break;

      case SlashMenuAction.numberedList:
        if (node is se.ParagraphNode) {
          _editor.execute([
            se.ReplaceNodeRequest(
              existingNodeId: node.id,
              newNode: se.ListItemNode.ordered(id: node.id, text: node.text),
            ),
          ]);
        }
        break;

      case SlashMenuAction.toDoList:
        if (node is se.ParagraphNode) {
          _editor.execute([
            se.ReplaceNodeRequest(
              existingNodeId: node.id,
              newNode: se.TaskNode(id: node.id, text: node.text, isComplete: false),
            ),
          ]);
        }
        break;

      case SlashMenuAction.divider:
        _editor.execute([
          se.InsertNodeAtCaretRequest(node: se.HorizontalRuleNode(id: se.Editor.createNodeId())),
        ]);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // No handles, no line numbers, no drag overlay — just the editor and the slash menu.
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 56, right: 24),
          child: se.SuperEditor(
            editor: _editor,
            documentLayoutKey: _documentLayoutKey,
            inputSource: se.TextInputSource.keyboard,
            focusNode: _editorFocusNode,
            keyboardActions: [
              _reorderKeyboardAction,     // <-- bubble-sort style moves
              _slashCommandKeyboardAction,
              ...se.defaultKeyboardActions,
            ],
          ),
        ),

        // Slash menu overlay
        ValueListenableBuilder<_SlashMenuState>(
          valueListenable: _slashMenuState,
          builder: (context, state, _) {
            if (state is! _SlashMenuVisible) return const SizedBox.shrink();

            final renderBox = context.findRenderObject() as RenderBox?;
            final overlaySize = renderBox?.size ?? Size.zero;
            final menuHeight = slashMenuTotalHeight(defaultSlashMenuItems.length);
            const menuWidth = defaultSlashMenuMaxWidth;

            double dx = _slashMenuAnchor.dx - menuWidth / 2;
            dx = dx.clamp(16.0, math.max(16.0, overlaySize.width - menuWidth - 16));

            double dy = _slashMenuAnchor.dy + 10;
            final double bottomLimit = overlaySize.height - menuHeight - 16;
            if (overlaySize.height > 0 && dy > bottomLimit) {
              dy = _slashMenuAnchor.dy - menuHeight - 10;
            }
            dy = dy.clamp(16.0, math.max(16.0, bottomLimit));

            return Positioned(
              left: dx,
              top: dy,
              child: SlashMenu(
                items: defaultSlashMenuItems,
                selectionIndexListenable: _slashMenuSelectionIndex,
                onSelect: _finalizeSlashSelection,
                onDismiss: () => _hideSlashMenu(insertSlashOnDismiss: true),
                maxWidth: menuWidth,
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---- Local slash menu state (kept here; UI in slash_menu.dart) ----
abstract class _SlashMenuState {
  const _SlashMenuState();
}

class _SlashMenuHidden extends _SlashMenuState {
  const _SlashMenuHidden();
}

class _SlashMenuVisible extends _SlashMenuState {
  const _SlashMenuVisible(this.triggerPosition);
  final se.DocumentPosition triggerPosition;
}
