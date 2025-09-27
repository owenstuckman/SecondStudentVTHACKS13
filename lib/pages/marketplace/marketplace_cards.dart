import 'package:flutter/material.dart';
import 'package:secondstudent/globals/database.dart';

class MarketplaceCard {
  final String id;
  final String name;
  final String description;
  final String author;
  final bool verified;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastUpdated;
  final dynamic metadata;

  MarketplaceCard({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.verified,
    required this.enabled,
    required this.createdAt,
    this.lastUpdated,
    this.metadata,
  });
}

class MarketplaceCards extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const MarketplaceCards({Key? key, required this.data}) : super(key: key);

  List<MarketplaceCard> get cards {
    return data.map((item) {
      return MarketplaceCard(
        id: item['id'].toString(),
        name: item['name'] ?? 'Unnamed',
        description: item['description'] ?? 'No description available',
        author: item['author']?.toString() ?? 'Unknown Author',
        verified: item['verified'] ?? false,
        enabled: item['enabled'] ?? false,
        createdAt: DateTime.parse(item['created_at']),
        lastUpdated: item['last_updated'] != null
            ? DateTime.parse(item['last_updated'])
            : null,
        metadata: item['metadata'],
      );
    }).toList();
  }

  void _showDetailCard(BuildContext context, MarketplaceCard card) async {
    // Fetch additional info from Supabase
    final response = await supabase
        .from('endpoints')
        .select()
        .eq('collection', card.id);

    List<Map<String, dynamic>> additionalInfoList = response;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(card.name),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Text('Description: ${card.description}'),
                Text('Author: ${card.author}'),
                Text('Verified: ${card.verified ? "Yes" : "No"}'),
                Text('Enabled: ${card.enabled ? "Yes" : "No"}'),
                Text('Created At: ${card.createdAt.toLocal()}'),
                Text('Last Updated: ${card.lastUpdated?.toLocal() ?? "Never"}'),
                SizedBox(height: 10), // Space before additional info
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3, // Adjust aspect ratio as needed
                  ),
                  itemCount: additionalInfoList.length,
                  itemBuilder: (context, index) {
                    final info = additionalInfoList[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info['name'] ?? 'Unnamed',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(info['description'] ?? 'No description available'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (card.metadata != null)
                  Text('Metadata: ${card.metadata.toString()}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          contentPadding: EdgeInsets.all(70),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 2 / 3,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(child: Text('No items available.'));
    }

    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return GestureDetector(
          onTap: () => _showDetailCard(context, card),
          child: Container(
            width: 300,
            height: 250, // Ensured all cards have a consistent height
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  card.description,
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
                SizedBox(height: 10),
                Text(
                  'Author: ${card.author}',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                SizedBox(height: 5),
                if (card.verified)
                  Text(
                    'Verified',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
