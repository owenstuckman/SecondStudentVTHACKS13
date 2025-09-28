import 'package:flutter/material.dart';
import 'slash_menu.dart';
import 'slash_menu_action.dart';

import 'package:secondstudent/globals/database.dart';

class CustomSlashMenuItems {
  final List<SlashMenuItemData> _items = [
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
      subtitle: 'New drawing or room/share link',
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
    ),
    SlashMenuItemData(
      action: SlashMenuAction.table,
      icon: Icons.table_chart_outlined,
      title: 'Table',
      subtitle: 'Table block',
    ),

  ];

  // Getter for items
  List<SlashMenuItemData> get items => _items;

  // Method to update items asynchronously
  void _updateItems(Function callback) {
    supabase.from('blocks').select().then((res) {
      if (res != null) {
        for (var row in res) {
          // Assuming row contains the necessary fields to create a SlashMenuItemData
          _items.add(SlashMenuItemData(
            action: SlashMenuAction.values[row['exec']], // Adjust based on your action mapping
            icon: (row['icon']), // Replace with appropriate icon based on your data
            title: row['name'] ?? 'Untitled', // Default title if none provided
            subtitle: row['description'] ?? '', // Default subtitle if none provided
          ));
        }
      }
      callback(); // Call the callback function to trigger setState
    });
  }

  // Method to retrieve the items and trigger update
  void fetchItems(Function callback) {
    _updateItems(() {
      callback(); // Call the callback function after items are updated
    });
  }

  // Method to add a new item
  void addItem(SlashMenuItemData item) {
    _items.add(item);
  }
}