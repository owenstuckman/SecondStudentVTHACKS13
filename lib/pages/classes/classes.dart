// lib/pages/editor/workspace.dart
import 'file.dart';
import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:secondstudent/globals/static/extensions/canvasFullQuery.dart';
import 'package:localstorage/localstorage.dart';
import 'package:secondstudent/globals/static/custom_widgets/classesCard.dart';
import 'package:secondstudent/globals/static/types/class.dart';

class Classes extends StatefulWidget {
  const Classes({super.key});

  @override
  State<Classes> createState() => _ClassesState();
}

class _ClassesState extends State<Classes> {
  List<dynamic> courses = [];
  @override
  void initState() {
    super.initState();
    getClasses();
  }

  Future<void> getClasses() async {
    final domain = localStorage.getItem('canvasDomain');
    final token = localStorage.getItem('canvasToken');
    if (domain == null || token == null) {}

    final headers = {'Authorization': 'Bearer $token'};

    try {
      final Uri coursesUrl = Uri.parse(
        '$domain/api/v1/courses?enrollment_type=student&enrollment_state=active&include[]=current_period_computed_current_grade',
      );
      final List<dynamic> courses = await CanvasFullQuery.fetchAllPages(
        coursesUrl,
        headers,
      );

      log("courses: $courses");
      setState(() {
        log(DateTime.now().subtract(Duration(days: 360)).toString());
        this.courses = courses
            .where(
              (e) => DateTime.parse(
                e['created_at'],
              ).isAfter(DateTime.now().subtract(Duration(days: 180))),
            )
            .toList();
      });
    } catch (_) {
      // Swallow errors silently for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          height: MediaQuery.of(context).size.height, // Use full screen height
          width: MediaQuery.of(context).size.width, // Use full screen width
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: SizedBox(
                  width: 980, // Fixed width for three cards + spacing
                  height: MediaQuery.of(context).size.height - 100,
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: courses.length,

                    itemBuilder: (context, index) {
                      final course = courses[index];

                      return MouseRegion(
                        cursor: SystemMouseCursors
                            .click, // shows a pointer-hand on hover
                        child: GestureDetector(
                          key: Key(course['id'].toString()),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    FilePage(courseId: course['id']),
                              ),
                            );
                          },
                          child: ClassesCard(
                            Class(
                              id: course['id'],
                              name: course['name'] ?? '',
                              course_code: course['course_code'] ?? '',
                              created_at: course['created_at'] ?? '',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
