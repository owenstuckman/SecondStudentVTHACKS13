import 'package:flutter/material.dart';
import 'package:secondstudent/types/class.dart';

class ClassesCard extends StatelessWidget {
  final Class _class;

  // Correct way to pass data using the constructor
  const ClassesCard(this._class, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // build method only takes BuildContext
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(_class.title),
          Text(_class.description),
          Text(_class.teacher),
        ],
      ),
    );
  }
}
