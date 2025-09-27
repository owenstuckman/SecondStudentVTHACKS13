import 'package:flutter/material.dart';
import 'slash_menu.dart';
import 'slash_menu_action.dart';

import 'package:secondstudent/globals/database.dart';

class CustomSlashMenuItems {
  List<SlashMenuItemData> _items = [
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
    _updateItems(callback); // Run async function to update items
  }

  // Method to add a new item
  void addItem(SlashMenuItemData item) {
    _items.add(item);
  }
}
