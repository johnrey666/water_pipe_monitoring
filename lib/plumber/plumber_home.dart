// ignore_for_file: unnecessary_cast, unused_element

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

  // For dropdown
  final GlobalKey _notificationButtonKey = GlobalKey();
  OverlayEntry? _notificationOverlay;

  // Monitoring events for calendar
  Map<DateTime, List<Map<String, dynamic>>> _monitoringEvents = {};

  // Prevent multiple navigations
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _fetchPlumberName();
    _setupNotifications();
    _setupMonitoringEvents();
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

  void _setupMonitoringEvents() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('weekly_monitorings')
        .where('plumberId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _monitoringEvents = {};
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final monitoringDate = (data['monitoringDate'] as Timestamp).toDate();
          final dateKey = DateTime(
              monitoringDate.year, monitoringDate.month, monitoringDate.day);
          _monitoringEvents[dateKey] = _monitoringEvents[dateKey] ?? [];
          _monitoringEvents[dateKey]!.add({
            'id': doc.id,
            'title': 'Weekly Monitoring',
            'description': data['description'] ?? 'No description',
            'status': data['status'] ?? 'pending',
          });
        }
      });
    });
  }

  void _showNotificationOverlay() {
    final RenderBox renderBox =
        _notificationButtonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        right: screenSize.width - position.dx - size.width,
        top: position.dy + size.height + 8,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 300,
              maxHeight: 500,
            ),
            child: NotificationDropdown(
              notifications: _notifications,
              unreadCount: _unreadCount,
              onMarkAsRead: _markNotificationAsRead,
              onNotificationTap: _handleNotificationTap,
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_notificationOverlay!);
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      setState(() {
        _unreadCount--;
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notif) async {
    if (_isNavigating) return;
    _isNavigating = true;
    
    try {
      // Mark as read if not already read
      if (!(notif['read'] ?? false)) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notif['id'])
            .update({'read': true});
        setState(() {
          _unreadCount--;
        });
      }
      
      _removeNotificationOverlay();
      
      // Add a small delay to ensure overlay is removed
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Handle the notification based on type
      if (notif['monitoringId'] != null) {
        _showWeeklyMonitoringModal(monitoringId: notif['monitoringId']);
      } else if (notif['reportId'] != null) {
        // Clear any existing report ID first
        setState(() {
          _initialReportId = null;
        });
        
        // Wait for state to update
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Navigate to reports page with the report ID
        if (mounted) {
          setState(() {
            _initialReportId = notif['reportId'];
            _selectedPage = PlumberPage.reports;
          });
        }
      } else {
        // General notification - just close the overlay
        print('General notification tapped: ${notif['title']}');
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    } finally {
      _isNavigating = false;
    }
  }

  void _showWeeklyMonitoringModal({String? monitoringId}) {
    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return const SizedBox.shrink();

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4FC3F7),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weekly Monitorings',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 24),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('weekly_monitorings')
                          .where('plumberId', isEqualTo: user.uid)
                          .where('status', isEqualTo: 'pending')
                          .orderBy('monitoringDate', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  'Error loading monitorings',
                                  style: GoogleFonts.poppins(color: Colors.red),
                                ),
                              ],
                            ),
                          );
                        }
                        final monitorings = snapshot.data?.docs ?? [];
                        if (monitorings.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_outlined,
                                    size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'No pending weekly monitorings assigned.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: monitorings.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final doc = monitorings[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final monitoringDate =
                                (data['monitoringDate'] as Timestamp).toDate();
                            final description =
                                data['description'] as String? ??
                                    'No description';
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.assignment,
                                    color: const Color(0xFF4FC3F7),
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  DateFormat('MMMM dd, yyyy')
                                      .format(monitoringDate),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    description,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                trailing: ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('weekly_monitorings')
                                          .doc(doc.id)
                                          .update({'status': 'done'});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Marked as done!',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(
                                    'Done',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
    Navigator.of(context).pop(); // Close drawer

    switch (page) {
      case PlumberPage.schedule:
        if (_selectedPage != PlumberPage.schedule) {
          setState(() {
            _selectedPage = page;
            _initialReportId = null;
          });
        }
        break;
      case PlumberPage.reports:
        if (_selectedPage != PlumberPage.reports) {
          setState(() {
            _selectedPage = page;
            _initialReportId = null;
          });
        }
        break;
      case PlumberPage.mapping:
        if (_selectedPage != PlumberPage.mapping) {
          setState(() {
            _selectedPage = page;
            _initialReportId = null;
          });
        }
        break;
    }
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
                  key: _notificationButtonKey,
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: Colors.blue.shade700,
                    size: 26,
                  ),
                  onPressed: () {
                    if (_notificationOverlay == null) {
                      _showNotificationOverlay();
                    } else {
                      _removeNotificationOverlay();
                    }
                  },
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
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
            key: ValueKey('${_selectedPage}_${_initialReportId ?? "no_report"}'),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showWeeklyMonitoringModal(),
                icon:
                    const Icon(Icons.assignment, color: Colors.white, size: 18),
                label: Text(
                  'View Weekly Monitoring',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
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
                              final reportEvents = _reportEvents[dateKey]
                                      ?.where((event) => _selectedStatuses
                                          .contains(event['status']))
                                      .toList() ??
                                  [];
                              final monitoringEvents =
                                  _monitoringEvents[dateKey] ?? [];
                              return [...reportEvents, ...monitoringEvents];
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
        if (_monitoringEvents.containsKey(dateKey)) {
          events.addAll(_monitoringEvents[dateKey]!);
        }
      }
    } else {
      final dateKey =
          DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      if (_reportEvents.containsKey(dateKey)) {
        events.addAll(_reportEvents[dateKey]!
            .where((e) => _selectedStatuses.contains(e['status']))
            .toList());
      }
      if (_monitoringEvents.containsKey(dateKey)) {
        events.addAll(_monitoringEvents[dateKey]!);
      }
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
                          : status == 'Fixed'
                              ? Icons.check
                              : Icons.assignment_outlined,
                  color: color,
                  size: 22,
                ),
              ),
              title: Text(
                '${event['fullName'] ?? ''}: ${event['title']}',
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
                '${event['time'] ?? ''} • $status • Priority: $priority',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onTap: () {
                if (event['id'] != null &&
                    event['title'] == 'Weekly Monitoring') {
                  _showWeeklyMonitoringModal(monitoringId: event['id']);
                } else {
                  setState(() {
                    _initialReportId = event['id'];
                    _selectedPage = PlumberPage.reports;
                  });
                }
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
    _removeNotificationOverlay();
    super.dispose();
  }
}

