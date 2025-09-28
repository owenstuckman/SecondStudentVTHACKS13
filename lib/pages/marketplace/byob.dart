// This Dart code defines a Flutter page for submitting text to a Supabase endpoint.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ByobPage extends StatefulWidget {
  @override
  _ByobPageState createState() => _ByobPageState();
}

class _ByobPageState extends State<ByobPage> {
  final TextEditingController _controller = TextEditingController();
  String _message = '';

  Future<void> _submitText() async {
    final textToSubmit = _controller.text;

    if (textToSubmit.isNotEmpty) {
      final response = await Supabase.instance.client
          .from('endpoints') // Replace with your actual table name
          .insert({'exec': textToSubmit}); // Replace with your actual column name

      if (response.error == null) {
        setState(() {
          _message = 'Submission Successful: $textToSubmit';
          _controller.clear(); // Clear the text field after submission
        });
      } else {
        setState(() {
          _message = 'Submission Failed: ${response.error!.message}';
        });
      }
    } else {
      setState(() {
        _message = 'Please enter some text before submitting.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Make Your Own')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter your text here',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitText,
              child: Text('Submit'),
            ),
            SizedBox(height: 16),
            Text(
              _message,
              style: TextStyle(color: Colors.green, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
