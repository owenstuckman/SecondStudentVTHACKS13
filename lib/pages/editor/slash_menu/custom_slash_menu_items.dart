import 'package:flutter/material.dart';
import 'slash_menu.dart';
import 'slash_menu_action.dart';

class CustomSlashMenuItems {
  List<SlashMenuItemData> get items => const [
    SlashMenuItemData(
      action: SlashMenuAction.addEditNote,
      icon: Icons.sticky_note_2_outlined,
      title: 'Note',
      subtitle: 'Inline note block',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.iframeExcalidraw,
      icon: Icons.draw_outlined,
      title: 'Excalidraw',
      subtitle: 'Embed a room/share link',
    ),
    SlashMenuItemData(
      action: SlashMenuAction.iframeGoogleDoc,
      icon: Icons.description_outlined,
      title: 'Google Doc',
      subtitle: 'Published or /preview link',
    ),
  ];
}
