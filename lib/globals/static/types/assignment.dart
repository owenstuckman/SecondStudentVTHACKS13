class Assignment {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String? priority;
  final String? course;
  final String? teacher;
  final String? courseID; // Add courseID
  final String? courseName; // Add courseName

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.priority,
    this.course,
    this.teacher,
    this.courseID, // Initialize courseID
    this.courseName, // Initialize courseName
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: DateTime.parse(json['dueDate'] as String),
      priority: json['priority'] as String?,
      course: json['course'] as String?,
      teacher: json['teacher'] as String?,
      courseID: json['courseID'] as String?,
      courseName: json['courseName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority,
      'course': course,
      'teacher': teacher,
      'courseID': courseID,
      'courseName': courseName,
    };
  }
}
