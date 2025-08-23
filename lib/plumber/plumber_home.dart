import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'view_schedule_page.dart';
import 'view_reports_page.dart';
import 'geographic_mapping_page.dart';
import 'auth/plumber_login.dart';

enum PlumberPage { schedule, reports, mapping }

class PlumberHomePage extends StatefulWidget {
  const PlumberHomePage({super.key});

  @override
  State<PlumberHomePage> createState() => _PlumberHomePageState();
}

class _PlumberHomePageState extends State<PlumberHomePage>
    with TickerProviderStateMixin {
  PlumberPage _selectedPage = PlumberPage.schedule;
  String? _initialReportId;
  String _plumberName = 'Plumber User';
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _reportEvents = {};

  @override
  void initState() {
    super.initState();
    _fetchPlumberName();
    _fetchReports();
  }

  Future<void> _fetchPlumberName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user found in _fetchPlumberName, staying on current page');
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['fullName'] != null) {
        setState(() {
          _plumberName = data['fullName'];
        });
      }
    } catch (e) {
      print('Error fetching plumber name: $e');
    }
  }

  Future<void> _fetchReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user authenticated in _fetchReports, staying on current page');
      return;
    }
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('assignedPlumber', isEqualTo: user.uid)
          .get();
      setState(() {
        _reportEvents = {};
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final timestamp = data['dateTime'] as Timestamp?;
          if (timestamp == null) {
            print('Skipping report ${doc.id}: Missing dateTime');
            continue;
          }
          try {
            final date = timestamp.toDate();
            // Normalize to UTC+8 to match sample document
            final utcDate = date.toUtc().add(const Duration(hours: 8));
            print('Report ${doc.id}: dateTime = $date, UTC+8 = $utcDate');
            final dateKey = DateTime(utcDate.year, utcDate.month, utcDate.day);
            _reportEvents[dateKey] = _reportEvents[dateKey] ?? [];
            _reportEvents[dateKey]!.add({
              'id': doc.id,
              'title': data['issueDescription'] ?? 'Untitled Report',
              'time': DateFormat.jm().format(date),
              'fullName': data['fullName'] ?? 'Unknown',
              'status': data['status'] ?? 'Unknown',
            });
          } catch (e) {
            print('Error processing report ${doc.id}: $e');
          }
        }
        print(
            'Fetched report events: ${_reportEvents.length} days with events');
        _reportEvents.forEach((key, value) {
          print('Date: $key, Events: ${value.map((e) => e['id']).toList()}');
        });
      });
    } catch (e) {
      print('Error fetching reports: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading reports: $e')),
      );
    }
  }

  void _onSelectPage(PlumberPage page) {
    print('Navigating to page: $page');
    Navigator.of(context).pop(); // Close the drawer
    setState(() {
      _selectedPage = page;
      _initialReportId = null;
    });
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              print('Logging out user');
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const PlumberLoginPage()),
                (route) => false,
              );
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedPage != PlumberPage.schedule) {
          print('Back button pressed, returning to schedule page');
          setState(() {
            _selectedPage = PlumberPage.schedule;
            _initialReportId = null;
          });
          return false; // Prevent back navigation to LandingPage or PlumberLoginPage
        }
        print('Back button pressed on schedule page, staying on dashboard');
        return false; // Prevent back navigation to LandingPage or PlumberLoginPage
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            'Plumber',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          elevation: 2,
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Colors.blue.shade700),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF87CEEB),
                        Color.fromARGB(255, 127, 190, 226),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.plumbing,
                            size: 36, color: Color.fromARGB(255, 58, 56, 56)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome!',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _plumberName,
                              style: GoogleFonts.poppins(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildDrawerItem(
                        icon: Icons.schedule,
                        title: 'View Schedule',
                        page: PlumberPage.schedule,
                      ),
                      _buildDrawerItem(
                        icon: Icons.report,
                        title: 'View Reports',
                        page: PlumberPage.reports,
                      ),
                      _buildDrawerItem(
                        icon: Icons.map_outlined,
                        title: 'Geographic Mapping',
                        page: PlumberPage.mapping,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: _logout,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation,
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey(_selectedPage),
            child: _selectedPage == PlumberPage.schedule
                ? _buildScheduleContent()
                : _getPageContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required PlumberPage page,
  }) {
    final bool isSelected = _selectedPage == page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: isSelected ? const Color(0xFF87CEEB) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: Colors.grey[800],
            size: 24,
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          selected: isSelected,
          onTap: () => _onSelectPage(page),
        ),
      ),
    );
  }

  Widget _getPageContent() {
    switch (_selectedPage) {
      case PlumberPage.schedule:
        return const ViewSchedulePage();
      case PlumberPage.reports:
        return ViewReportsPage(initialReportId: _initialReportId);
      case PlumberPage.mapping:
        return const GeographicMappingPage();
      default:
        return const ViewSchedulePage();
    }
  }

  Widget _buildScheduleContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            FadeInDown(
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(
                        Icons.plumbing,
                        color: Colors.blue.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $_plumberName!',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            'Manage your tasks and reports.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reports')
                        .where('assignedPlumber',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .where('status', isEqualTo: 'Monitoring')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count =
                          snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return ElasticIn(
                        duration: const Duration(milliseconds: 300),
                        child: _buildSummaryCard(
                          title: 'Monitoring',
                          count: count,
                          icon: Icons.visibility,
                          color: Colors.lightBlue,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reports')
                        .where('assignedPlumber',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .where('status', isEqualTo: 'Unfixed Reports')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count =
                          snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return ElasticIn(
                        duration: const Duration(milliseconds: 300),
                        delay: const Duration(milliseconds: 100),
                        child: _buildSummaryCard(
                          title: 'Unfixed',
                          count: count,
                          icon: Icons.report_problem,
                          color: Colors.orange.shade600,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reports')
                        .where('assignedPlumber',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .where('status', isEqualTo: 'Fixed')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count =
                          snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return ElasticIn(
                        duration: const Duration(milliseconds: 300),
                        delay: const Duration(milliseconds: 200),
                        child: _buildSummaryCard(
                          title: 'Fixed',
                          count: count,
                          icon: Icons.check_circle,
                          color: Colors.green.shade600,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Calendar
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Your Schedule',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, _selectedDay),
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month'
                      },
                      eventLoader: (day) {
                        final dateKey = DateTime(day.year, day.month, day.day);
                        return _reportEvents[dateKey] ?? [];
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isEmpty) return null;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: events.map((event) {
                              final status = event is Map
                                  ? event['status'] ?? 'Unknown'
                                  : 'Unknown';
                              final color = status == 'Monitoring'
                                  ? Colors.lightBlue
                                  : status == 'Unfixed Reports'
                                      ? Colors.orange.shade600
                                      : status == 'Fixed'
                                          ? Colors.green.shade600
                                          : Colors.grey.shade600;
                              return Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      headerStyle: HeaderStyle(
                        titleTextStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        formatButtonVisible: false,
                        leftChevronIcon: Icon(Icons.chevron_left,
                            color: Colors.blue.shade700, size: 20),
                        rightChevronIcon: Icon(Icons.chevron_right,
                            color: Colors.blue.shade700, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Reports for ${DateFormat.yMMMd().format(_selectedDay)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    _buildEventList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  count.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final dateKey =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final events =
        _reportEvents.containsKey(dateKey) ? _reportEvents[dateKey]! : [];
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            'No reports for this day',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final status = event['status'] ?? 'Unknown';
          final color = status == 'Monitoring'
              ? Colors.lightBlue
              : status == 'Unfixed Reports'
                  ? Colors.orange.shade600
                  : status == 'Fixed'
                      ? Colors.green.shade600
                      : Colors.grey.shade600;
          return FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: Duration(milliseconds: index * 100),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(Icons.report, color: color, size: 22),
              ),
              title: Text(
                '${event['fullName']}: ${event['title']}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: Text(
                '${event['time']} • $status',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onTap: () {
                setState(() {
                  _initialReportId = event['id'];
                  _selectedPage = PlumberPage.reports;
                });
              },
            ),
          );
        },
      ),
    );
  }
}
