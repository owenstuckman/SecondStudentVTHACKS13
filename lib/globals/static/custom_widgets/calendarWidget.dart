import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:localstorage/localstorage.dart';
import 'package:secondstudent/globals/static/custom_widgets/styled_button.dart';
import 'package:secondstudent/globals/static/types/assignment.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:secondstudent/globals/static/extensions/local-storage-wrap.dart';
import 'package:secondstudent/globals/static/extensions/canvasFullQuery.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarWidget extends StatefulWidget {
  final String description;
  final String calendarViewtype;

  const CalendarWidget(this.description, this.calendarViewtype, {super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

final GlobalKey<MonthViewState> monthViewKey = GlobalKey<MonthViewState>();
final GlobalKey<WeekViewState> weekViewKey = GlobalKey<WeekViewState>();
final GlobalKey<DayViewState> dayViewKey = GlobalKey<DayViewState>();

class _CalendarWidgetState extends State<CalendarWidget> {
  late EventController _eventController;
  int _eventId = 1;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;

  String stripHtml(String input) {
    final almost = input.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    return almost.replaceAll('&nbsp;', ' ');
  }

  @override
  void initState() {
    super.initState();
    _eventController = EventController();
    final assignments = localStorage.getItem('assignments');
    if (assignments != null && assignments.isNotEmpty) {
      final List<dynamic> assignmentsList =
          jsonDecode(assignments) as List<dynamic>;
      final List<CalendarEventData> initialEvents = assignmentsList
          .whereType<Map>()
          .map((e) {
            final String title = (e['title'] ?? 'Event').toString();
            final String? dueAt = e['due_at']?.toString();
            final DateTime date = dueAt != null
                ? DateTime.parse(dueAt).toLocal()
                : DateTime.now();
            return CalendarEventData(
              title: title,
              date: date,
              description: (e['description'] ?? '').toString(),
              event: e,
            );
          })
          .toList();
      if (initialEvents.isNotEmpty) {
        _eventController.addAll(initialEvents);
      }
    }
    fetchData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    final domain = localStorage.getItem('canvasDomain');
    final token = localStorage.getItem('canvasToken');
    if (domain == null || token == null) {
      return;
    }

    final headers = {'Authorization': 'Bearer $token'};

    try {
      final stored = localStorage.getItem('assignments');
      final Set<String> existingIds = {};
      if (stored != null && stored.isNotEmpty) {
        final List<dynamic> storedList = jsonDecode(stored) as List<dynamic>;
        for (final item in storedList) {
          if (item is Map && item['id'] != null) {
            existingIds.add(item['id'].toString());
          }
        }
      }

      final List<CalendarEventData> newEvents = [];
      final List<Map<String, dynamic>> newMetas = [];

      final Uri coursesUrl = Uri.parse(
        '$domain/api/v1/courses?enrollment_type=student&enrollment_state=active',
      );

      final List<dynamic> courses = await CanvasFullQuery.fetchAllPages(
        coursesUrl,
        headers,
      );

      await Future.wait(
        courses.map((course) async {
          if (course is! Map) return;
          final dynamic idVal = course['id'];
          final int courseId = idVal is int
              ? idVal
              : int.tryParse(idVal?.toString() ?? '') ?? 0;
          if (courseId == 0) return;

          final Uri assignmentsUrl = Uri.parse(
            '$domain/api/v1/courses/$courseId/assignments?per_page=100',
          );
          final List<dynamic> assignments = await CanvasFullQuery.fetchAllPages(
            assignmentsUrl,
            headers,
          );

          for (final assignment in assignments) {
            if (assignment is! Map) continue;
            final dueAt = assignment['due_at'];
            if (dueAt == null) continue;

            final String idStr = assignment['id'].toString();
            if (existingIds.contains(idStr)) continue;

            final String title = (assignment['name'] ?? 'Assignment')
                .toString();
            final String description = (assignment['description'] ?? '')
                .toString();

            final Map<String, dynamic> meta = {
              'id': assignment['id'],
              'title': title,
              'description': description,
              'due_at': dueAt,
              'html_url': assignment['html_url'],
              'course_id': assignment['course_id'],
              'source': 'canvas',
              'completed': assignment['has_submitted_submissions'] == true,
            };

            final event = CalendarEventData(
              title: title.isEmpty ? 'Assignment' : title,
              date: DateTime.parse(dueAt).toLocal(),
              event: meta,
              description: description,
            );

            newEvents.add(event);
            newMetas.add(meta);
            existingIds.add(idStr);
          }
        }),
      );

      if (newEvents.isNotEmpty) {
        _eventController.addAll(newEvents);
        localStorage.inclusiveSetItem('assignments', jsonEncode(newMetas));
      }
    } catch (e) {
      print(e);
    }
  }

  Widget _headerBuilder(DateTime date) {
    const monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final title = '${monthNames[date.month - 1]} ${date.year}';
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _addEvent({
    required String title,
    required String description,
    required DateTime date,
  }) {
    final DateTime normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
    );
    final String generatedId =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    final newEvent = CalendarEventData(
      title: title.isEmpty ? 'New Event ${_eventId++}' : title,
      date: normalizedDate,
      event: {
        'id': generatedId,
        'title': title,
        'description': description,
        'due_at': normalizedDate.toUtc().toIso8601String(),
        'source': 'local',
      },
    );
    _eventController.add(newEvent);

    final Map<String, dynamic> jsonEvent = {
      'id': generatedId,
      'title': newEvent.title,
      'description': description,
      'due_at': normalizedDate.toUtc().toIso8601String(),
      'source': 'local',
    };
    localStorage.inclusiveSetItem('assignments', jsonEncode([jsonEvent]));

    setState(() {});
    Navigator.of(context).pop();
  }

  Widget _dialogBuilder(DateTime date) {
    final DateTime displayDate = _selectedDate ?? date;

    return Dialog(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.3,
        width: MediaQuery.of(context).size.width * 0.3,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: displayDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Event Name',
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Event Description',
                  ),
                ),
                SizedBox(height: 10),
                StyledButton(
                  text: 'Add Event',
                  onTap: () {
                    _addEvent(
                      title: _nameController.text.trim(),
                      description: _descriptionController.text.trim(),
                      date: _selectedDate ?? date,
                    );
                    _nameController.clear();
                    _descriptionController.clear();
                    _selectedDate = null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetails(CalendarEventData event) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final meta = event.event;
    final String source = (meta is Map && meta['source'] is String)
        ? meta['source'] as String
        : 'unknown';
    final String description = (meta is Map && meta['description'] is String)
        ? meta['description'] as String
        : '';
    final String? htmlUrl = (meta is Map && meta['html_url'] is String)
        ? meta['html_url'] as String
        : null;
    final bool isCompleted = (meta is Map && meta['completed'] == true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: source == 'local'
                          ? colorScheme.secondary
                          : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title ?? 'Event',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Due: ${event.date?.toLocal().toString() ?? ''}',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
              if (description.isNotEmpty) ...[
                SizedBox(height: 8),
                HtmlWidget(
                  description,
                  onTapUrl: (url) async {
                    return await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
              if (htmlUrl != null && htmlUrl.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Link: $htmlUrl',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ],
              SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _eventChip(CalendarEventData event, ColorScheme colorScheme) {
    final meta = event.event;
    final String source = (meta is Map && meta['source'] is String)
        ? meta['source'] as String
        : 'canvas';
    final bool isCompleted = meta is Map && meta['completed'] == true;

    final Color barColor = source == 'local'
        ? colorScheme.secondary
        : colorScheme.primary;

    final Color chipBg = isCompleted
        ? barColor.withOpacity(0.25)
        : barColor.withOpacity(0.12);
    final Color chipBorder = isCompleted
        ? barColor.withOpacity(0.7)
        : barColor.withOpacity(0.5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 18, color: barColor),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              event.title ?? '',
              maxLines: 1,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withOpacity(isCompleted ? 0.6 : 1),
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    return CalendarControllerProvider(
      controller: _eventController,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                iconSize: 32,
                onPressed: () {
                  if (monthViewKey.currentState != null) {
                    monthViewKey.currentState?.animateToPage(
                      monthViewKey.currentState!.currentPage - 1,
                    );
                  }
                },
                icon: Icon(Icons.arrow_back),
              ),
              IconButton(
                iconSize: 32,
                onPressed: () {
                  if (monthViewKey.currentState != null) {
                    monthViewKey.currentState?.animateToPage(
                      monthViewKey.currentState!.currentPage + 1,
                    );
                  }
                },
                icon: Icon(Icons.arrow_forward),
              ),
            ],
          ),
          MonthView(
            key: monthViewKey,
            // Users can swipe/drag horizontally to change months (built-in behavior)
            minMonth: DateTime(now.year, now.month - 2),
            maxMonth: DateTime(now.year, now.month + 3),
            initialMonth: DateTime(now.year, now.month),
            startDay: WeekDays.monday,
            headerBuilder: _headerBuilder,
            showWeekTileBorder: false,
            hideDaysNotInMonth: true,
            cellAspectRatio: 1.5,
            onPageChange: (date, pageIndex) {
              setState(() {});
            },
            onCellTap: (events, date) {},
            cellBuilder:
                (date, events, isToday, isInMonth, hideDaysNotInMonth) {
                  if (!isInMonth && hideDaysNotInMonth) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isToday
                          ? colorScheme.primary.withValues(alpha: 0.1)
                          : colorScheme.surfaceContainer,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: events.map((event) {
                                  return GestureDetector(
                                    onTap: () {
                                      _showEventDetails(event);
                                    },
                                    child: _eventChip(event, colorScheme),
                                  );
                                }).toList(),
                              ),
                            ),
                            Container(
                              alignment: Alignment.topRight,
                              child: Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isInMonth
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurface,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
            onEventTap: (event, date) {
              _showEventDetails(event);
            },
            onEventDoubleTap: (events, date) {},
            onEventLongTap: (event, date) {},
            onDateLongPress: (date) {},
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: colorScheme.primary,
              onPressed: () => showDialog(
                context: context,
                builder: (context) => _dialogBuilder(now),
              ),
              child: Icon(Icons.add, color: colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
