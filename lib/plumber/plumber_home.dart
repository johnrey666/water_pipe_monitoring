import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<Map<String, dynamic>> _notifications = [];
  Set<String> _readNotifications = Set<String>();
  bool _isDropdownOpen = false;
  final GlobalKey _bellKey = GlobalKey();
  String? _initialReportId;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('assignedPlumber', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Monitoring')
          .get();
      setState(() {
        _notifications = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final residentName = data['fullName'] ?? 'Unknown Resident';
          return {
            'id': doc.id,
            'message': 'You have a new $residentName Monitoring!',
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  void _onSelectPage(PlumberPage page) {
    Navigator.of(context).pop();
    setState(() {
      _selectedPage = page;
    });
  }

  void _openReportFromNotification(String reportId) {
    setState(() {
      _initialReportId = reportId;
      _selectedPage = PlumberPage.reports;
      _isDropdownOpen = false;
    });
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PlumberLoginPage()),
      (route) => false,
    );
  }

  void _toggleDropdown() {
    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });
  }

  void _markAsRead(String notificationId) {
    setState(() {
      _readNotifications.add(notificationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.length - _readNotifications.length;
    final RenderBox? bellBox =
        _bellKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset? bellPosition = bellBox?.localToGlobal(Offset.zero);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dropdownWidth = 300;
    final double dropdownTop = (bellPosition?.dy ?? kToolbarHeight) + -15;
    final double dropdownLeft = bellPosition != null
        ? (bellPosition.dx - dropdownWidth + 48)
            .clamp(16, screenWidth - dropdownWidth - 16)
        : (screenWidth - dropdownWidth - 16);

    return Scaffold(
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6E4A9E), Color(0xFF4A2C6F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.only(bottomRight: Radius.circular(24)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: const Icon(
                        Icons.plumbing,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome,',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Plumber User',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: Colors.white70),
                  ],
                ),
              ),
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
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('Plumber Portal'),
        centerTitle: true,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                key: _bellKey,
                icon: const Icon(Icons.notifications_none),
                onPressed: _toggleDropdown,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: _getPageContent(),
          ),
          if (_isDropdownOpen && bellBox != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: dropdownTop,
              left: dropdownLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 300,
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _notifications.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No Notifications',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          shrinkWrap: true,
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            final isRead =
                                _readNotifications.contains(notification['id']);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              color: isRead ? Colors.white : Colors.grey[200],
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: const Icon(Icons.notifications,
                                    color: Colors.blueAccent),
                                title: Text(
                                  notification['message'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    color: isRead
                                        ? Colors.black54
                                        : Colors.black87,
                                  ),
                                ),
                                onTap: () {
                                  _markAsRead(notification['id']);
                                  _openReportFromNotification(
                                      notification['id']);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
        leading:
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey.shade700),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.black87,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        onTap: () => _onSelectPage(page),
      ),
    );
  }
}
