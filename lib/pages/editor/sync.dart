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

    // Upsert the document in Supabase
    await supabase.from('documents').upsert({
      "title": filePath, // Use filePath instead of file object
      "snapshot": jsonData,
      "updated_at": ts,
    });
  }

  Future<void> syncAllFiles(String rootDir) async {
    final ts = DateTime.now();
    final directory = Directory(rootDir);
    final files = directory.listSync(recursive: true);

    for (var fileEntity in files) {
      if (fileEntity is File) {
        final filePath = fileEntity.path;
        final fileExtension = filePath.split('.').last; // Get the file extension
        final jsonData = await fileEntity.readAsString(); // Read the file content as a string

        if (fileExtension == 'json') {
          await supabase.from('documents').upsert({
            "title": filePath,
            "snapshot": jsonData,
            "updated_at": ts,
            "vault": rootDir,
          });
        } else {
          // Upload the non-JSON file to Supabase storage
          await supabase.storage.from('userfiles').upload(fileEntity.uri.pathSegments.last, fileEntity);
        }
      }
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
    myChannel.onBroadcast(
      event: 'shout', // Listen for "shout". Can be "*" to listen to all events
      callback: (payload) => messageReceived(payload),
    ).subscribe();
  }
}
