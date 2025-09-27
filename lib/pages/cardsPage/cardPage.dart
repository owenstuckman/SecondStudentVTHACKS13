import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

Future<void> hitApi() async {
  var client = http.Client();
  try {
    var response = await client.post(Uri.https('{{canvas_domain}}/api/v1/courses?include[]=&state[]=available', 'whatsit/create'),
        body: {'name': 'doodle', 'color': 'blue'});
    var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    var uri = Uri.parse(decodedResponse['uri'] as String);
    print(await client.get(uri));
  } finally {
    client.close();
  }
}

Widget cardCarouselWidget(
    String frontText, String backText, BuildContext context) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;

  final cardFlipper = FlipCardController();
  final MediaQueryData mediaQuery = MediaQuery.of(context);

  Widget cardWidget(String frontText, String backText, BuildContext context) {
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

  return Scaffold(
    appBar: AppBar(
      title: const Text("FlipCards"),
    ),
    body: Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) => cardWidget(
          frontText,
          backText,
          context,
        ),
      ),
    ),
  );
}

class _MyAppState extends State<CardPage> {
  final con = FlipCardController();

  @override
  Widget build(BuildContext context) {
    return cardCarouselWidget("frontText", "backText", context);
  }
}
