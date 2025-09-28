import 'package:flutter/material.dart';
import 'package:flutter_eval/flutter_eval.dart';
import 'package:dart_eval/dart_eval.dart';

class EvalPage extends StatelessWidget {
  const EvalPage({required this.dbCode, this.args = const []});

  final String dbCode;
  final List<dynamic> args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: CompilerWidget(
        packages: {
          'remote': {
            'main.dart': dbCode, // your code string from Supabase
          },
        },
        library: 'package:remote/main.dart',
        function: 'ClassesCardEval.',
        args: args,
      ),
    );
  }
}
