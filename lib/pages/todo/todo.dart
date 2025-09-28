import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

class ToDo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sample Text Page')),
      body: Center(
        child: Column(
          children: [
            Text('This is a sample text.', style: TextStyle(fontSize: 24)),
            Text('This is a sample text.', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
