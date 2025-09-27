import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart' as se;

import 'slash_menu.dart';
import 'slash_menu_action.dart';
import 'node_dnd.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

// --- Layout knobs (tweak to taste) ---
const double kPageSidePadding = 20;   // outer page padding
const double kContentMaxWidth  = 900; // column width
const double kContentLeftInset = 56;  // text column offset from the left edge

// Drag handle placement (NodeDragLayer also uses these)
const double kHandleGap   = 6;        // distance handle sits left of text
const double kHandleWidth = 36;       // visual width of handle box

class _EditorScreenState extends State<EditorScreen> {
  late final se.MutableDocument _document;
  late final se.MutableDocumentComposer _composer;
  late final se.Editor _editor;

  final FocusNode _editorFocusNode = FocusNode();
  final GlobalKey _documentLayoutKey = GlobalKey();

  // Anchor the overlayed drag layer to the editor.
  final LayerLink _editorLink = LayerLink();

  final ValueNotifier<_SlashMenuState> _slashMenuState = ValueNotifier(_SlashMenuHidden());
  final ValueNotifier<int> _slashMenuSelectionIndex = ValueNotifier(0);
  Offset _slashMenuAnchor = Offset.zero;

  OverlayEntry? _dragOverlayEntry;

  se.DocumentKeyboardAction get _slashCommandKeyboardAction => ({
        required se.SuperEditorContext editContext,
        required KeyEvent keyEvent,
      }) {
        if (keyEvent is! KeyDownEvent) {
          return se.ExecutionInstruction.continueExecution;
        }

        final currentState = _slashMenuState.value;
        if (currentState is _SlashMenuVisible) {
          if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
            _hideSlashMenu(insertSlashOnDismiss: true);
            return se.ExecutionInstruction.haltExecution;
          }

          final itemCount = defaultSlashMenuItems.length;
          if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown && itemCount > 0) {
            _slashMenuSelectionIndex.value = (_slashMenuSelectionIndex.value + 1) % itemCount;
            return se.ExecutionInstruction.haltExecution;
          }

          if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp && itemCount > 0) {
            _slashMenuSelectionIndex.value = (_slashMenuSelectionIndex.value - 1 + itemCount) % itemCount;
            return se.ExecutionInstruction.haltExecution;
          }

          if (keyEvent.logicalKey == LogicalKeyboardKey.enter && itemCount > 0) {
            _finalizeSlashSelection(defaultSlashMenuItems[_slashMenuSelectionIndex.value].action);
            return se.ExecutionInstruction.haltExecution;
          }
        }

        if (keyEvent.logicalKey == LogicalKeyboardKey.slash && keyEvent.character == '/') {
          final selection = editContext.composer.selection;
          if (selection == null || !selection.isCollapsed) {
            return se.ExecutionInstruction.continueExecution;
          }

          final extent = selection.extent;
          final node = editContext.document.getNodeById(extent.nodeId);
          if (node is! se.ParagraphNode) {
            return se.ExecutionInstruction.continueExecution;
          }
          final nodePosition = extent.nodePosition;
          if (nodePosition is! se.TextNodePosition || nodePosition.offset != 0) {
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

    _editor = se.createDefaultDocumentEditor(document: _document, composer: _composer);

    _composer.selectionNotifier.addListener(_handleSelectionChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editorFocusNode.requestFocus();
      _mountDragOverlay();
    });
  }

  void _mountDragOverlay() {
    _dragOverlayEntry = OverlayEntry(
      maintainState: true,
      builder: (context) {
        return CompositedTransformFollower(
          link: _editorLink,
          showWhenUnlinked: false,
          offset: Offset.zero,
          child: IgnorePointer(
            ignoring: false, // we want the layer to handle gestures
            child: SizedBox.expand(
              child: NodeDragLayer(
                document: _document,
                editor: _editor,
                documentLayoutKey: _documentLayoutKey,
                handleWidth: kHandleWidth,
                handlePadding: 6,
                handleGap: kHandleGap,
              ),
            ),
          ),
        );
      },
    );

    final overlay = Overlay.of(context, rootOverlay: true);
    overlay!.insert(_dragOverlayEntry!);
  }

  @override
  void dispose() {
    _composer.selectionNotifier.removeListener(_handleSelectionChange);
    _dragOverlayEntry?.remove();
    _editor.dispose();
    _composer.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _handleSelectionChange() {
    final state = _slashMenuState.value;
    if (state is _SlashMenuVisible && _composer.selection?.extent != state.triggerPosition) {
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

  void _applySlashMenuAction(SlashMenuAction action, se.DocumentPosition triggerPosition) {
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
          _editor.execute([se.ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: null)]);
        }
        break;
      case SlashMenuAction.heading1:
        if (node is se.ParagraphNode) {
          _editor.execute([se.ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: se.header1Attribution)]);
        }
        break;
      case SlashMenuAction.heading2:
        if (node is se.ParagraphNode) {
          _editor.execute([se.ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: se.header2Attribution)]);
        }
        break;
      case SlashMenuAction.heading3:
        if (node is se.ParagraphNode) {
          _editor.execute([se.ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: se.header3Attribution)]);
        }
        break;
      case SlashMenuAction.bulletList:
        if (node is se.ParagraphNode) {
          _editor.execute([
            se.ReplaceNodeRequest(existingNodeId: node.id, newNode: se.ListItemNode.unordered(id: node.id, text: node.text)),
          ]);
        }
        break;
      case SlashMenuAction.numberedList:
        if (node is se.ParagraphNode) {
          _editor.execute([
            se.ReplaceNodeRequest(existingNodeId: node.id, newNode: se.ListItemNode.ordered(id: node.id, text: node.text)),
          ]);
        }
        break;
      case SlashMenuAction.toDoList:
        if (node is se.ParagraphNode) {
          _editor.execute([
            se.ReplaceNodeRequest(existingNodeId: node.id, newNode: se.TaskNode(id: node.id, text: node.text, isComplete: false)),
          ]);
        }
        break;
      case SlashMenuAction.divider:
        _editor.execute([se.InsertNodeAtCaretRequest(node: se.HorizontalRuleNode(id: se.Editor.createNodeId()))]);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Left-aligned content column with a max width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth   = constraints.maxWidth;
        final usableWidth = pageWidth - (kPageSidePadding * 2);
        final contentW    = math.min(usableWidth, kContentMaxWidth);
        final leftPad     = kPageSidePadding + kContentLeftInset;
        final rightPad    = (pageWidth - contentW) - leftPad;

        return Stack(
          children: [
            CompositedTransformTarget(
              link: _editorLink,
              child: Padding(
                padding: EdgeInsets.only(left: leftPad, right: rightPad, top: 12, bottom: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentW),
                  child: se.SuperEditor(
                    editor: _editor,
                    documentLayoutKey: _documentLayoutKey,
                    inputSource: se.TextInputSource.keyboard,
                    focusNode: _editorFocusNode,
                    keyboardActions: [
                      _slashCommandKeyboardAction,
                      ...se.defaultKeyboardActions,
                    ],
                  ),
                ),
              ),
            ),

            // Slash menu overlay (local)
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
      },
    );
  }
}

// ---- Slash menu helper state ----
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
