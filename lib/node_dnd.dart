// lib/node_dnd.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart' as se;

/// Drag-to-reorder handles for Super Editor.
/// You mount this in a root Overlay (you're already doing that in editor.dart).
class NodeDragLayer extends StatefulWidget {
  const NodeDragLayer({
    super.key,
    required this.document,
    required this.editor,
    required this.documentLayoutKey,
    this.handleWidth = 28,
    this.handlePadding = 6,
    this.handleGap = 8, // gap between node's left edge and the handle
    this.handleBuilder,
    this.onReorder,
  });

  final se.MutableDocument document;
  final se.Editor editor;
  final GlobalKey documentLayoutKey;

  final double handleWidth;
  final double handlePadding;
  final double handleGap;

  final Widget Function(BuildContext, bool isDragging)? handleBuilder;
  final void Function(int from, int to)? onReorder;

  @override
  State<NodeDragLayer> createState() => _NodeDragLayerState();
}

class _NodeDragLayerState extends State<NodeDragLayer> {
  String? _draggingNodeId;
  int? _targetSlot;
  int? _lastSlot;
  _DropDirection _dragDirection = _DropDirection.neutral;

  late final se.DocumentChangeListener _docListener;

  @override
  void initState() {
    super.initState();
    _docListener = (se.DocumentChangeLog _) {
      if (mounted) setState(() {}); // repaint when the doc changes
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

  /// Rect for a node in **global** coordinates, using the node's upstream (or text 0) position.
  Rect? _nodeRectGlobal(String nodeId) {
    final layout = _layout;
    if (layout == null) return null;

    final node = widget.document.getNodeById(nodeId);
    if (node == null) return null;

    final pos = node is se.TextNode
        ? const se.TextNodePosition(offset: 0)
        : const se.UpstreamDownstreamNodePosition.upstream();

    final localRect = layout.getRectForPosition(
      se.DocumentPosition(nodeId: nodeId, nodePosition: pos),
    );
    if (localRect == null) return null;

    // Convert from document layout space -> global.
    final tl = layout.getGlobalOffsetFromDocumentOffset(localRect.topLeft);
    final br = layout.getGlobalOffsetFromDocumentOffset(localRect.bottomRight);
    return Rect.fromPoints(tl, br);
  }

  List<se.DocumentNode> _allNodes() {
    final out = <se.DocumentNode>[];
    for (int i = 0; i < widget.document.length; i++) {
      final n = widget.document.getNodeAt(i);
      if (n != null) out.add(n);
    }
    return out;
  }

  /// Slot (0..len) where the drop line should appear for a given **global** Y.
  int? _computeInsertionSlot(double globalDy) {
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
      toIndex -= 1; // remove-then-insert shift
    }

    final maxIndex = widget.document.length - 1;
    if (toIndex != fromIndex && toIndex >= 0 && toIndex <= maxIndex) {
      final node = widget.document.getNodeAt(fromIndex)!;
      widget.editor.execute([se.MoveNodeRequest(nodeId: node.id, newIndex: toIndex)]);
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

    if (_targetSlot == 0 && nodes.isNotEmpty) {
      final r = _nodeRectGlobal(nodes.first.id);
      return r == null ? null : stackBox.globalToLocal(r.topLeft).dy;
    }
    if (_targetSlot == nodes.length && nodes.isNotEmpty) {
      final r = _nodeRectGlobal(nodes.last.id);
      return r == null ? null : stackBox.globalToLocal(r.bottomLeft).dy;
    }
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

    // Per-node handles, positioned beside each node's left edge.
    final handles = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final r = _nodeRectGlobal(node.id);
      if (r == null) continue;

      final topLeftLocal = stackBox.globalToLocal(r.topLeft);
      final bottomLeftLocal = stackBox.globalToLocal(Offset(r.left, r.bottom));

      final top = topLeftLocal.dy;
      final height = math.max(24.0, bottomLeftLocal.dy - topLeftLocal.dy);

      // Place the handle just to the LEFT of this node's left edge.
      final handleLeft = (topLeftLocal.dx - widget.handleGap - widget.handleWidth).clamp(0.0, double.infinity);

      handles.add(Positioned(
        left: handleLeft,
        top: top,
        width: widget.handleWidth,
        height: height,
        child: _Handle(
          nodeId: node.id,
          index: i,
          padding: widget.handlePadding,
          isDragging: _draggingNodeId == node.id,
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

    // While dragging, capture movement anywhere so the editor doesn’t steal gestures.
    final dragCapture = (_draggingNodeId != null)
        ? Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: _onDragUpdate,
              onPanEnd: (_) => _onDragEnd(),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (_) => _onDragEnd(),
            builder: (context, _, __) => const SizedBox.expand(),
          ),
        ),
        indicator,
        ...handles,
        dragCapture,
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

class _Handle extends StatelessWidget {
  const _Handle({
    required this.nodeId,
    required this.index,
    required this.padding,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.builder,
  });

  final String nodeId;
  final int index;
  final double padding;
  final bool isDragging;
  final void Function(String nodeId, int index, double globalDy) onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;
  final Widget Function(BuildContext, bool isDragging)? builder;

  @override
  Widget build(BuildContext context) {
    final child = builder?.call(context, isDragging) ??
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

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => onDragStart(nodeId, index, details.globalPosition.dy),
        onPanUpdate: onDragUpdate,
        onPanEnd: (_) => onDragEnd(),
        child: child,
      ),
    );
  }
}
