import 'package:flutter/material.dart';
import 'slash_menu.dart';
import 'slash_menu_action.dart';

class CustomSlashMenuItems {
  List<SlashMenuItemData> get items => const [
    // SlashMenuItemData(
    //   action: SlashMenuAction.addEditNote,
    //   icon: Icons.sticky_note_2_outlined,
    //   title: 'Note',
    //   subtitle: 'Inline note block',
    // ),
    SlashMenuItemData(
      action: SlashMenuAction.pageLink,
      icon: Icons.link_outlined,
      title: 'Page link',
      subtitle: 'Link to another JSON page',
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
    SlashMenuItemData(
      action: SlashMenuAction.embedPdf,
      icon: Icons.picture_as_pdf_outlined,
      title: 'PDF',
      subtitle: 'PDF URL, data: URI, or assets/path.pdf',
    )
  ];
}
