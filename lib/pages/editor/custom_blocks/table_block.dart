// lib/pages/editor/custom_blocks/table_block.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/flutter_quill.dart';

/// ==== Embed payload ==========================================================
/// Stores rows = List<List<String>>, headerRow = bool, colAlign = "left|center|right" per column.
class TableBlockEmbed extends CustomBlockEmbed {
  TableBlockEmbed({
    required List<List<String>> rows,
    bool headerRow = false,
    List<String>? colAlign, // optional alignment per column: left|center|right
  }) : super(
          kType,
          jsonEncode({
            'rows': rows,
            'headerRow': headerRow,
            'colAlign': colAlign,
          }),
        );

  static const String kType = 'table';

  static TableBlockEmbed fromRaw(dynamic raw) {
    Map<String, dynamic> m;
    if (raw is String) {
      m = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } else if (raw is Map<String, dynamic>) {
      m = raw;
    } else {
      m = const {};
    }
    final rows = (m['rows'] as List? ?? [])
        .map<List<String>>((r) => (r as List).map((e) => '$e').toList())
        .toList();
    final header = (m['headerRow'] == true);
    final colAlign = (m['colAlign'] as List?)
        ?.map((e) => (e?.toString() ?? 'left'))
        .toList();

    return TableBlockEmbed(
      rows: rows.isEmpty ? const [[]] : rows,
      headerRow: header,
      colAlign: colAlign,
    );
  }

  Map<String, dynamic> get dataMap {
    try {
      if (data is String) return jsonDecode(data) as Map<String, dynamic>;
      if (data is Map<String, dynamic>) return data as Map<String, dynamic>;
    } catch (_) {}
    return const {'rows': [[]], 'headerRow': false, 'colAlign': null};
  }

  List<List<String>> get rows {
    final r = dataMap['rows'] as List? ?? const [];
    return r.map<List<String>>((row) => (row as List).map((e) => '$e').toList()).toList();
  }

  bool get headerRow => dataMap['headerRow'] == true;

  List<String>? get colAlign {
    final a = dataMap['colAlign'] as List?;
    return a?.map((e) => e?.toString() ?? 'left').toList();
  }
}

/// ==== Builder ================================================================
/// Pass an edit callback so the builder can request edits without knowing about the controller.
class TableEmbedBuilder implements EmbedBuilder {
  const TableEmbedBuilder({this.onEdit});

  final Future<void> Function(
    BuildContext context, {
    required int nodeOffset,
    required List<List<String>> currentRows,
    required bool headerRow,
    required List<String>? colAlign,
  })? onEdit;

  @override
  String get key => TableBlockEmbed.kType;

  @override
  bool get expanded => true;

  @override
  WidgetSpan buildWidgetSpan(Widget child) => WidgetSpan(child: child);

  @override
  String toPlainText(Embed node) {
    final m = TableBlockEmbed.fromRaw(node.value.data);
    final dims = '${m.rows.length}×${(m.rows.isNotEmpty ? m.rows.first.length : 0)}';
    return '[table $dims]';
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final m = TableBlockEmbed.fromRaw(embedContext.node.value.data);
    final rows = m.rows;
    final headerRow = m.headerRow;
    final colAlign = m.colAlign;

    return _TableChrome(
      canEdit: onEdit != null,
      onEditPressed: onEdit == null
          ? null
          : () => onEdit!.call(
                context,
                nodeOffset: embedContext.node.documentOffset,
                currentRows: rows,
                headerRow: headerRow,
                colAlign: colAlign,
              ),
      child: _PrettyTable(
        rows: rows,
        headerRow: headerRow,
        colAlign: colAlign,
        // also route cell double-tap to edit
        onCellEdit: onEdit == null
            ? null
            : () => onEdit!.call(
                  context,
                  nodeOffset: embedContext.node.documentOffset,
                  currentRows: rows,
                  headerRow: headerRow,
                  colAlign: colAlign,
                ),
      ),
    );
  }
}

/// ======= UI Chrome (rounded card + hover toolbar) ============================
class _TableChrome extends StatefulWidget {
  const _TableChrome({
    required this.child,
    required this.canEdit,
    this.onEditPressed,
  });

  final Widget child;
  final bool canEdit;
  final VoidCallback? onEditPressed;

  @override
  State<_TableChrome> createState() => _TableChromeState();
}

class _TableChromeState extends State<_TableChrome> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: widget.child,
            ),
            if (widget.canEdit && _hover)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: scheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: widget.onEditPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Edit',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ======= Nicer table rendering ==============================================
class _PrettyTable extends StatelessWidget {
  const _PrettyTable({
    required this.rows,
    required this.headerRow,
    required this.colAlign,
    this.onCellEdit,
  });

  final List<List<String>> rows;
  final bool headerRow;
  final List<String>? colAlign;
  final VoidCallback? onCellEdit;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty || rows.first.isEmpty) {
      return Center(
        child: Text(
          'Empty table',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cols = rows.first.length;

    final aligns = List<TextAlign>.generate(
      cols,
      (i) => _toAlign(colAlign?[i]),
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Even widths across available content width, with min width per column.
        final contentWidth = constraints.maxWidth;
        final minColWidth = 96.0;
        final target = (contentWidth / cols).clamp(minColWidth, double.infinity);
        final widths = <int, TableColumnWidth>{
          for (int i = 0; i < cols; i++) i: FixedColumnWidth(target),
        };

        final borderColor = scheme.outlineVariant;
        final headerBg = scheme.surfaceContainerHighest;
        final zebra = scheme.surfaceContainerLow;

        final table = Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: borderColor, width: 1),
            verticalInside: BorderSide(color: borderColor, width: 1),
            top: BorderSide(color: borderColor, width: 1),
            bottom: BorderSide(color: borderColor, width: 1),
            left: BorderSide(color: borderColor, width: 1),
            right: BorderSide(color: borderColor, width: 1),
          ),
          columnWidths: widths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (int r = 0; r < rows.length; r++)
              TableRow(
                decoration: (headerRow && r == 0)
                    ? BoxDecoration(color: headerBg)
                    : (r.isEven && headerRow ? null : BoxDecoration(color: zebra.withValues(alpha: 0.25))),
                children: [
                  for (int c = 0; c < cols; c++)
                    _PrettyCell(
                      text: rows[r][c],
                      align: aligns[c],
                      isHeader: headerRow && r == 0,
                      textTheme: textTheme,
                      onDoubleTap: onCellEdit, // double-tap any cell -> edit
                    ),
                ],
              ),
          ],
        );

        // Make the entire table clickable to edit (if allowed)
        return GestureDetector(
          onTap: onCellEdit,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: table,
          ),
        );
      },
    );
  }

  TextAlign _toAlign(String? a) {
    switch (a) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }
}

class _PrettyCell extends StatelessWidget {
  const _PrettyCell({
    required this.text,
    required this.align,
    required this.isHeader,
    required this.textTheme,
    this.onDoubleTap,
  });

  final String text;
  final TextAlign align;
  final bool isHeader;
  final TextTheme textTheme;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1)
        : textTheme.bodyMedium;

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Text(
          text,
          textAlign: align,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
          style: style,
        ),
      ),
    );
  }
}
