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

  // Slash menu state
  final ValueNotifier<_SlashMenuState> _slashMenuState =
      ValueNotifier<_SlashMenuState>(const _SlashMenuHidden());
  final ValueNotifier<int> _slashMenuSelectionIndex = ValueNotifier<int>(0);
  Offset _slashMenuAnchor = Offset.zero;

  // Floating reorder bubble (arrows) — anchored to caret line
  Offset? _reorderBubbleAnchor; // in our Stack's local coords
  bool _reorderBubbleVisible = false;
  bool _reorderBubbleExpanded = false;
  final GlobalKey _reorderBubbleKey = GlobalKey();

  // ---------- Keyboard: bubble-sort style moves ----------
  se.DocumentKeyboardAction get _reorderKeyboardAction => ({
        required se.SuperEditorContext editContext,
        required KeyEvent keyEvent,
      }) {
        if (keyEvent is! KeyDownEvent) {
          return se.ExecutionInstruction.continueExecution;
        }

        final pressed = HardwareKeyboard.instance.logicalKeysPressed;
        final altLike = pressed.contains(LogicalKeyboardKey.altLeft) ||
            pressed.contains(LogicalKeyboardKey.altRight);

        if (!altLike) return se.ExecutionInstruction.continueExecution;

        final isShift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
            pressed.contains(LogicalKeyboardKey.shiftRight);

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

  void _moveCurrentNodeBy(int delta) {
    final selection = _composer.selection;
    if (selection == null) return;

    final nodeId = selection.extent.nodeId;
    final fromIndex = _document.getNodeIndexById(nodeId);
    if (fromIndex == -1) return;

    var toIndex = (fromIndex + delta).clamp(0, _document.length - 1);
    if (toIndex == fromIndex) return;

    _editor.execute([
      se.MoveNodeRequest(nodeId: nodeId, newIndex: toIndex),
    ]);

    // Keep caret on same node, try to preserve text offset.
    final movedNode = _document.getNodeById(nodeId);
    if (movedNode is se.TextNode) {
      final extentPos = selection.extent.nodePosition;
      final offset = extentPos is se.TextNodePosition ? extentPos.offset : 0;
      _editor.execute([
        se.ChangeSelectionRequest(
          se.DocumentSelection.collapsed(
            position: se.DocumentPosition(
              nodeId: movedNode.id,
              nodePosition: se.TextNodePosition(
                offset: offset.clamp(0, movedNode.text.text.length),
              ),
            ),
          ),
          se.SelectionChangeType.placeCaret,
          se.SelectionReason.userInteraction,
        ),
      ]);
    } else {
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

    // After layout shifts, update bubble anchor next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateReorderBubbleAnchor();
    });
  }

  // ---------- Slash menu keyboard handling ----------
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

        // Open: only when caret is at start of a paragraph.
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

  // Hide the reorder bubble on general typing or navigation (except our Alt+J/K moves).
  se.DocumentKeyboardAction get _dismissBubbleOnInputAction => ({
        required se.SuperEditorContext editContext,
        required KeyEvent keyEvent,
      }) {
        if (!_reorderBubbleVisible) {
          return se.ExecutionInstruction.continueExecution;
        }

        if (keyEvent is! KeyDownEvent) {
          return se.ExecutionInstruction.continueExecution;
        }

        final pressed = HardwareKeyboard.instance.logicalKeysPressed;
        final altLike = pressed.contains(LogicalKeyboardKey.altLeft) ||
            pressed.contains(LogicalKeyboardKey.altRight);

        // Don't dismiss when using our Alt+J/K shortcuts.
        if (altLike && (keyEvent.logicalKey == LogicalKeyboardKey.keyJ || keyEvent.logicalKey == LogicalKeyboardKey.keyK)) {
          return se.ExecutionInstruction.continueExecution;
        }

        // Dismiss for most other inputs: character keys, enter, backspace, delete, arrows, space, tab.
        final isCharacter = keyEvent.character != null && keyEvent.character!.isNotEmpty;
        final lk = keyEvent.logicalKey;
        final isEditingOrNav = isCharacter ||
            lk == LogicalKeyboardKey.enter ||
            lk == LogicalKeyboardKey.backspace ||
            lk == LogicalKeyboardKey.delete ||
            lk == LogicalKeyboardKey.space ||
            lk == LogicalKeyboardKey.tab ||
            lk == LogicalKeyboardKey.arrowUp ||
            lk == LogicalKeyboardKey.arrowDown ||
            lk == LogicalKeyboardKey.arrowLeft ||
            lk == LogicalKeyboardKey.arrowRight ||
            lk == LogicalKeyboardKey.pageUp ||
            lk == LogicalKeyboardKey.pageDown ||
            lk == LogicalKeyboardKey.home ||
            lk == LogicalKeyboardKey.end;

        if (isEditingOrNav) {
          // Hide bubble but allow the keystroke to continue.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _reorderBubbleVisible = false;
              _reorderBubbleExpanded = false;
            });
          });
        }

        return se.ExecutionInstruction.continueExecution;
      };

  // ---------- Lifecycle ----------
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

    _composer.selectionNotifier.addListener(() {
      _handleSelectionChange();
      _updateReorderBubbleAnchor();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editorFocusNode.requestFocus();
      _updateReorderBubbleAnchor();
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

  // ---------- Reorder bubble placement ----------
  void _updateReorderBubbleAnchor() {
    final selection = _composer.selection;
    final layout = _documentLayoutKey.currentState as se.DocumentLayout?;
    if (selection == null || layout == null) {
      setState(() {
        _reorderBubbleAnchor = null;
        _reorderBubbleVisible = false;
      });
      return;
    }

    final rect = layout.getRectForPosition(selection.extent);
    if (rect == null) {
      setState(() {
        _reorderBubbleAnchor = null;
        _reorderBubbleVisible = false;
      });
      return;
    }

    final topLeftGlobal =
        layout.getGlobalOffsetFromDocumentOffset(rect.topLeft);
    final stackBox = context.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final local = stackBox.globalToLocal(topLeftGlobal);

    setState(() {
      _reorderBubbleAnchor = local;
      _reorderBubbleVisible = true;
    });
  }

  // ---------- Slash menu helpers ----------
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
          se.InsertNodeAtCaretRequest(
            node: se.HorizontalRuleNode(id: se.Editor.createNodeId()),
          ),
        ]);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Order: SuperEditor (with scroll listener), floating reorder bubble, slash menu.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (!_reorderBubbleVisible) return;

        final ctx = _reorderBubbleKey.currentContext;
        final box = ctx?.findRenderObject() as RenderBox?;
        if (box != null) {
          final topLeft = box.localToGlobal(Offset.zero);
          final rect = topLeft & box.size;
          // If tap is within bubble, don't dismiss; let the bubble handle it.
          if (rect.contains(event.position)) {
            return;
          }
        }

        setState(() {
          _reorderBubbleVisible = false;
          _reorderBubbleExpanded = false;
        });
      },
      child: Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // Keep bubble glued to the caret line on scroll.
            _updateReorderBubbleAnchor();
            return false;
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 24),
            child: se.SuperEditor(
              editor: _editor,
              documentLayoutKey: _documentLayoutKey,
              inputSource: se.TextInputSource.keyboard,
              focusNode: _editorFocusNode,
              keyboardActions: [
                // Dismiss first so it runs before other actions.
                _dismissBubbleOnInputAction,
                _reorderKeyboardAction,
                _slashCommandKeyboardAction,
                ...se.defaultKeyboardActions,
              ],
            ),
          ),
        ),

        // Floating reorder bubble (Up2 / Up1 / Down1 / Down2)
        if (_reorderBubbleVisible && _reorderBubbleAnchor != null)
          Positioned(
            // Pin to a fixed gutter near the start of the line (not the caret).
            left: 4,
            top: _reorderBubbleAnchor!.dy - 6,
            child: _ReorderBubble(
              key: _reorderBubbleKey,
              expanded: _reorderBubbleExpanded,
              onToggleExpanded: () => setState(() => _reorderBubbleExpanded = !_reorderBubbleExpanded),
              onUp1: () => _moveCurrentNodeBy(-1),
              onUp2: () => _moveCurrentNodeBy(-2),
              onDown1: () => _moveCurrentNodeBy(1),
              onDown2: () => _moveCurrentNodeBy(2),
              onClose: () => setState(() {
                _reorderBubbleVisible = false;
                _reorderBubbleExpanded = false;
              }),
            ),
          ),

        // Slash menu overlay (unchanged)
        ValueListenableBuilder<_SlashMenuState>(
          valueListenable: _slashMenuState,
          builder: (context, state, _) {
            if (state is! _SlashMenuVisible) return const SizedBox.shrink();

            final renderBox = context.findRenderObject() as RenderBox?;
            final overlaySize = renderBox?.size ?? Size.zero;
            final menuHeight =
                slashMenuTotalHeight(defaultSlashMenuItems.length);
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
    ),
    );
  }
}

