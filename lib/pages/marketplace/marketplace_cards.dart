import 'package:flutter/material.dart';
import 'package:secondstudent/globals/database.dart';
import 'package:secondstudent/pages/marketplace/endpoint.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // Import for file handling

class MarketplaceCard {
  final String id;
  final String name;
  final String description;
  final String author;
  final bool verified;
  final bool enabled;
  final dynamic metadata;

  MarketplaceCard({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.verified,
    required this.enabled,
    this.metadata,
  });
}

class CFunction {
  final int endpointId;
  final String name;
  final String exec;
  final String description;

  CFunction({
    required this.endpointId,
    required this.name,
    required this.exec,
    required this.description,
  });

  factory CFunction.fromJson(Map<String, dynamic> json) {
    return CFunction(
      endpointId: json['endpointId'] as int,
      name: json['name'] as String,
      exec: json['exec'] as String,
      description: json['description'] as String,
    );
  }
}

class MarketplaceCards extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<Map<String, dynamic>> endpoints = []; // Concurrent list to hold endpoints
  final Set<String> installedEndpoints = {}; // Track installed endpoints

  MarketplaceCards({Key? key, required this.data}) : super(key: key);

  Future<List<MarketplaceCard>> fetchCards() async {
    final List<Map<String, dynamic>> response = await supabase
        .from('collections') // Fetch data from the collections table
        .select();

    return response.map((item) {
      return MarketplaceCard(
        id: item['id'].toString(),
        name: item['name'] ?? 'Unnamed',
        description: item['description'] ?? 'No description available',
        author: item['author']?.toString() ?? 'Unknown Author',
        verified: item['verified'] ?? false,
        enabled: item['enabled'] ?? false,
        metadata: item['metadata'],
      );
    }).toList();
  }

  void _showDetailCard(BuildContext context, MarketplaceCard card) async {
    final List<Map<String, dynamic>> response = await supabase
        .from('endpoints')
        .select('*')
        .eq('collection', card.id);

    endpoints.clear(); // Clear previous endpoints
    endpoints.addAll(response); // Store the fetched endpoints

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EndpointsListView(
          endpoints: endpoints,
        ), // Navigate to the new list view
      ),
    );
  }

  void _installEndpoint(
    BuildContext context,
    List<Map<String, dynamic>> endpoint,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? pathToFiles = prefs.getString('path_to_files')?.trim();
    if (pathToFiles != null && pathToFiles.isNotEmpty) {
      final Directory studentDirectory = Directory(pathToFiles);
      final Directory secondStudentDirectory = Directory(
        '${studentDirectory.path}/.secondstudent/customblocks',
      );

      StringBuffer execCommands = StringBuffer();

      for (var ep in endpoints) { // Use a different variable name
        execCommands.writeln(ep['exec']);
        installedEndpoints.add(ep['name']); // Track installed endpoint

        /*
  // Method to add a new item
  void addItem(SlashMenuItemData item) {
    _items.add(item);
  }
*/

      }

      if (!await secondStudentDirectory.exists()) {
        await secondStudentDirectory.create(recursive: true);
      }

      final execFile = File('${secondStudentDirectory.path}/execs.dart');
      await execFile.writeAsString(execCommands.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Installed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MarketplaceCard>>(
      future: fetchCards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No items available.'));
        }

        final cards = snapshot.data!;

        return ListView.builder(
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return GestureDetector(
              onTap: () {
                _showDetailCard(context, card);
              },
              child: Container(
                width: 250, // Reduced width for smaller cards
                height: 200, // Reduced height for smaller cards
                margin: EdgeInsets.all(8), // Reduced margin for better spacing
                padding: EdgeInsets.all(12), // Reduced padding for a more compact look
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12), // Slightly smaller border radius
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1), // Lighter shadow for a softer look
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16, // Reduced font size for the name
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4), // Reduced space between elements
                    Text(
                      card.description,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                      ), // Reduced font size for description
                    ),
                    SizedBox(height: 4),
                    if (card.verified)
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                        ), // Reduced font size for verified label
                      ),
                    SizedBox(height: 8), // Space before the button
                    ElevatedButton.icon(
                      onPressed: installedEndpoints.contains(card.name) 
                          ? null 
                          : () => _installEndpoint(context, card.metadata), // Disable button if already installed
                      icon: Icon(
                        Icons.install_desktop,
                        size: 24,
                      ), // Bigger icon
                      label: Text(
                        'Install',
                        style: TextStyle(fontSize: 16),
                      ), // Bigger text
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ), // Bigger button
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class EndpointsListView extends StatelessWidget {
  final List<Map<String, dynamic>> endpoints;

  const EndpointsListView({Key? key, required this.endpoints}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Endpoints'),
        actions: [
          // Removed install button from the second page
        ],
      ),
      body: ListView.builder(
        itemCount: endpoints.length,
        itemBuilder: (context, index) {
          final endpoint = endpoints[index];
          return ListTile(
            title: Text(endpoint['name'] ?? 'Unnamed Endpoint'),
            subtitle: Text(
              endpoint['description'] ?? 'No description available',
            ),
            onTap: () {
              // Handle endpoint selection
            },
          );
        },
      ),
    );
  }
}
