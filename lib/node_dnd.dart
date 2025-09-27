// lib/node_dnd.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart' as se;

/// Notion-like drag-and-drop layer for Super Editor.
/// Put this ABOVE SuperEditor in a Stack (ideally as the LAST child so it sits on top).
class NodeDragLayer extends StatefulWidget {
  const NodeDragLayer({
    super.key,
    required this.document,
    required this.editor,
    required this.documentLayoutKey,
    this.gutterWidth = 28,
    this.gutterPadding = 6,
    this.handleBuilder,
    this.onReorder,
  });

  final se.MutableDocument document;
  final se.Editor editor;
  final GlobalKey documentLayoutKey;

  /// Fixed left gutter width where the handles live.
  final double gutterWidth;

  /// Padding inside the gutter around each handle.
  final double gutterPadding;

  /// Optional custom handle widget builder.
  final Widget Function(BuildContext, bool isDragging)? handleBuilder;

  /// Callback after reorder: (fromIndex, toIndex).
  final void Function(int from, int to)? onReorder;

  @override
  State<NodeDragLayer> createState() => _NodeDragLayerState();
}

class _NodeDragLayerState extends State<NodeDragLayer> {
  String? _draggingNodeId;
  int? _targetSlot;
  int? _lastSlot;
  _DropDirection _dragDirection = _DropDirection.neutral;
  String? _hoveredNodeId;

  late final se.DocumentChangeListener _docListener;

  @override
  void initState() {
    super.initState();
    _docListener = (se.DocumentChangeLog _) {
      if (mounted) setState(() {});
    };
    widget.document.addListener(_docListener);
  }

