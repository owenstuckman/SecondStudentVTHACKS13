import 'package:flutter/material.dart';
import 'package:secondstudent/globals/static/types/class.dart';

class ClassesCard extends StatelessWidget {
  final Class _class;

  // Correct way to pass data using the constructor
  const ClassesCard(this._class, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // build method only takes BuildContext
    return Container(
      width: 300, // Increased width for a blockier appearance
      height: 200, // Adjusted height
      margin: EdgeInsets.all(10), // Added margin for spacing between cards
      padding: EdgeInsets.all(15), // Added internal padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          15,
        ), // Slightly more rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ), // Added subtle shadow for depth
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align content to start
        children: [
          Text(
            _class.name,
            style: TextStyle(
              color: Colors.black,
              fontSize: 18, // Larger font for name
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5), // Space between name and course code
          Text(
            _class.course_code,
            style: TextStyle(color: Colors.black87, fontSize: 14),
          ),
          SizedBox(height: 10), // Space before created_at
          Text(
            'Created: ${DateTime.parse(_class.created_at).toLocal().toString().split(' ')[0]}',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          // You can add more elements here, like a teacher's name or an icon.
        ],
      ),
    );
  }
}
