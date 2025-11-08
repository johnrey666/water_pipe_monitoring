import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'view_schedule_page.dart';
import 'view_reports_page.dart';
import 'geographic_mapping_page.dart';
import 'auth/plumber_login.dart';
import 'dart:async';

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
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  Map<DateTime, List<Map<String, dynamic>>> _reportEvents = {};
  Set<String> _selectedStatuses = {'Monitoring', 'Unfixed Reports', 'Fixed'};
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Notification state
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _notifSubscription;

  @override
  void initState() {
    super.initState();
    _fetchPlumberName();
    _setupNotifications();
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

  void _setupNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _notifSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _notifications = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        _unreadCount =
            _notifications.where((n) => !(n['read'] ?? false)).length;
      });
    });
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = notif['read'] ?? false;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isRead ? Colors.grey.shade50 : Colors.blue.shade50,
                      child: ListTile(
                        leading: Icon(
                          Icons.notifications,
                          color: isRead ? Colors.grey : Colors.blue,
                        ),
                        title: Text(
                          notif['title'] ?? '',
                          style: GoogleFonts.poppins(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notif['message'] ?? ''),
                            Text(
                              _formatTimestamp(notif['timestamp']),
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        onTap: () async {
                          if (!isRead) {
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(notif['id'])
                                .update({'read': true});
                          }
                          if (notif['reportId'] != null) {
                            setState(() {
                              _initialReportId = notif['reportId'];
                              _selectedPage = PlumberPage.reports;
                            });
                            Navigator.pop(context);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate());
    }
    return 'N/A';
  }

  void _onSelectPage(PlumberPage page) {
    print('Navigating to page: $page');
    Navigator.of(context).pop();
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
          return false;
        }
        print('Back button pressed on schedule page, staying on dashboard');
        return false;
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
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _showNotifications(context),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reports')
                      .where('assignedPlumber',
                          isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Error loading reports: ${snapshot.error}',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.red.shade600),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    _reportEvents = {};
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final timestamp = data['dateTime'] as Timestamp?;
                      if (timestamp == null) {
                        print('Skipping report ${doc.id}: Missing dateTime');
                        continue;
                      }
                      try {
                        final date = timestamp.toDate();
                        final utcDate =
                            date.toUtc().add(const Duration(hours: 8));
                        final dateKey =
                            DateTime(utcDate.year, utcDate.month, utcDate.day);
                        _reportEvents[dateKey] = _reportEvents[dateKey] ?? [];
                        _reportEvents[dateKey]!.add({
                          'id': doc.id,
                          'title':
                              data['issueDescription'] ?? 'Untitled Report',
                          'time': DateFormat.jm().format(date),
                          'fullName': data['fullName'] ?? 'Unknown',
                          'status': data['status'] ?? 'Unknown',
                          'priority': data['priority'] ?? 'medium',
                        });
                      } catch (e) {
                        print('Error processing report ${doc.id}: $e');
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF87CEEB), Color(0xFFE0F7FA)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateFormat.yMMMM().format(_focusedDay),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ).animate().fadeIn(
                              duration: const Duration(milliseconds: 300)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: Text('Monitoring',
                                    style: GoogleFonts.poppins(fontSize: 12)),
                                selected:
                                    _selectedStatuses.contains('Monitoring'),
                                selectedColor:
                                    Colors.lightBlue.withOpacity(0.2),
                                checkmarkColor: Colors.lightBlue,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedStatuses.add('Monitoring');
                                    } else {
                                      _selectedStatuses.remove('Monitoring');
                                    }
                                  });
                                },
                              ),
                              FilterChip(
                                label: Text('Unfixed',
                                    style: GoogleFonts.poppins(fontSize: 12)),
                                selected: _selectedStatuses
                                    .contains('Unfixed Reports'),
                                selectedColor:
                                    Colors.orange.shade600.withOpacity(0.2),
                                checkmarkColor: Colors.orange.shade600,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedStatuses.add('Unfixed Reports');
                                    } else {
                                      _selectedStatuses
                                          .remove('Unfixed Reports');
                                    }
                                  });
                                },
                              ),
                              FilterChip(
                                label: Text('Fixed',
                                    style: GoogleFonts.poppins(fontSize: 12)),
                                selected: _selectedStatuses.contains('Fixed'),
                                selectedColor:
                                    Colors.green.shade600.withOpacity(0.2),
                                checkmarkColor: Colors.green.shade600,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedStatuses.add('Fixed');
                                    } else {
                                      _selectedStatuses.remove('Fixed');
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              DropdownButton<CalendarFormat>(
                                value: _calendarFormat,
                                items: const [
                                  DropdownMenuItem(
                                    value: CalendarFormat.month,
                                    child: Text('Month',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: CalendarFormat.twoWeeks,
                                    child: Text('2 Weeks',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: CalendarFormat.week,
                                    child: Text('Week',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _calendarFormat = value;
                                    });
                                  }
                                },
                                underline: const SizedBox(),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 2.0,
                          child: TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) =>
                                isSameDay(day, _selectedDay),
                            rangeStartDay: _rangeStart,
                            rangeEndDay: _rangeEnd,
                            calendarFormat: _calendarFormat,
                            rangeSelectionMode: RangeSelectionMode.toggledOn,
                            eventLoader: (day) {
                              final dateKey =
                                  DateTime(day.year, day.month, day.day);
                              return _reportEvents[dateKey]
                                      ?.where((event) => _selectedStatuses
                                          .contains(event['status']))
                                      .toList() ??
                                  [];
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                                _rangeStart = null;
                                _rangeEnd = null;
                              });
                            },
                            onRangeSelected: (start, end, focusedDay) {
                              setState(() {
                                _selectedDay = start ?? _selectedDay;
                                _rangeStart = start;
                                _rangeEnd = end;
                                _focusedDay = focusedDay;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              setState(() {
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarStyle: CalendarStyle(
                              defaultTextStyle: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.black87),
                              weekendTextStyle: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                              outsideTextStyle: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.grey.shade400),
                              todayDecoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF87CEEB),
                                    Color(0xFFE0F7FA)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.blue.shade700, width: 2),
                              ),
                              selectedDecoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF87CEEB),
                                    Color(0xFFE0F7FA)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              rangeStartDecoration: BoxDecoration(
                                color: Colors.blue.shade300,
                                shape: BoxShape.circle,
                              ),
                              rangeEndDecoration: BoxDecoration(
                                color: Colors.blue.shade300,
                                shape: BoxShape.circle,
                              ),
                              rangeHighlightColor:
                                  Colors.blue.shade100.withOpacity(0.3),
                              defaultDecoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 0.5),
                              ),
                              cellMargin: const EdgeInsets.all(4),
                              tableBorder: TableBorder.all(
                                  color: Colors.grey.shade200, width: 0.5),
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, date, events) {
                                if (events.isEmpty) return null;
                                if (events.length > 5) {
                                  return Positioned(
                                    bottom: 1,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade700,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${events.length}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ).animate().pulse(
                                        duration:
                                            const Duration(milliseconds: 500)),
                                  );
                                }
                                return Positioned(
                                  bottom: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: events.map((event) {
                                      if (event is! Map<String, dynamic>) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 2),
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade600,
                                            shape: BoxShape.circle,
                                          ),
                                        );
                                      }
                                      final status =
                                          event['status'] as String? ??
                                              'Unknown';
                                      final priority =
                                          event['priority'] as String? ??
                                              'medium';
                                      final color = status == 'Monitoring'
                                          ? Colors.lightBlue
                                          : status == 'Unfixed Reports'
                                              ? Colors.orange.shade600
                                              : status == 'Fixed'
                                                  ? Colors.green.shade600
                                                  : Colors.grey.shade600;
                                      final icon = status == 'Monitoring'
                                          ? Icons.circle
                                          : status == 'Unfixed Reports'
                                              ? Icons.warning
                                              : Icons.check;
                                      return GestureDetector(
                                        onLongPress: () {
                                          final statusCounts = {
                                            'Monitoring': 0,
                                            'Unfixed Reports': 0,
                                            'Fixed': 0,
                                            'Unknown': 0,
                                          };
                                          for (var e in events) {
                                            if (e is Map<String, dynamic>) {
                                              statusCounts[
                                                      (e['status'] as String? ??
                                                          'Unknown')] =
                                                  (statusCounts[(e['status']
                                                                  as String? ??
                                                              'Unknown')] ??
                                                          0) +
                                                      1;
                                            } else {
                                              statusCounts['Unknown'] =
                                                  (statusCounts['Unknown'] ??
                                                          0) +
                                                      1;
                                            }
                                          }
                                          final tooltipText = statusCounts
                                              .entries
                                              .where((e) => e.value > 0)
                                              .map((e) => '${e.value} ${e.key}')
                                              .join(', ');
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Events on ${DateFormat.yMMMd().format(date)}: $tooltipText',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 14),
                                              ),
                                              duration:
                                                  const Duration(seconds: 3),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: priority == 'high'
                                                ? Border.all(
                                                    color: Colors.red.shade600,
                                                    width: 1)
                                                : null,
                                          ),
                                          child: Icon(
                                            icon,
                                            size: 12,
                                            color: color,
                                          ).animate(
                                            effects: status == 'Unfixed Reports'
                                                ? []
                                                : [],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                              dowBuilder: (context, day) {
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final text = DateFormat.E()
                                        .format(day)
                                        .substring(0, 3);
                                    final double underlineWidth =
                                        (constraints.maxWidth * 0.8)
                                            .clamp(10, 20)
                                            .toDouble();
                                    return ClipRect(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            text,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                            overflow: TextOverflow.clip,
                                            maxLines: 1,
                                          ),
                                          Container(
                                            height: 2,
                                            width: underlineWidth,
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color(0xFF87CEEB),
                                                  Color(0xFFE0F7FA)
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              defaultBuilder: (context, day, focusedDay) {
                                final hasEvents = _reportEvents[DateTime(
                                            day.year, day.month, day.day)]
                                        ?.isNotEmpty ??
                                    false;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 0.5),
                                  ),
                                  child: Transform.scale(
                                    scale: hasEvents ? 1.1 : 1.0,
                                    child: Center(
                                      child: Text(
                                        '${day.day}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            headerVisible: false,
                          ).animate().fadeIn(
                              duration: const Duration(milliseconds: 500)),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            _rangeStart != null && _rangeEnd != null
                                ? 'Reports from ${DateFormat.yMMMd().format(_rangeStart!)} to ${DateFormat.yMMMd().format(_rangeEnd!)}'
                                : 'Reports for ${DateFormat.yMMMd().format(_selectedDay)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        _buildEventList(),
                      ],
                    );
                  },
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
    List<Map<String, dynamic>> events = [];
    if (_rangeStart != null && _rangeEnd != null) {
      final days = _rangeEnd!.difference(_rangeStart!).inDays + 1;
      for (int i = 0; i < days; i++) {
        final date = _rangeStart!.add(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        if (_reportEvents.containsKey(dateKey)) {
          events.addAll(_reportEvents[dateKey]!
              .where((e) => _selectedStatuses.contains(e['status']))
              .toList());
        }
      }
    } else {
      final dateKey =
          DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      events = _reportEvents.containsKey(dateKey)
          ? _reportEvents[dateKey]!
              .where((e) => _selectedStatuses.contains(e['status']))
              .toList()
          : [];
    }
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            'No reports for this selection',
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
          final status = event['status'] as String? ?? 'Unknown';
          final priority = event['priority'] as String? ?? 'medium';
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
                child: Icon(
                  status == 'Monitoring'
                      ? Icons.circle
                      : status == 'Unfixed Reports'
                          ? Icons.warning
                          : Icons.check,
                  color: color,
                  size: 22,
                ),
              ),
              title: Text(
                '${event['fullName']}: ${event['title']}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  decoration:
                      priority == 'high' ? TextDecoration.underline : null,
                  decorationColor: Colors.red.shade600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: Text(
                '${event['time']} • $status • Priority: $priority',
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

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }
}
