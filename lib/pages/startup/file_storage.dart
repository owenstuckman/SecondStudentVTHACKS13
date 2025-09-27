import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'dart:io';

import 'package:secondstudent/pages/startup/home_page.dart';

/*

Works to select a root location for where files will be stored
 - DOES NOT WORK FOR WEB 
 - potential package: https://pub.dev/packages/flutter_dropzone

*/

class FileStorage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _folderSelectorWidget(context);
  }

  Widget _folderSelectorWidget(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Folder Selector')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FutureBuilder<String?>(
              future: _getSavedPath(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasData && snapshot.data != null) {
                  return Text('Current File Location: ${snapshot.data}', style: TextStyle(fontSize: 18));
                } else {
                  return Text('No folder selected', style: TextStyle(fontSize: 18));
                }
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
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

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => HomePage()),
                    (route) => false,
                  );
                }
              },
              child: Text('Please Select a Folder', style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('path_to_files');
  }
}