  @override
  void didUpdateWidget(NodeDragLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      oldWidget.document.removeListener(_docListener);
      widget.document.addListener(_docListener);
    }
  }

  @override
  void dispose() {
    widget.document.removeListener(_docListener);
    super.dispose();
  }

  se.DocumentLayout? get _layout {
    final state = widget.documentLayoutKey.currentState;
    if (state is se.DocumentLayout) {
      return state as se.DocumentLayout;
    }
    return null;
  }

  /// Rect for a node, in GLOBAL coordinates.
  Rect? _nodeRectGlobal(String nodeId) {
    final layout = _layout;
    if (layout == null) return null;

    final node = widget.document.getNodeById(nodeId);
    if (node == null) return null;

    final pos = node is se.TextNode
        ? const se.TextNodePosition(offset: 0)
        : const se.UpstreamDownstreamNodePosition.upstream();

    try {
      return layout.getRectForPosition(
        se.DocumentPosition(nodeId: nodeId, nodePosition: pos),
      );
    } catch (_) {
      return null;
    }
  }

  List<se.DocumentNode> _allNodes() {
    final out = <se.DocumentNode>[];
    for (int i = 0; i < widget.document.length; i++) {
      final n = widget.document.getNodeAt(i);
      if (n != null) out.add(n);
    }
    return out;
  }

  /// Compute the insertion slot (0..len) for a given GLOBAL y.
  int? _computeInsertionSlot(double globalDy) {
    final layout = _layout;
    if (layout == null) return null;

    final nodes = _allNodes();
    if (nodes.isEmpty) return 0;

    final lanes = <_Lane>[];
    for (final node in nodes) {
      final r = _nodeRectGlobal(node.id);
      if (r != null) lanes.add(_Lane(nodeId: node.id, top: r.top, bottom: r.bottom));
    }
    if (lanes.isEmpty) return null;

    if (globalDy <= lanes.first.top) return 0;
    if (globalDy >= lanes.last.bottom) return lanes.length;

    for (int i = 0; i < lanes.length - 1; i++) {
      final gapTop = lanes[i].bottom;
      final gapBottom = lanes[i + 1].top;
      if (globalDy >= gapTop && globalDy <= gapBottom) {
        return i + 1;
      }
    }

    for (int i = 0; i < lanes.length; i++) {
      final mid = (lanes[i].top + lanes[i].bottom) / 2;
      if (globalDy >= lanes[i].top && globalDy <= lanes[i].bottom) {
        return globalDy < mid ? i : i + 1;
      }
    }
    return null;
  }

  void _onDragStart(String nodeId, int index, double globalDy) {
    final slot = _computeInsertionSlot(globalDy) ?? index;
    setState(() {
      _draggingNodeId = nodeId;
      _targetSlot = slot;
      _lastSlot = slot;
      _dragDirection = _DropDirection.neutral;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_draggingNodeId == null) return;

    final slot = _computeInsertionSlot(details.globalPosition.dy);
    if (slot == null) {
      setState(() {
        _targetSlot = null;
        _dragDirection = _DropDirection.neutral;
      });
      return;
    }

    if (_lastSlot != null) {
      _dragDirection = slot > _lastSlot!
          ? _DropDirection.down
          : slot < _lastSlot!
              ? _DropDirection.up
              : _DropDirection.neutral;
    }
    _lastSlot = slot;

    setState(() => _targetSlot = slot);
  }

  void _onDragEnd() {
    if (_draggingNodeId == null || _targetSlot == null) {
      _resetDrag();
      return;
    }

    final fromIndex = widget.document.getNodeIndexById(_draggingNodeId!);
    var toIndex = _targetSlot!;

    if (toIndex > fromIndex) {
      toIndex -= 1; // removing first shifts the target down by 1
    }

    final maxIndex = widget.document.length - 1;
    if (toIndex != fromIndex && toIndex >= 0 && toIndex <= maxIndex) {
      final node = widget.document.getNodeAt(fromIndex)!;
      widget.editor.execute([
        se.MoveNodeRequest(nodeId: node.id, newIndex: toIndex),
      ]);
      widget.onReorder?.call(fromIndex, toIndex);
    }

    _resetDrag();
  }

  void _resetDrag() {
    setState(() {
      _draggingNodeId = null;
      _targetSlot = null;
      _lastSlot = null;
      _dragDirection = _DropDirection.neutral;
    });
  }

  double? _indicatorYLocal(RenderBox stackBox, List<se.DocumentNode> nodes) {
    if (_targetSlot == null) return null;

    // Slot 0: above first node
    if (_targetSlot == 0 && nodes.isNotEmpty) {
      final r = _nodeRectGlobal(nodes.first.id);
      return r == null ? null : stackBox.globalToLocal(r.topLeft).dy;
    }
    // Slot len: below last node
    if (_targetSlot == nodes.length && nodes.isNotEmpty) {
      final r = _nodeRectGlobal(nodes.last.id);
      return r == null ? null : stackBox.globalToLocal(r.bottomLeft).dy;
    }
    // Between two nodes
    if (_targetSlot! > 0 && _targetSlot! < nodes.length) {
      final above = _nodeRectGlobal(nodes[_targetSlot! - 1].id);
      final below = _nodeRectGlobal(nodes[_targetSlot!].id);
      if (above == null || below == null) return null;
      final midY = (above.bottom + below.top) / 2;
      return stackBox.globalToLocal(Offset(0, midY)).dy;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    if (layout == null) return const SizedBox.shrink();

    final stackBox = context.findRenderObject() as RenderBox?;
    if (stackBox == null) return const SizedBox.shrink();

    final nodes = _allNodes();

    // Left gutter background (optional, subtle)
    final gutter = Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: widget.gutterWidth,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.02),
        ),
      ),
    );

    // Hover regions and gutter cells
    final rowHoverRegions = <Widget>[];
    final gutterCells = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final r = _nodeRectGlobal(node.id);
      if (r == null) continue;

      final topLeftLocal = stackBox.globalToLocal(r.topLeft);
      final bottomLeftLocal = stackBox.globalToLocal(Offset(r.left, r.bottom));
      final height = math.max(24.0, bottomLeftLocal.dy - topLeftLocal.dy);

      // Full-width invisible hover region for this row
      rowHoverRegions.add(Positioned(
        left: 0,
        right: 0,
        top: topLeftLocal.dy,
        height: height,
        child: MouseRegion(
          opaque: false,
          onEnter: (_) => setState(() => _hoveredNodeId = node.id),
          onExit: (_) {
            if (_hoveredNodeId == node.id) {
              setState(() => _hoveredNodeId = null);
            }
          },
          child: const SizedBox.expand(),
        ),
      ));

      // Gutter cell content (handle or line number)
      gutterCells.add(Positioned(
        left: 0,
        top: topLeftLocal.dy,
        width: widget.gutterWidth,
        height: height,
        child: _GutterCell(
          nodeId: node.id,
          index: i,
          padding: widget.gutterPadding,
          isDragging: _draggingNodeId == node.id,
          isHovered: _hoveredNodeId == node.id,
          builder: widget.handleBuilder,
          onDragStart: _onDragStart,
          onDragUpdate: _onDragUpdate,
          onDragEnd: _onDragEnd,
        ),
      ));
    }

    // Drop indicator line
    Widget indicator = const SizedBox.shrink();
    if (_targetSlot != null) {
      final y = _indicatorYLocal(stackBox, nodes);
      if (y != null) {
        indicator = Positioned(
          left: 0,
          right: 0,
          top: y - (_dragDirection == _DropDirection.neutral ? 1 : 2),
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              height: 2,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                boxShadow: _dragDirection == _DropDirection.neutral
                    ? null
                    : [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.30),
                          blurRadius: 6,
                          offset: Offset(0, _dragDirection == _DropDirection.up ? -1 : 1),
                        ),
                      ],
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        gutter,
        // Absorb clicks in the gutter area so the editor below doesn't claim focus.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.gutterWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
          ),
        ),
        // While dragging, capture pointer updates anywhere to continue the drag
        // and prevent the editor from handling clicks.
        if (_draggingNodeId != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: _onDragUpdate,
              onPanEnd: (_) => _onDragEnd(),
            ),
          ),
        indicator,
        ...rowHoverRegions,
        ...gutterCells,
      ],
    );
  }
}

enum _DropDirection { up, down, neutral }

class _Lane {
  _Lane({required this.nodeId, required this.top, required this.bottom});
  final String nodeId;
  final double top;
  final double bottom;
}

class _GutterCell extends StatelessWidget {
  const _GutterCell({
    required this.nodeId,
    required this.index,
    required this.padding,
    required this.isDragging,
    required this.isHovered,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.builder,
  });

  final String nodeId;
  final int index;
  final double padding;
  final bool isDragging;
  final bool isHovered;
  final void Function(String nodeId, int index, double globalDy) onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;
  final Widget Function(BuildContext, bool isDragging)? builder;

  @override
  Widget build(BuildContext context) {
    final handle = builder?.call(context, isDragging) ??
        Container(
          alignment: Alignment.center,
          margin: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isDragging
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: const Icon(Icons.drag_indicator, size: 18),
        );

    final lineNumberText = Text(
      "${index + 1}",
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
      textAlign: TextAlign.right,
    );

    final content = (isHovered || isDragging)
        ? handle
        : Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: lineNumberText,
          );

    return MouseRegion(
      cursor: (isHovered || isDragging) ? SystemMouseCursors.grab : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => onDragStart(nodeId, index, details.globalPosition.dy),
        onPanUpdate: onDragUpdate,
        onPanEnd: (_) => onDragEnd(),
        child: content,
      ),
    );
  }
}