class NotificationDropdown extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final Function(String) onMarkAsRead;
  final Function(Map<String, dynamic>) onNotificationTap;

  const NotificationDropdown({
    super.key,
    required this.notifications,
    required this.unreadCount,
    required this.onMarkAsRead,
    required this.onNotificationTap,
  });

  @override
  State<NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown> {
  int _page = 0;
  static const int _itemsPerPage = 3;

  @override
  Widget build(BuildContext context) {
    if (widget.notifications.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: Text('No notifications')),
      );
    }

    // Sort notifications by timestamp descending
    final sortedNotifications =
        List<Map<String, dynamic>>.from(widget.notifications);
    sortedNotifications.sort((a, b) =>
        (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

    final totalPages = (sortedNotifications.length / _itemsPerPage).ceil();
    final currentItems = sortedNotifications
        .skip(_page * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...currentItems
              .map((notif) => _buildNotificationItem(context, notif)),
          if (totalPages > 1)
            _buildPaginationRow(
              currentPage: _page,
              totalPages: totalPages,
              onPrev: () =>
                  setState(() => _page = (_page - 1).clamp(0, totalPages - 1)),
              onNext: () =>
                  setState(() => _page = (_page + 1).clamp(0, totalPages - 1)),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, Map<String, dynamic> notif) {
    final isRead = notif['read'] ?? false;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: isRead ? Colors.white : Colors.grey[200],
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Icon(
          Icons.notifications,
          color: isRead ? Colors.grey : Colors.blue,
          size: 20,
        ),
        title: Text(
          notif['title'] ?? '',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? Colors.grey[600] : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (notif['message'] ?? '').length > 50
                  ? '${(notif['message'] ?? '').substring(0, 50)}...'
                  : notif['message'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _formatTimestamp(notif['timestamp']),
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        onTap: () => widget.onNotificationTap(notif),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate());
    }
    return 'N/A';
  }

  Widget _buildPaginationRow({
    required int currentPage,
    required int totalPages,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: currentPage > 0 ? onPrev : null,
            child: const Text('Previous'),
          ),
          Text('${currentPage + 1} of $totalPages'),
          TextButton(
            onPressed: currentPage < totalPages - 1 ? onNext : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}