// ---------- Local slash menu state ----------
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

// ---------- Floating reorder bubble UI ----------
class _ReorderBubble extends StatelessWidget {
  const _ReorderBubble({
    super.key,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onUp1,
    required this.onUp2,
    required this.onDown1,
    required this.onDown2,
    required this.onClose,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onUp1, onUp2, onDown1, onDown2, onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!expanded) {
      // Collapsed: compact handle button
      return Material(
        elevation: 4,
        color: theme.colorScheme.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onToggleExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(
              Icons.unfold_more,
              size: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    // Expanded: full set of controls
    return Material(
      elevation: 6,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Collapse',
              icon: const Icon(Icons.chevron_left, size: 16),
              onPressed: onToggleExpanded,
              splashRadius: 14,
            ),
            IconButton(
              tooltip: 'Up 2',
              icon: const Icon(Icons.keyboard_double_arrow_up, size: 18),
              onPressed: onUp2,
              splashRadius: 16,
            ),
            IconButton(
              tooltip: 'Up 1',
              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              onPressed: onUp1,
              splashRadius: 16,
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Down 1',
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              onPressed: onDown1,
              splashRadius: 16,
            ),
            IconButton(
              tooltip: 'Down 2',
              icon: const Icon(Icons.keyboard_double_arrow_down, size: 18),
              onPressed: onDown2,
              splashRadius: 16,
            ),
            const SizedBox(width: 2),
            // Close button removed; bubble hides on general click/typing.
          ],
        ),
      ),
    );
  }
}