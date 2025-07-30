import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:animate_do/animate_do.dart';

class ViewSchedulePage extends StatefulWidget {
  const ViewSchedulePage({super.key});

  @override
  State<ViewSchedulePage> createState() => _ViewSchedulePageState();
}

class _ViewSchedulePageState extends State<ViewSchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Map<DateTime, List<String>> _events = {
    DateTime.utc(2024, 11, 5): ['Monitored'],
    DateTime.utc(2024, 11, 7): ['Monitored'],
    DateTime.utc(2024, 11, 11): ['Monitored'],
    DateTime.utc(2024, 11, 13): ['Fixed'],
    DateTime.utc(2024, 11, 19): ['Monitored'],
    DateTime.utc(2024, 11, 24): ['Unfixed Reports'],
    DateTime.utc(2024, 11, 29): ['Planned'],
  };

  List<String> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  Color _getMarkerColor(String type) {
    switch (type) {
      case 'Monitored':
        return const Color(0xFF2F8E2F);
      case 'Unfixed Reports':
        return const Color(0xFFD94B3B);
      case 'Fixed':
        return const Color(0xFFC18B00);
      case 'Planned':
        return const Color(0xFF4A2C6F);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Center(
            child: FadeIn(
              duration: const Duration(milliseconds: 300),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule for Monitoring',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMM().format(_focusedDay),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TableCalendar<String>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFF4A2C6F).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFF4A2C6F),
                          shape: BoxShape.circle,
                        ),
                        outsideTextStyle: const TextStyle(color: Colors.grey),
                        defaultTextStyle:
                            const TextStyle(color: Colors.black87),
                        weekendTextStyle:
                            const TextStyle(color: Colors.black87),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Color(0xFF4A2C6F),
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Color(0xFF4A2C6F),
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          final types = _getEventsForDay(day);
                          if (types.isEmpty) return const SizedBox.shrink();

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: types.map((type) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: _getMarkerColor(type),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      eventLoader: _getEventsForDay,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'Legend',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        legendRow('Monitored', const Color(0xFF2F8E2F)),
                        legendRow('Unfixed Reports', const Color(0xFFD94B3B)),
                        legendRow('Fixed', const Color(0xFFC18B00)),
                        legendRow(
                            'Planned to Monitor', const Color(0xFF4A2C6F)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget legendRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
