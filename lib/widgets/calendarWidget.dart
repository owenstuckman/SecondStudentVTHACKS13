import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';

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

  @override
  void initState() {
    super.initState();
    _eventController = EventController();

    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month, 10);

    final sampleEvent = CalendarEventData(
      title: "Event 1",
      date: currentMonthDate,
      event: "Event 1",
    );
    _eventController.add(sampleEvent);

    final sampleEvent2 = CalendarEventData(
      title: "Event 2",
      date: DateTime(now.year, now.month, 15),
      event: "Event 2",
    );
    _eventController.add(sampleEvent2);
  }

  @override
  void dispose() {
    _eventController.dispose();
    super.dispose();
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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _addEventForToday() {
    final now = DateTime.now();
    final newEvent = CalendarEventData(
      title: 'New Event ${_eventId++}',
      date: DateTime(now.year, now.month, now.day),
      event: 'New Event',
    );
    _eventController.add(newEvent);
    setState(() {});
  }

  Widget _dialogBuilder(DateTime date) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
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
                TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Event Name',
                  ),
                ),
              ],
            ),
          ),
        ),
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
                        monthViewKey.currentState!.currentPage - 1);
                  }
                },
                icon: Icon(Icons.arrow_back),
              ),
              IconButton(
                iconSize: 32,
                onPressed: () {
                  if (monthViewKey.currentState != null) {
                    monthViewKey.currentState?.animateToPage(
                        monthViewKey.currentState!.currentPage + 1);
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
            cellBuilder: (
              date,
              events,
              isToday,
              isInMonth,
              hideDaysNotInMonth,
            ) {
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      spacing: 4.0,
                      children: events.map((event) {
                        return Container(
                          width: 30,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.rectangle,
                          ),
                        );
                      }).toList(),
                    ),
                    Container(
                      alignment: Alignment.topRight,
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isInMonth
                              ? colorScheme.onSurface
                              : colorScheme.onSurface,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            onEventTap: (event, date) {},
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
                  context: context, builder: (context) => _dialogBuilder(now)),
              child: Icon(Icons.add, color: colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
