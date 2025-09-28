import 'package:flutter/material.dart';
import 'package:secondstudent/pages/marketplace/marketplace_cards.dart'; // Adjust the import path as necessary
import 'package:supabase_flutter/supabase_flutter.dart';
import 'byob.dart';

class Marketplace extends StatefulWidget {
  @override
  _MarketplaceState createState() => _MarketplaceState();
}

class _MarketplaceState extends State<Marketplace> {
  List<Map<String, dynamic>> data = [];

  @override
  void initState() {
    super.initState();
    _runSupabaseFunction();
  }

  Future<void> _runSupabaseFunction() async {
    final response = await Supabase.instance.client
        .from('collections') // Replace with your actual table name
        .select();

    if (response.isNotEmpty) {
      // Handle successful response
      print('Supabase function executed successfully: ${response.toString()}');
      setState(() {
        data = response;
      });
    } else {
      // Handle error
      print('Error executing Supabase function.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Marketplace')),
      body: Column(
        // Remove SingleChildScrollView to prevent layout issues
        children: [
          Expanded(
            // Use Expanded to allow the Column to take available space
            child: MarketplaceCards(
              data: data,
            ), // Call the MarketplaceCards widget with the fetched data
          ),
          SizedBox(height: 16), // Add some spacing
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the "Make Your Own" page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ByobPage()), // Correct navigation to ByobPage
          );
        },
        child: Icon(Icons.add, size: 36), // Plus button with increased size
        tooltip: 'Make Your Own',
        mini: false, // Ensure the button is not mini
      ),
    );
  }
}
