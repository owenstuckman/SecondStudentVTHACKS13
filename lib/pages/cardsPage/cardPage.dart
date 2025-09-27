import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient supabase = Supabase.instance.client;

class CardPage extends StatefulWidget {
  const CardPage({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class CardData {
  final String question;
  final String answer;

  CardData({required this.question, required this.answer});

  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }
}

Widget cardWidget(String frontText, String backText, BuildContext context) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;

  final cardFlipper = FlipCardController();
  final MediaQueryData mediaQuery = MediaQuery.of(context);

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: FlipCard(
          onTapFlipping: true,
          controller: cardFlipper,
          frontWidget: Center(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              width: mediaQuery.size.width / 3,
              height: mediaQuery.size.height / 3,
              child: Center(
                child: Text(
                  frontText,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 25,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
          backWidget: Center(
            child: Container(
              width: mediaQuery.size.width / 3,
              height: mediaQuery.size.height / 3,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  backText,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 25,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
          rotateSide: RotateSide.right),
    ),
  );
}

class _MyAppState extends State<CardPage> {
  final con = FlipCardController();
  List<CardData> cardData = [];

  Future<void> getCardData(String idea) async {
    final res = await supabase.functions.invoke('NoteCardProcess', body: {
      'idea': idea,
    });
    if (!mounted) return;
    setState(() {
      if (res.data is List) {
        final List<dynamic> responseData = res.data as List<dynamic>;
        cardData = responseData
            .map((item) => CardData.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FlipCards"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: cardData.length,
          itemBuilder: (context, index) => cardWidget(
            cardData[index].question,
            cardData[index].answer,
            context,
          ),
        ),
      ),
    );
  }
}
