import 'package:flutter/material.dart';

class Calendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sample Text Page'),
      ),
      body: Center(
        child: Text(
          'This is a sample text.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
