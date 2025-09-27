import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:localstorage/localstorage.dart';
import 'package:path_provider/path_provider.dart';
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

Future<List<dynamic>> fetchData() async {
  final url = Uri.parse(
      '${localStorage.getItem('canvasDomain')}/api/v1/courses?include[]=&state[]=available');
  print(url);

  final headers = {
    'Authorization': 'Bearer ${localStorage.getItem('canvasToken')}',
  };
  print(headers);

  try {
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      print(response.body);

      return jsonDecode(response.body);
    }
    print("Error: ${response.statusCode}");
    return [];
  } catch (e) {
    print("Error: $e");
    return [];
  }
}

Widget cardCarouselWidget(String frontText, String backText,
    BuildContext context, List<dynamic> data) {
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
        itemCount: data.length,
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
  var data = [];
  final con = FlipCardController();

  @override
  void initState() {
    super.initState();
    fetchData().then((value) {
      setState(() {
        data = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return cardCarouselWidget("frontText", "backText", context, data);
  }
}
