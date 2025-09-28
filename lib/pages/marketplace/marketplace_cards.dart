import 'package:flutter/material.dart';
import 'package:secondstudent/globals/database.dart';
import 'package:secondstudent/pages/marketplace/endpoint.dart';
import 'package:dart_eval/stdlib/core.dart' as de;

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
    final List<Map<String, dynamic>> response = await supabase
        .from('endpoints')
        .select('*')
        .eq('collection', card.id);

    final dbCode = response[0]['exec'];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvalPage(
          dbCode: dbCode,
          args: [
            de.$String(card.name),
            de.$String(card.description),
            de.$String(card.id),
            const de.$null(),
          ],
        ),
      ),
    );
  }

  void _showGeneral(BuildContext context, MarketplaceCard card) async {
    final List<Map<String, dynamic>> response = await supabase
        .from('endpoints')
        .select('*')
        .eq('collection', card.id);

    final dbCode = response[0]['exec'];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => General(
          dbCode: dbCode,
          args: [
            de.$String(card.name),
            de.$String(card.description),
            de.$String(card.id),
            const de.$null(),
          ],
        ),
      ),
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
          onTap: () {
            _showGeneral(context, card);
          },
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
