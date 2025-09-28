import 'package:flutter/material.dart';
import 'package:secondstudent/globals/database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class Sync {
  Future<void> syncFile(String filePath) async {
    final ts = DateTime.now();
    final file = File('$filePath.json');

    // Read the file content as a string
    final jsonData = await file.readAsString();
    String uuid = (await supabase.auth.getUser()).user?.id ?? '';

    // Upsert the document in Supabase
    await supabase.from('documents').upsert({
      "title": filePath, // Use filePath instead of file object
      "snapshot": jsonData,
      "updated_at": ts,
      "created_by": uuid
    });
  }

  Future<void> syncAllFiles(String rootDir) async {
    final ts = DateTime.now().toIso8601String();
    final directory = Directory(rootDir);
    final files = directory.listSync(recursive: true);

    String uuid = (await supabase.auth.getUser()).user?.id ?? '';

    for (var fileEntity in files) {
      if (fileEntity is File) {
        final filePath = fileEntity.path;
        final fileExtension = filePath
            .split('.')
            .last; // Get the file extension
        final jsonData = await fileEntity
            .readAsString(); // Read the file content as a string

        if (fileExtension == 'json') {
          await supabase.from('documents').upsert({
            "title": filePath,
            "snapshot": jsonData.toString(),
            "updated_at": ts,
            "vault": rootDir,
            "created_by": uuid
          });
        } else {
          // Upload the non-JSON file to Supabase storage
          await supabase.storage
              .from('userfiles')
              .upload(fileEntity.uri.pathSegments.last, fileEntity);
        }
      }
    }
    await syncDown(rootDir);
  }

  Future<void> syncDown(String rootDir) async {
    // Instead of uploading the non-JSON file, we will now receive all files matching rootDir for the column vault in documents
    final response = await supabase
        .from('documents')
        .select()
        .eq('vault', rootDir);

    final documents = response;
    for (var document in documents) {
      final filePath = document['title'];
      final fileContent = document['snapshot'];
      final fileName = filePath.split('/').last; // Extract filename from path
      final newFilePath = '$rootDir/$fileName'; // Save to rootDir/filename
      final file = File(newFilePath);
      await file.writeAsString(fileContent); // Write content to the file
      print('Saved document: $newFilePath');
    }
  }

  Future<void> sendRealtime(String filePath) async {
    final myChannel = supabase.channel('test-channel');

    // Sending a message before subscribing will use HTTP
    final res = await myChannel.sendBroadcastMessage(
      event: "shout",
      payload: {'message': 'Hi'},
    );
    print(res);

    // Sending a message after subscribing will use Websockets
    myChannel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        myChannel.sendBroadcastMessage(
          event: 'shout',
          payload: {'message': 'hello, world'},
        );
      }
    });
  }

  Future<void> receiveRealtime(String filePath) async {
    final myChannel = supabase.channel('test-channel');

    // Simple function to log any messages we receive
    void messageReceived(payload) {
      print(payload);
    }

    // Subscribe to the Channel
    myChannel
        .onBroadcast(
          event:
              'shout', // Listen for "shout". Can be "*" to listen to all events
          callback: (payload) => messageReceived(payload),
        )
        .subscribe();
  }
}
