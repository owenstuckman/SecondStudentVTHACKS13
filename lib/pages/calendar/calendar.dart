import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:secondstudent/globals/static/custom_widgets/calendarWidget.dart';

class Calendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calendar')),
      body: Center(child: CalendarWidget("Test", "month")),
    );
  }
}
