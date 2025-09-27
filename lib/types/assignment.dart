class Assignment {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String? priority;
  final String? course;
  final String? teacher;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.priority,
    this.course,
    this.teacher,
  });
}
