import 'package:flutter/material.dart';
import 'package:secondstudent/pages/marketplace/marketplace_cards.dart'; // Adjust the import path as necessary
import 'package:supabase_flutter/supabase_flutter.dart';

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

    if (response.isEmpty != true) {
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
      body: MarketplaceCards(
        data: data,
      ), // Call the MarketplaceCards widget with the fetched data
    );
  }
}
