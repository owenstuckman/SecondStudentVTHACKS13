import 'package:flutter/material.dart';

class ClassesCardEval extends StatelessWidget {
  final String name;
  final String unitCode;
  final String id;

  const ClassesCardEval(this.name, this.unitCode, this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(name), Text(unitCode), Text(id)],
        ),
      ),
    );
  }
}
