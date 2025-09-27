// lib/node_dnd.dart
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/super_editor.dart' as se;

/// Notion-like drag-to-reorder layer for Super Editor.
/// Mount this in a root Overlay and anchor it with a CompositedTransformFollower.
class NodeDragLayer extends StatefulWidget {
  const NodeDragLayer({
    super.key,
    required this.document,
    required this.editor,
    required this.documentLayoutKey,
    this.handleWidth = 36, // visual width of handle
    this.handlePadding = 8, // inner padding
    this.handleGap = 6, // gap between node left edge and handle
    this.handleBuilder,
    this.onReorder,
    this.autoscrollEdgePx = 56,
    this.autoscrollMaxSpeed = 22,
    this.showLineNumbers = true,
    this.lineNumberWidth = 28,
  });

  final se.MutableDocument document;
  final se.Editor editor;
  final GlobalKey documentLayoutKey;

  final double handleWidth;
  final double handlePadding;
  final double handleGap;

  final Widget Function(BuildContext, bool isDragging)? handleBuilder;
  final void Function(int from, int to)? onReorder;

  /// Pixels from top/bottom where we start autoscrolling.
  final double autoscrollEdgePx;

  /// Max autoscroll speed in px per frame (roughly).
  final double autoscrollMaxSpeed;

  /// Whether to display a left-aligned line number gutter.
  final bool showLineNumbers;

  /// Fixed width for the line number gutter.
  final double lineNumberWidth;

  @override
  State<NodeDragLayer> createState() => _NodeDragLayerState();
}

