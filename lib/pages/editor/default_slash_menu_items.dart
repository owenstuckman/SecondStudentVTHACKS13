import 'slash_menu_action.dart';
import 'slash_menu.dart';
import 'package:flutter/material.dart';

class DefaultSlashMeuItems {
  List<SlashMenuItemData> defaultSlashMenuItems = [
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
      action: SlashMenuAction.toDoList,
      icon: Icons.checklist_rtl,
      title: 'To-do list',
      subtitle: 'Track tasks with checkboxes',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.divider,
      icon: Icons.horizontal_rule,
      title: 'Divider',
      subtitle: 'Visual separator',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.addEditNote,
      icon: Icons.edit_note,
      title: 'Edit Note',
      subtitle: 'Visual separator',
    ),
  ];


}
