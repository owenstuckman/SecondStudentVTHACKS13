import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'slash_menu_action.dart';

class SlashMenu extends StatelessWidget {
  const SlashMenu({
    super.key,
    required this.items,
    required this.selectionIndexListenable,
    required this.onSelect,
    required this.onDismiss,
  });

  final List<SlashMenuItemData> items;
  final ValueListenable<int> selectionIndexListenable;
  final ValueChanged<SlashMenuAction> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectionIndexListenable,
      builder: (context, index, _) {
        return Material(
          elevation: 6,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  _SlashMenuItem(
                    data: items[i],
                    isSelected: index == i,
                    onTap: () => onSelect(items[i].action),
                  ),
                _SlashMenuFooter(onDismiss: onDismiss),
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
  });

  final SlashMenuAction action;
  final IconData icon;
  final String title;
  final String subtitle;
}

const List<SlashMenuItemData> defaultSlashMenuItems = [
  SlashMenuItemData(
    action: SlashMenuAction.paragraph,
    icon: Icons.text_fields,
    title: 'Paragraph',
    subtitle: 'Plain text block',
  ),
  SlashMenuItemData(
    action: SlashMenuAction.heading1,
    icon: Icons.looks_one,
    title: 'Heading 1',
    subtitle: 'Large section title',
  ),
  SlashMenuItemData(
    action: SlashMenuAction.heading2,
    icon: Icons.looks_two,
    title: 'Heading 2',
    subtitle: 'Medium section title',
  ),
  SlashMenuItemData(
    action: SlashMenuAction.heading3,
    icon: Icons.looks_3,
    title: 'Heading 3',
    subtitle: 'Small section title',
  ),
  SlashMenuItemData(
    action: SlashMenuAction.bulletList,
    icon: Icons.format_list_bulleted,
    title: 'Bulleted list',
    subtitle: 'Organize ideas with bullets',
  ),
  SlashMenuItemData(
    action: SlashMenuAction.numberedList,
    icon: Icons.format_list_numbered,
    title: 'Numbered list',
    subtitle: 'Steps and ordered lists',
  ),
  SlashMenuItemData(
    action: SlashMenuAction.quote,
    icon: Icons.format_quote,
    title: 'Quote',
    subtitle: 'Highlight key ideas',
  ),
  SlashMenuItemData(
    action: SlashMenuAction.divider,
    icon: Icons.horizontal_rule,
    title: 'Divider',
    subtitle: 'Visual separator',
  ),
];

class _SlashMenuItem extends StatelessWidget {
  const _SlashMenuItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final SlashMenuItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor =
        isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              child: Icon(data.icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
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
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Type '/' on the page",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            child: const Text('esc'),
          ),
        ],
      ),
    );
  }
}
