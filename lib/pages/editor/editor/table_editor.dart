import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:secondstudent/pages/editor/custom_blocks/table_block.dart';

Future<void> editTableBlock(
  BuildContext context, {
  required quill.QuillController controller,
  required int nodeOffset,
  required List<List<String>> currentRows,
  required bool headerRow,
  required List<String>? colAlign,
}) async {
  // Make a safe, mutable copy
  final rows = currentRows.map((r) => r.toList()).toList();
  bool isHeader = headerRow;
  List<String>? alignment = (colAlign == null) ? null : List<String>.from(colAlign);

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit Table',
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final colCount = rows.isNotEmpty ? rows.first.length : 0;
      alignment ??= List.filled(colCount, 'left');

      return StatefulBuilder(
        builder: (ctx, setState) => Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Semi-transparent overlay
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.black26),
                ),
              ),
              // Positioned dialog over the editor area (right side)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.3, // Start after sidebar
                top: MediaQuery.of(context).size.height * 0.2, // Offset from top
                child: Material(
                  type: MaterialType.card,
                  elevation: 12,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Edit Table', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Column(
                      children: [
              Row(
                children: [
                  const Text('Header row'),
                  const SizedBox(width: 8),
                  Switch(
                    value: isHeader,
                    onChanged: (v) => setState(() => isHeader = v),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Add row',
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        if (rows.isEmpty) {
                          rows.add(['']);
                        } else {
                          rows.add(List.filled(rows.first.length, ''));
                        }
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'Add column',
                    icon: const Icon(Icons.view_column),
                    onPressed: () {
                      setState(() {
                        if (rows.isEmpty) {
                          rows.add(['']);
                        } else {
                          for (final r in rows) {
                            r.add('');
                          }
                        }
                        alignment!.add('left');
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Quick & dirty grid editor
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Alignment row
                      if (rows.isNotEmpty)
                        Row(
                          children: [
                            for (int c = 0; c < rows.first.length; c++)
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: alignment![c],
                                  items: const [
                                    DropdownMenuItem(value: 'left', child: Text('Left')),
                                    DropdownMenuItem(value: 'center', child: Text('Center')),
                                    DropdownMenuItem(value: 'right', child: Text('Right')),
                                  ],
                                  onChanged: (v) => setState(() => alignment![c] = v ?? 'left'),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: 'Col ${c + 1}',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      for (int r = 0; r < rows.length; r++)
                        Row(
                          children: [
                            for (int c = 0; c < rows[r].length; c++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: TextFormField(
                                    initialValue: rows[r][c],
                                    onChanged: (v) => rows[r][c] = v,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'R${r + 1}C${c + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Delete row',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() => rows.removeAt(r)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final newEmbed = TableBlockEmbed(
                            rows: rows,
                            headerRow: isHeader,
                            colAlign: alignment,
                          );
                          // Replace the table embed at the specific node offset
                          controller.replaceText(
                            nodeOffset,
                            1,
                            quill.BlockEmbed.custom(newEmbed),
                            TextSelection.collapsed(offset: nodeOffset + 1),
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ))],
        ),
      ));
    },
  );
}
