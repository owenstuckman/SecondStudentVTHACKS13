import 'package:flutter/material.dart';
import 'slash_menu.dart';
import 'slash_menu_action.dart';

class DefaultSlashMeuItems {
  List<SlashMenuItemData> get defaultSlashMenuItems => const [
    SlashMenuItemData(
      action: SlashMenuAction.paragraph,
      icon: Icons.text_fields,
      title: 'Paragraph',
      subtitle: 'Normal text',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.heading1,
      icon: Icons.title,
      title: 'Heading 1',
      subtitle: 'Large title',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.heading2,
      icon: Icons.title,
      title: 'Heading 2',
      subtitle: 'Section title',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.heading3,
      icon: Icons.title,
      title: 'Heading 3',
      subtitle: 'Subsection',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.codeBlock,
      icon: Icons.code,
      title: 'Code block',
      subtitle: 'Monospace section',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.bulletList,
      icon: Icons.format_list_bulleted,
      title: 'Bulleted list',
      subtitle: '• Itemized list',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.numberedList,
      icon: Icons.format_list_numbered,
      title: 'Numbered list',
      subtitle: '1. 2. 3.',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.toDoList,
      icon: Icons.check_box_outlined,
      title: 'To-do list',
      subtitle: 'Checkbox items',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.divider,
      icon: Icons.horizontal_rule,
      title: 'Divider',
      subtitle: 'Horizontal rule',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.image,
      icon: Icons.image_outlined,
      title: 'Image',
      subtitle: 'Paste an image URL',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.video,
      icon: Icons.ondemand_video_outlined,
      title: 'Video',
      subtitle: 'YouTube/Vimeo URL',
    ),
  ];
}