class _NodeDragLayerState extends State<NodeDragLayer>
    with SingleTickerProviderStateMixin {
  String? _draggingNodeId;
  int? _targetSlot;
  int? _lastSlot;

  // Live cursor y (global), used to place the indicator smoothly.
  double? _cursorGlobalDy;

  // Cached lane list (recomputed frequently during drag).
  List<_Lane> _lanes = const [];

  // Animated indicator Y (local to our Stack).
  late final AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;
  double? _indicatorTargetY;

  // Simple autoscroll
  ScrollPosition? _scrollPos;
  double _autoscrollVelocity = 0;
  bool _autoscrolling = false;

  @override
  void initState() {
    super.initState();

    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _indicatorAnim = _indicatorCtrl.drive(
      Tween(begin: 0.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
    );

    // Rebuild lanes whenever the document changes.
    widget.document.addListener(_onDocumentChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachScrollable();
      _rebuildLanes();
      setState(() {});
    });
  }

  void _attachScrollable() {
    // Best-effort: find the nearest scrollable where SuperEditor sits.
    _scrollPos = Scrollable.of(context).position;
  }

  void _onDocumentChange(se.DocumentChangeLog _) {
    if (!mounted) return;
    _rebuildLanes();
    setState(() {});
  }

  @override
  void didUpdateWidget(NodeDragLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      oldWidget.document.removeListener(_onDocumentChange);
      widget.document.addListener(_onDocumentChange);
      _rebuildLanes();
    }
  }

  @override
  void dispose() {
    widget.document.removeListener(_onDocumentChange);
    _indicatorCtrl.dispose();
    super.dispose();
  }

  se.DocumentLayout? get _layout {
    final state = widget.documentLayoutKey.currentState;
    if (state is se.DocumentLayout) {
      return state as se.DocumentLayout;
    }
    return null;
  }

  List<se.DocumentNode> _allNodes() {
    final out = <se.DocumentNode>[];
    for (int i = 0; i < widget.document.length; i++) {
      final n = widget.document.getNodeAt(i);
      if (n != null) out.add(n);
    }
    return out;
  }

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

    final tl = layout.getGlobalOffsetFromDocumentOffset(localRect.topLeft);
    final br = layout.getGlobalOffsetFromDocumentOffset(localRect.bottomRight);
    return Rect.fromPoints(tl, br);
  }

  void _rebuildLanes() {
    final nodes = _allNodes();
    final lanes = <_Lane>[];
    for (final node in nodes) {
      final r = _nodeRectGlobal(node.id);
      if (r != null) {
        lanes.add(
          _Lane(nodeId: node.id, top: r.top, bottom: r.bottom, left: r.left),
        );
      }
    }
    _lanes = lanes;
  }

  // Find drop slot by dy (global) using binary search + midpoint rule.
  int? _slotForDy(double dy) {
    if (_lanes.isEmpty) return 0;
    if (dy <= _lanes.first.top) return 0;
    if (dy >= _lanes.last.bottom) return _lanes.length;

    int lo = 0, hi = _lanes.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final lane = _lanes[mid];
      if (dy < lane.top) {
        hi = mid - 1;
      } else if (dy > lane.bottom) {
        lo = mid + 1;
      } else {
        final m = (lane.top + lane.bottom) / 2;
        return dy < m ? mid : mid + 1;
      }
    }
    return lo;
  }

  void _startDrag(String nodeId, int index, double globalDy) {
    if (_lanes.isEmpty) _rebuildLanes();
    final slot = _slotForDy(globalDy) ?? index;
    _cursorGlobalDy = globalDy;
    _updateIndicatorTargetForSlot(slot);
    setState(() {
      _draggingNodeId = nodeId;
      _targetSlot = slot;
      _lastSlot = slot;
    });
  }

  void _updateIndicatorTargetForSlot(int slot) {
    final stackBox = context.findRenderObject() as RenderBox?;
    if (stackBox == null || _lanes.isEmpty) return;

    double y;
    if (slot == 0) {
      y = stackBox.globalToLocal(Offset(0, _lanes.first.top)).dy;
    } else if (slot == _lanes.length) {
      y = stackBox.globalToLocal(Offset(0, _lanes.last.bottom)).dy;
    } else {
      final above = _lanes[slot - 1];
      final below = _lanes[slot];
      y = stackBox.globalToLocal(Offset(0, (above.bottom + below.top) / 2)).dy;
    }

    // Animate the indicator toward the new target for a “snap while following” feel.
    final begin = (_indicatorAnim.value);
    _indicatorAnim = _indicatorCtrl.drive(
      Tween<double>(
        begin: begin,
        end: y,
      ).chain(CurveTween(curve: Curves.easeOut)),
    );
    _indicatorCtrl
      ..value = 0
      ..forward();
    _indicatorTargetY = y;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_draggingNodeId == null) return;

    _cursorGlobalDy = e.position.dy;

    // Rebuild lanes every move to avoid misalignment when layout changes.
    _rebuildLanes();

    final slot = _slotForDy(_cursorGlobalDy!);
    if (slot == null) return;

    if (_targetSlot != slot) {
      _updateIndicatorTargetForSlot(slot);
      _lastSlot = _targetSlot;
      _targetSlot = slot;
      setState(() {});
    }

    _maybeAutoscroll(e.position);
  }

  void _onPointerUpCancel() {
    if (_draggingNodeId == null) return;
    _finishDrag();
  }

  void _finishDrag() {
    final nodeId = _draggingNodeId;
    final slot = _targetSlot;
    _stopAutoscroll();

    if (nodeId == null || slot == null) {
      _resetDrag();
      return;
    }

    final fromIndex = widget.document.getNodeIndexById(nodeId);
    var toIndex = slot;

    if (toIndex > fromIndex) {
      toIndex -= 1; // remove-then-insert shift
    }

    final maxIndex = widget.document.length - 1;
    if (toIndex != fromIndex && toIndex >= 0 && toIndex <= maxIndex) {
      final node = widget.document.getNodeAt(fromIndex)!;
      widget.editor.execute([
        se.MoveNodeRequest(nodeId: node.id, newIndex: toIndex),
      ]);
      widget.onReorder?.call(fromIndex, toIndex);
    }

    // After the move, layout shifts. Rebuild lanes on the next frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rebuildLanes();
      setState(() {});
    });

    _resetDrag();
  }

  void _resetDrag() {
    setState(() {
      _draggingNodeId = null;
      _targetSlot = null;
      _lastSlot = null;
      _cursorGlobalDy = null;
      _indicatorTargetY = null;
    });
  }

  // --- Autoscroll while dragging near edges ---
  void _maybeAutoscroll(Offset globalPos) {
    final rb = context.findRenderObject() as RenderBox?;
    if (rb == null || _scrollPos == null) return;
    final local = rb.globalToLocal(globalPos);
    final size = rb.size;

    double v = 0;
    if (local.dy < widget.autoscrollEdgePx) {
      final t =
          (widget.autoscrollEdgePx - local.dy) /
          widget.autoscrollEdgePx; // 0..1
      v = -widget.autoscrollMaxSpeed * t;
    } else if (local.dy > size.height - widget.autoscrollEdgePx) {
      final t =
          (local.dy - (size.height - widget.autoscrollEdgePx)) /
          widget.autoscrollEdgePx;
      v = widget.autoscrollMaxSpeed * t;
    }

    if (v == 0) {
      _stopAutoscroll();
      return;
    }

    _autoscrollVelocity = v;
    if (!_autoscrolling) {
      _autoscrolling = true;
      _tickAutoscroll();
    }
  }

  void _stopAutoscroll() {
    _autoscrolling = false;
    _autoscrollVelocity = 0;
  }

  void _tickAutoscroll() {
    if (!_autoscrolling || _scrollPos == null) return;
    _scrollPos!.jumpTo(
      (_scrollPos!.pixels + _autoscrollVelocity).clamp(
        _scrollPos!.minScrollExtent,
        _scrollPos!.maxScrollExtent,
      ),
    );
    // Recompute lanes after scroll so indicator/handles stay aligned.
    _rebuildLanes();
    if (_cursorGlobalDy != null) {
      final slot = _slotForDy(_cursorGlobalDy!);
      if (slot != null && _targetSlot != slot) {
        _updateIndicatorTargetForSlot(slot);
        _targetSlot = slot;
      }
    }
    // Schedule next frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _autoscrolling) _tickAutoscroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    if (layout == null) return const SizedBox.shrink();

    final stackBox = context.findRenderObject() as RenderBox?;
    if (stackBox == null) return const SizedBox.shrink();

    // Optional: line numbers, left-aligned at x = 0.
    final lineNumbers = <Widget>[];
    if (widget.showLineNumbers) {
      for (var i = 0; i < _lanes.length; i++) {
        final lane = _lanes[i];
        final topLeftLocal = stackBox.globalToLocal(Offset(0, lane.top));
        final bottomLeftLocal = stackBox.globalToLocal(Offset(0, lane.bottom));
        final height = math.max(20.0, bottomLeftLocal.dy - topLeftLocal.dy);

        lineNumbers.add(
          Positioned(
            left: 0,
            top: topLeftLocal.dy,
            width: widget.lineNumberWidth,
            height: height,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  "${i + 1}",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Build handles beside each lane.
    final handles = <Widget>[];
    for (var i = 0; i < _lanes.length; i++) {
      final lane = _lanes[i];

      final topLeftLocal = stackBox.globalToLocal(Offset(lane.left, lane.top));
      final bottomLeftLocal = stackBox.globalToLocal(
        Offset(lane.left, lane.bottom),
      );
      final height = math.max(34.0, bottomLeftLocal.dy - topLeftLocal.dy);

      final handleLeft = (topLeftLocal.dx - widget.handleGap - widget.handleWidth)
          .clamp(widget.lineNumberWidth + 4, double.infinity);

      handles.add(
        Positioned(
          left: handleLeft,
          top: topLeftLocal.dy,
          width: widget.handleWidth,
          height: height,
          child: _Handle(
            nodeId: lane.nodeId,
            index: i,
            padding: widget.handlePadding,
            isDragging: _draggingNodeId == lane.nodeId,
            builder: widget.handleBuilder,
            onStart: _startDrag,
          ),
        ),
      );
    }

    // Indicator line (animated). If no animation target yet, hide it.
    final indicator = (_indicatorTargetY != null)
        ? AnimatedBuilder(
            animation: _indicatorCtrl,
            builder: (context, _) {
              final y = _indicatorAnim.value;
              return Positioned(
                left: 0,
                right: 0,
                top: y - 1,
                child: IgnorePointer(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      boxShadow: const [
                        BoxShadow(blurRadius: 6, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        : const SizedBox.shrink();

    // Global pointer listener while dragging for buttery updates.
    final globalPointerLayer = (_draggingNodeId != null)
        ? Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerMove: _onPointerMove,
              onPointerUp: (_) => _onPointerUpCancel(),
              onPointerCancel: (_) => _onPointerUpCancel(),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // allow drop anywhere
        Positioned.fill(
          child: DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (_) => _finishDrag(),
            builder: (context, _, __) => const SizedBox.expand(),
          ),
        ),
        indicator,
        ...lineNumbers,
        ...handles,
        globalPointerLayer,
      ],
    );
  }
}

class _Lane {
  _Lane({
    required this.nodeId,
    required this.top,
    required this.bottom,
    required this.left,
  });
  final String nodeId;
  final double top;
  final double bottom;
  final double left;
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.nodeId,
    required this.index,
    required this.padding,
    required this.isDragging,
    required this.onStart,
    this.builder,
  });

  final String nodeId;
  final int index;
  final double padding;
  final bool isDragging;
  final void Function(String nodeId, int index, double globalDy) onStart;
  final Widget Function(BuildContext, bool isDragging)? builder;

  @override
  Widget build(BuildContext context) {
    final child =
        builder?.call(context, isDragging) ??
        Container(
          alignment: Alignment.center,
          margin: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isDragging
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: const Icon(Icons.drag_indicator, size: 20),
        );

    // Immediate drag with large hit target
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => onStart(nodeId, index, d.globalPosition.dy),
        child: child,
      ),
    );
  }
}
