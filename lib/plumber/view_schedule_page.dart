import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewSchedulePage extends StatefulWidget {
  const ViewSchedulePage({super.key});

  @override
  State<ViewSchedulePage> createState() => _ViewSchedulePageState();
}

class _ViewSchedulePageState extends State<ViewSchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  Color _getMarkerColor(String status) {
    switch (status) {
      case 'Monitoring':
        return const Color(0xFF2F8E2F);
      case 'Unfixed':
        return const Color(0xFFD94B3B);
      case 'Fixed':
        return const Color(0xFFC18B00);
      default:
        return Colors.grey;
    }
  }

  void _showReportsDialog(
      BuildContext context, List<Map<String, dynamic>> reports) {
    showDialog(
      context: context,
      builder: (context) => FadeIn(
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              backgroundColor: Colors.white.withOpacity(0.95),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reports for ${DateFormat.yMMMd().format(_selectedDay!)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 100,
                                height: 2,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF5E35B1),
                                      Color(0xFF8E24AA),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Color(0xFF5E35B1),
                                size: 20,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: reports.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final report = reports[index];
                            return FadeInUp(
                              duration:
                                  Duration(milliseconds: 200 + index * 100),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      _getMarkerColor(report['status'])
                                          .withOpacity(0.2),
                                  child: Text(
                                    (report['fullName'] ?? 'U')[0],
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  report['fullName'] ?? 'Unknown',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                trailing: Chip(
                                  label: Text(
                                    report['status'] ?? 'Unknown',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: _getMarkerColor(
                                          report['status'] ?? 'Unknown')
                                      .withOpacity(0.3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey[50]!,
              Colors.grey[100]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Center(
              child: FadeIn(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reports')
                        .where('monitoringDate', isNotEqualTo: null)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading reports',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Build events map from Firestore data
                      _events = {};
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final monitoringDate =
                            data['monitoringDate'] as Timestamp?;
                        if (monitoringDate != null) {
                          final date = DateTime.utc(
                            monitoringDate.toDate().year,
                            monitoringDate.toDate().month,
                            monitoringDate.toDate().day,
                          );
                          _events[date] = _events[date] ?? [];
                          _events[date]!.add({
                            'fullName': data['fullName'] ?? 'Unknown',
                            'status': data['status'] ?? 'Unknown',
                          });
                        }
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monitoring Schedule',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat.yMMMM().format(_focusedDay),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TableCalendar<Map<String, dynamic>>(
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
                              final events = _getEventsForDay(selectedDay);
                              if (events.isNotEmpty) {
                                _showReportsDialog(context, events);
                              }
                            },
                            calendarStyle: CalendarStyle(
                              todayDecoration: BoxDecoration(
                                color: const Color(0xFF5E35B1).withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF5E35B1),
                                    Color(0xFF8E24AA),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              outsideTextStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              defaultTextStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              weekendTextStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              markersAlignment: Alignment.bottomCenter,
                              markerDecoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.1),
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              leftChevronIcon: ZoomIn(
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.chevron_left,
                                  color: Color(0xFF5E35B1),
                                  size: 24,
                                ),
                              ),
                              rightChevronIcon: ZoomIn(
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF5E35B1),
                                  size: 24,
                                ),
                              ),
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, events) {
                                final reportEvents = _getEventsForDay(day);
                                if (reportEvents.isEmpty)
                                  return const SizedBox.shrink();

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: reportEvents.map((event) {
                                    return ZoomIn(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        child: Icon(
                                          Icons.circle,
                                          size: 10,
                                          color:
                                              _getMarkerColor(event['status']),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            eventLoader: _getEventsForDay,
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            'Legend',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              legendItem('Monitoring', const Color(0xFF2F8E2F)),
                              const SizedBox(width: 16),
                              legendItem('Unfixed', const Color(0xFFD94B3B)),
                              const SizedBox(width: 16),
                              legendItem('Fixed', const Color(0xFFC18B00)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget legendItem(String label, Color color) {
    return ZoomIn(
      duration: const Duration(milliseconds: 400),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
