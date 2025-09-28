import 'package:flutter/material.dart';
import 'package:flutter_eval/flutter_eval.dart';
import 'package:dart_eval/dart_eval.dart';
import 'package:secondstudent/pages/marketplace/marketplace_cards.dart';
import 'package:dart_eval/stdlib/core.dart'
    as de; // Import dart_eval/stdlib/core.dart as de
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

class InfoBanner extends StatelessWidget {
  const InfoBanner({required this.dbCode, required this.args});

  final String dbCode;
  final List<dynamic> args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: CompilerWidget(
        packages: {
          'remote': {'main.dart': dbCode},
        },
        library: 'package:remote/main.dart',
        function: 'InfoBannerEval.',
        args: args,
      ),
    );
  }
}

class General extends StatelessWidget {
  const General({required this.cfunctions});

  final List<CFunction> cfunctions;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Build up to 9 tiles (3 rows x 3 cols), padding with placeholders
    final tiles = <Widget>[
      for (final fn in _functions)
        Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CompilerWidget(
              packages: {
                'remote': {'main.dart': dbCode},
              },
              library: 'package:remote/main.dart',
              function: fn,
              args: args,
            ),
                        library: 'package:remote/main.dart',
                        function: cfunction.name + '.',
                        args: args,
                      );
                    },
                  )
                : Center(
                    child: Text('No code available for ${cfunction.name}'),
                  ),
          ),
        ),

      for (int i = 0; i < (6 - cfunctions.length).clamp(0, 6); i++)
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surface,
          ),
          child: const Center(child: Text('Empty')),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 4 / 3,
          children: tiles,
        ),
      ),
    );
  }
}
