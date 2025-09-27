import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'slash_menu_action.dart';

class SlashMenu extends StatefulWidget {
  const SlashMenu({
    super.key,
    required this.items,
    required this.selectionIndexListenable,
    required this.onSelect,
    required this.onDismiss,
    this.maxWidth = defaultSlashMenuMaxWidth,
    this.rowHeight = defaultSlashMenuRowHeight,
    this.footerHeight = defaultSlashMenuFooterHeight,
    this.maxVisibleRows = defaultSlashMenuMaxVisibleRows,
  });

  final List<SlashMenuItemData> items;
  final ValueListenable<int> selectionIndexListenable;
  final ValueChanged<SlashMenuAction> onSelect;
  final VoidCallback onDismiss;
  final double maxWidth;
  final double rowHeight;
  final double footerHeight;
  final int maxVisibleRows;

  double get estimatedHeight =>
      (items.length.clamp(0, maxVisibleRows) * rowHeight) + footerHeight;

  @override
  State<SlashMenu> createState() => _SlashMenuState();
}

class _SlashMenuState extends State<SlashMenu> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.selectionIndexListenable.addListener(_onSelectionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureSelectedVisible(widget.selectionIndexListenable.value);
      }
    });
  }

  @override
  void didUpdateWidget(SlashMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionIndexListenable != widget.selectionIndexListenable) {
      oldWidget.selectionIndexListenable.removeListener(_onSelectionChanged);
      widget.selectionIndexListenable.addListener(_onSelectionChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureSelectedVisible(widget.selectionIndexListenable.value);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.selectionIndexListenable.removeListener(_onSelectionChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (!mounted) {
      return;
    }
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureSelectedVisible(widget.selectionIndexListenable.value);
        }
      });
      return;
    }
    _ensureSelectedVisible(widget.selectionIndexListenable.value);
  }

  void _ensureSelectedVisible(int index) {
    if (!_scrollController.hasClients) {
      return;
    }

    final double itemTop = index * widget.rowHeight;
    final double itemBottom = itemTop + widget.rowHeight;
    final double viewportTop = _scrollController.offset;
    final double viewportBottom =
        viewportTop + _scrollController.position.viewportDimension;

    double? targetOffset;
    if (itemTop < viewportTop) {
      targetOffset = itemTop;
    } else if (itemBottom > viewportBottom) {
      targetOffset = itemBottom - _scrollController.position.viewportDimension;
    }

    if (targetOffset == null) {
      return;
    }

    final minExtent = _scrollController.position.minScrollExtent;
    final maxExtent = _scrollController.position.maxScrollExtent;
    targetOffset = targetOffset.clamp(minExtent, maxExtent);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxListHeight = widget.rowHeight * widget.maxVisibleRows;

    return ValueListenableBuilder<int>(
      valueListenable: widget.selectionIndexListenable,
      builder: (context, index, _) {
        return Material(
          elevation: 6,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxListHeight,
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility:
                        widget.items.length > widget.maxVisibleRows,
                    child: ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: widget.items.length,
                      itemBuilder: (context, i) {
                        return _SlashMenuItem(
                          data: widget.items[i],
                          isSelected: index == i,
                          onTap: () => widget.onSelect(widget.items[i].action),
                          height: widget.rowHeight,
                        );
                      },
                    ),
                  ),
                ),
                _SlashMenuFooter(
                  height: widget.footerHeight,
                  onDismiss: widget.onDismiss,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SlashMenuItemData {
  const SlashMenuItemData({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLabel = false,
    this.isSeparator = false, 
  });

  const SlashMenuItemData.separator()
      : action = SlashMenuAction.paragraph,
        icon = Icons.more_horiz,
        title = '',
        subtitle = '',
        isLabel = false,
        isSeparator = true;

  final SlashMenuAction action;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLabel; // non-selectable header row
  final bool isSeparator; // separator row
}

class _SlashMenuItem extends StatelessWidget {
  const _SlashMenuItem({
    required this.data,
    required this.isSelected,
    required this.height,
    required this.onTap,
  });

  final SlashMenuItemData data;
  final bool isSelected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = '${data.title}  •  ${data.subtitle}';

    if (data.isSeparator) {
      return const Padding(                    // 👈 render the divider
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Divider(height: 1),
      );
    }
    
    if (data.isLabel) {
      return Container(
        height: height,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          data.title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.secondaryContainer,
              ),
              child: Icon(data.icon, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlashMenuFooter extends StatelessWidget {
  const _SlashMenuFooter({
    required this.height,
    required this.onDismiss,
  });

  final double height;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              "Type '/' on the page",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('esc', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

const double defaultSlashMenuRowHeight = 44;
const double defaultSlashMenuFooterHeight = 34;
const double defaultSlashMenuMaxWidth = 240;
const int defaultSlashMenuMaxVisibleRows = 6;

double slashMenuTotalHeight(
  int itemCount, {
  double rowHeight = defaultSlashMenuRowHeight,
  double footerHeight = defaultSlashMenuFooterHeight,
  int maxVisibleRows = defaultSlashMenuMaxVisibleRows,
}) {
  return itemCount.clamp(0, maxVisibleRows) * rowHeight + footerHeight;
}
