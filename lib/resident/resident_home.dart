import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'auth/resident_login.dart';
import 'report_problem_page.dart';
import 'view_billing_page.dart';

void main() {
  runApp(const ResidentialPortalApp());
}

class ResidentialPortalApp extends StatelessWidget {
  const ResidentialPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Residential Portal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF87CEEB),
          primary: const Color(0xFF0288D1),
          secondary: const Color(0xFF4CAF50),
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          margin: const EdgeInsets.all(8),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 2,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black87),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          const TextTheme(
            titleLarge: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            bodyLarge: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            bodyMedium: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
      ),
      home: const ResidentHomePage(),
    );
  }
}

enum ResidentPage { home, report, billing }

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage>
    with TickerProviderStateMixin {
  ResidentPage _selectedPage = ResidentPage.home;
  final GlobalKey _notificationButtonKey = GlobalKey();
  bool _isDropdownOpen = false;
  String _residentName = 'Resident';

  @override
  void initState() {
    super.initState();
    _fetchResidentName();
  }

  Future<void> _fetchResidentName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['fullName'] != null) {
        setState(() {
          _residentName = data['fullName'];
        });
      }
    } catch (e) {
      print('Error fetching resident name: $e');
    }
  }

  Future<double> _fetchTotalWaterConsumption() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('residentId', isEqualTo: user.uid)
          .get();
      final totalConsumption = snapshot.docs.fold<double>(
        0.0,
        (sum, doc) =>
            sum + (doc.data()['currentConsumedWaterMeter']?.toDouble() ?? 0.0),
      );
      return totalConsumption;
    } catch (e) {
      print('Error fetching water consumption: $e');
      return 0.0;
    }
  }

  Future<double> _fetchThisMonthConsumption() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;
    try {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('residentId', isEqualTo: user.uid)
          .get();

      final totalConsumption = snapshot.docs.fold<double>(
        0.0,
        (sum, doc) {
          final data = doc.data();
          final periodStart = (data['periodStart'] as Timestamp?)?.toDate();
          if (periodStart != null &&
              periodStart.year == currentYear &&
              periodStart.month == currentMonth) {
            return sum + (data['currentConsumedWaterMeter']?.toDouble() ?? 0.0);
          }
          return sum;
        },
      );
      return totalConsumption;
    } catch (e) {
      print('Error fetching this month\'s consumption: $e');
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLastSixMonthsConsumption() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    try {
      final now = DateTime.now();
      final months = <Map<String, dynamic>>[];
      final dateFormat = DateFormat('MMM');

      // Generate the last 6 months, including the current month
      for (int i = 0; i < 6; i++) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final monthName = dateFormat.format(targetDate);
        months.add(
            {'month': targetDate, 'monthName': monthName, 'consumption': 0.0});
      }

      // Fetch bills
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('residentId', isEqualTo: user.uid)
          .get();

      // Aggregate consumption by month
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final periodStart = (data['periodStart'] as Timestamp?)?.toDate();
        if (periodStart != null) {
          for (var month in months) {
            if (periodStart.year == month['month'].year &&
                periodStart.month == month['month'].month) {
              month['consumption'] +=
                  (data['currentConsumedWaterMeter']?.toDouble() ?? 0.0);
            }
          }
        }
      }

      // Sort months in descending order (most recent first)
      months.sort((a, b) => b['month'].compareTo(a['month']));
      return months;
    } catch (e) {
      print('Error fetching last six months consumption: $e');
      return [];
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
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
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

  Future<void> _refreshDashboard() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }

  Widget _getPageContent() {
    switch (_selectedPage) {
      case ResidentPage.report:
        return const ReportProblemPage();
      case ResidentPage.billing:
        return const ViewBillingPage();
      case ResidentPage.home:
      default:
        return _buildDashboard();
    }
  }

  void _onSelectPage(ResidentPage page) {
    setState(() {
      _selectedPage = page;
    });
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchNotifications() async {
    print('Fetching notifications...');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      return {'unread': [], 'read': []};
    }
    print('Current user UID: ${user.uid}');

    try {
      final unreadSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('residentId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final readSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('residentId', isEqualTo: user.uid)
          .where('read', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      print('Found ${unreadSnapshot.docs.length} unread notifications');
      print('Found ${readSnapshot.docs.length} read notifications');

      final unreadNotifications = unreadSnapshot.docs.map((doc) {
        final data = doc.data();
        print('Unread notification data: $data');
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'status': data['status'],
          'month': data['month'],
          'amount': data['amount']?.toDouble(),
          'message': data['message'],
          'processedDate': (data['processedDate'] as Timestamp?)?.toDate(),
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();

      final readNotifications = readSnapshot.docs.map((doc) {
        final data = doc.data();
        print('Read notification data: $data');
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'status': data['status'],
          'month': data['month'],
          'amount': data['amount']?.toDouble(),
          'message': data['message'],
          'processedDate': (data['processedDate'] as Timestamp?)?.toDate(),
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();

      print(
          'Processed ${unreadNotifications.length} unread and ${readNotifications.length} read notifications');
      return {'unread': unreadNotifications, 'read': readNotifications};
    } catch (e) {
      print('Error fetching notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: $e')),
      );
      return {'unread': [], 'read': []};
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      print('Marking notification $notificationId as read');
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      print('Notification $notificationId marked as read');
      setState(() {
        _isDropdownOpen = false;
      });
    } catch (e) {
      print('Error marking notification as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notification as read: $e')),
      );
    }
  }

  void _toggleNotificationsDropdown() {
    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const dropdownWidth = 300.0;
    final bellBox =
        _notificationButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final bellPosition = bellBox?.localToGlobal(Offset.zero);
    final dropdownTop = (bellPosition?.dy ?? kToolbarHeight) - 28.0;
    final dropdownLeft = bellPosition != null
        ? (bellPosition.dx - dropdownWidth + 48.0)
            .clamp(16.0, (screenWidth - dropdownWidth - 16.0).toDouble())
        : (screenWidth - dropdownWidth - 16.0).toDouble();

    return WillPopScope(
      onWillPop: () async {
        if (_selectedPage != ResidentPage.home) {
          setState(() {
            _selectedPage = ResidentPage.home;
          });
          return false;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            'Resident',
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
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('residentId',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                int notificationCount = 0;
                if (snapshot.hasData) {
                  notificationCount = snapshot.data!.docs.length;
                  print(
                      'StreamBuilder: Found $notificationCount unread notifications');
                } else if (snapshot.hasError) {
                  print('StreamBuilder error: ${snapshot.error}');
                }
                return Stack(
                  children: [
                    IconButton(
                      key: _notificationButtonKey,
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: Colors.blue.shade700,
                        size: 26,
                      ),
                      onPressed: _toggleNotificationsDropdown,
                    ),
                    if (notificationCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            notificationCount.toString(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
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
                        child: Icon(Icons.person,
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
                              _residentName,
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
                        icon: Icons.home_outlined,
                        title: 'Home',
                        page: ResidentPage.home,
                      ),
                      _buildDrawerItem(
                        icon: Icons.report_problem_outlined,
                        title: 'Report Water Problem',
                        page: ResidentPage.report,
                      ),
                      _buildDrawerItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'View Billing',
                        page: ResidentPage.billing,
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
        body: Stack(
          children: [
            AnimatedSwitcher(
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
                child: _getPageContent(),
              ),
            ),
            if (_isDropdownOpen && bellBox != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                top: dropdownTop,
                left: dropdownLeft,
                child: FadeIn(
                  duration: const Duration(milliseconds: 200),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: dropdownWidth,
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.white],
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
                      child: FutureBuilder<
                          Map<String, List<Map<String, dynamic>>>>(
                        future: _fetchNotifications(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Error loading notifications',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          final notifications =
                              snapshot.data ?? {'unread': [], 'read': []};
                          final unreadNotifications = notifications['unread']!;
                          final readNotifications = notifications['read']!;
                          if (unreadNotifications.isEmpty &&
                              readNotifications.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No Notifications',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }
                          return ListView(
                            padding: const EdgeInsets.all(8),
                            shrinkWrap: true,
                            children: [
                              if (unreadNotifications.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Unread Notifications',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                ...unreadNotifications.map((notification) =>
                                    _buildNotificationItem(
                                        notification, false)),
                              ],
                              if (readNotifications.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Read Notifications',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                ...readNotifications.map((notification) =>
                                    _buildNotificationItem(notification, true)),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required ResidentPage page,
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
          onTap: () {
            Navigator.pop(context);
            _onSelectPage(page);
          },
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
      Map<String, dynamic> notification, bool isRead) {
    String text;
    IconData icon;
    Color iconColor;
    if (notification['type'] == 'report_status') {
      text = notification['message'] ?? 'Issue fixed';
      icon = Icons.check_circle;
      iconColor = isRead ? Colors.grey[400]! : Colors.green;
    } else {
      final status =
          notification['status'] == 'approved' ? 'Successful' : 'Declined';
      final month = notification['month'] ?? 'Unknown';
      final amount = notification['amount']?.toStringAsFixed(2) ?? '0.00';
      text = 'Payment of ₱$amount for $month is $status';
      icon = notification['status'] == 'approved'
          ? Icons.check_circle
          : Icons.cancel;
      iconColor = isRead
          ? Colors.grey[400]!
          : (notification['status'] == 'approved' ? Colors.green : Colors.red);
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: isRead ? Colors.white : Colors.grey[200],
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? Colors.grey[600] : Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          notification['createdAt'] != null
              ? DateFormat.yMMMd().add_jm().format(notification['createdAt'])
              : 'Unknown time',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        onTap: () {
          if (!isRead && notification['id'] != null) {
            _markNotificationAsRead(notification['id']);
          }
        },
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      color: Colors.blue.shade700,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                        Icons.person,
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
                            'Welcome, $_residentName!',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            'Manage your water usage and reports.',
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
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    child: ElasticIn(
                      duration: const Duration(milliseconds: 300),
                      child: FutureBuilder<double>(
                        future: _fetchTotalWaterConsumption(),
                        builder: (context, snapshot) {
                          String value = 'Loading...';
                          if (snapshot.hasData) {
                            value = '${snapshot.data!.toStringAsFixed(2)} m³';
                          } else if (snapshot.hasError) {
                            value = 'Error';
                          }
                          return _buildStatCard(
                            title: 'Water Consumption',
                            value: value,
                            description: 'Total usage recorded',
                            icon: Icons.water_drop,
                            color: Colors.blue.shade700,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElasticIn(
                      duration: const Duration(milliseconds: 300),
                      delay: const Duration(milliseconds: 100),
                      child: FutureBuilder<double>(
                        future: _fetchThisMonthConsumption(),
                        builder: (context, snapshot) {
                          String value = 'Loading...';
                          if (snapshot.hasData) {
                            value = '${snapshot.data!.toStringAsFixed(2)} m³';
                          } else if (snapshot.hasError) {
                            value = 'Error';
                          }
                          return _buildStatCard(
                            title: 'This Month Consumption',
                            value: value,
                            description: 'This month\'s usage',
                            icon: Icons.calendar_today,
                            color: Colors.blue.shade700,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildMonthlyUsageChart(),
            ),
            const SizedBox(height: 16),
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              delay: const Duration(milliseconds: 100),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _onSelectPage(ResidentPage.report);
                          },
                          icon: const Icon(Icons.report_problem_outlined),
                          label: Text(
                            'Report Issue',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            _onSelectPage(ResidentPage.billing);
                          },
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Text(
                            'View Bills',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyUsageChart() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchLastSixMonthsConsumption(),
      builder: (context, snapshot) {
        List<BarChartGroupData> barGroups = [];
        double maxY = 250.0;

        if (snapshot.hasData) {
          final months = snapshot.data!;
          maxY = months.fold(
                  0.0,
                  (max, month) =>
                      month['consumption'] > max ? month['consumption'] : max) *
              1.2;
          maxY = maxY < 50 ? 50 : maxY; // Ensure minimum maxY for visibility
          barGroups = months.asMap().entries.map((entry) {
            final index = entry.key;
            final month = entry.value;
            return _buildBarGroup(
                index, month['consumption'], month['monthName']);
          }).toList();
        } else if (snapshot.hasError) {
          barGroups =
              List.generate(6, (index) => _buildBarGroup(index, 0.0, 'Err'));
        }

        return Container(
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Water Consumption',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipMargin: 8,
                          getTooltipColor: (_) => Colors.white,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toStringAsFixed(0)} m³',
                              GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (!snapshot.hasData ||
                                  value >= snapshot.data!.length) {
                                return const SizedBox();
                              }
                              final monthName =
                                  snapshot.data![value.toInt()]['monthName'];
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4,
                                child: Text(
                                  monthName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: maxY / 5,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4,
                                child: Text(
                                  value.toInt().toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                      groupsSpace: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, String month) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF87CEEB),
              Color(0xFFE0F7FA),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 16,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(4),
          ),
        ),
      ],
    );
  }
}
