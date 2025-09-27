import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:filesystem_picker/filesystem_picker.dart'; // Use filesystem_picker package
import 'dart:io'; // Import dart:io to use Directory

class FileStorage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Folder Selector'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Open folder picker
            String? path = await FilesystemPicker.open(
              context: context,
              title: 'Select a Folder',
              allowedExtensions: null, // Allow all types
              rootDirectory: Directory('/'), // Start from root
              fsType: FilesystemType.folder, // Specify folder type
              showGoUp: true, // Show option to go up
            );

            if (path != null) {
              // Save the path to local storage
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('path_to_files', path);

              // Show a confirmation message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Folder path saved: $path')),
              );
            }
          },
          child: Text(
            'Please Select a Folder',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
