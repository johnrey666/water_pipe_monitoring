// ignore_for_file: unused_import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'auth/resident_login.dart';
import 'report_problem_page.dart';
import 'view_billing_page.dart';

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
  OverlayEntry? _notificationOverlay;
  String _residentName = 'Resident';
  String? _residentId;
  int _unreadNotifCount = 0;
  // Create page instances once and reuse them
  late final ReportProblemPage _reportPage;
  late final ViewBillingPage _billingPage;
  bool _pagesInitialized = false;
  // PageStorage bucket to preserve state
  final PageStorageBucket _bucket = PageStorageBucket();
  @override
  void initState() {
    super.initState();
    _fetchResidentName();
    _fetchUnreadNotifCount();
    // Initialize pages once
    if (!_pagesInitialized) {
      _reportPage = const ReportProblemPage();
      _billingPage = const ViewBillingPage();
      _pagesInitialized = true;
    }
  }

  Future<void> _fetchResidentName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Redirect to login if not logged in
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
            (route) => false,
          );
        });
        return;
      }
      if (mounted) {
        setState(() {
          _residentId = user.uid;
        });
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['fullName'] != null && mounted) {
        setState(() {
          _residentName = data['fullName'];
        });
      } else if (mounted) {
        setState(() {
          _residentName = 'Resident';
        });
      }
    } catch (e) {
      print('DEBUG: Error fetching resident name: $e');
      if (mounted) {
        setState(() {
          _residentName = 'Resident';
        });
      }
    }
  }

  Future<void> _fetchUnreadNotifCount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _unreadNotifCount = 0;
        });
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('residentId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();
      if (mounted) {
        setState(() {
          _unreadNotifCount = snapshot.docs.length;
        });
      }
    } catch (e) {
      print('DEBUG: Error fetching notification count: $e');
      if (mounted) {
        setState(() {
          _unreadNotifCount = 0;
        });
      }
    }
  }

  Future<double> _fetchTotalWaterConsumption() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0.0;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('consumption_history')
          .get();
      if (snapshot.docs.isEmpty) return 0.0;
      final totalConsumption = snapshot.docs.fold<double>(
        0.0,
        (sum, doc) => sum + (doc['cubicMeterUsed']?.toDouble() ?? 0.0),
      );
      return totalConsumption;
    } catch (e) {
      print('DEBUG: Error fetching total water consumption: $e');
      return 0.0;
    }
  }

  Future<double> _fetchThisMonthConsumption() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0.0;
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('consumption_history')
          .where('year', isEqualTo: currentYear)
          .where('month', isEqualTo: currentMonth)
          .get();
      final totalConsumption = snapshot.docs.fold<double>(
        0.0,
        (sum, doc) => sum + (doc['cubicMeterUsed']?.toDouble() ?? 0.0),
      );
      return totalConsumption;
    } catch (e) {
      print('DEBUG: Error fetching this month\'s consumption: $e');
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLastSixMonthsConsumption() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;
      final startDate = DateTime(currentYear, currentMonth - 5, 1);
      final endDate = DateTime(currentYear, currentMonth + 1, 1);
      final months = <Map<String, dynamic>>[];
      final dateFormat = DateFormat('MMM');
      for (int i = 0; i < 6; i++) {
        final targetDate = DateTime(currentYear, currentMonth - i, 1);
        final monthName = dateFormat.format(targetDate);
        months.add({
          'month': targetDate,
          'monthName': monthName,
          'consumption': 0.0,
        });
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('consumption_history')
          .where('periodStart',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('periodStart', isLessThan: Timestamp.fromDate(endDate))
          .get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final periodStart = (data['periodStart'] as Timestamp?)?.toDate();
        if (periodStart != null) {
          for (var month in months) {
            if (periodStart.year == month['month'].year &&
                periodStart.month == month['month'].month) {
              final consumption = data['cubicMeterUsed']?.toDouble() ?? 0.0;
              month['consumption'] += consumption;
            }
          }
        }
      }
      months.sort((a, b) => b['month'].compareTo(a['month']));
      return months;
    } catch (e) {
      print('DEBUG: Error fetching last six months consumption: $e');
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
    if (mounted) {
      _fetchResidentName();
      _fetchUnreadNotifCount();
      setState(() {});
    }
  }

  void _onSelectPage(ResidentPage page) {
    if (!mounted) return;
    if (_notificationOverlay != null) {
      _removeNotificationOverlay();
    }
    // Use microtask to avoid rebuild cycles
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _selectedPage = page;
        });
      }
    });
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchNotifications() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'unread': [], 'read': []};
      final unreadSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('residentId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();
      final readSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('residentId', isEqualTo: user.uid)
          .where('read', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();
      final unreadNotifications = unreadSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'status': data['status'],
          'month': data['month'],
          'amount': data['amount']?.toDouble(),
          'message': data['message'],
          'billId': data['billId'],
          'processedDate': (data['processedDate'] as Timestamp?)?.toDate(),
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'isRead': false,
        };
      }).toList();
      final readNotifications = readSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'status': data['status'],
          'month': data['month'],
          'amount': data['amount']?.toDouble(),
          'message': data['message'],
          'billId': data['billId'],
          'processedDate': (data['processedDate'] as Timestamp?)?.toDate(),
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'isRead': true,
        };
      }).toList();
      return {'unread': unreadNotifications, 'read': readNotifications};
    } catch (e) {
      print('DEBUG: Error fetching notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
      return {'unread': [], 'read': []};
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      _fetchUnreadNotifCount();
    } catch (e) {
      print('DEBUG: Error marking notification as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking notification as read: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchPaidBillDetails(
      String billId, String month) async {
    try {
      // Try to fetch from consumption_history for the month
      final monthDate = DateFormat('MMM yyyy').parse(month);
      final year = monthDate.year;
      final monthNum = monthDate.month;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_residentId)
          .collection('consumption_history')
          .where('year', isEqualTo: year)
          .where('month', isEqualTo: monthNum)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final periodStart = data['periodStart'] as Timestamp?;
        final cubicMeterUsed = data['cubicMeterUsed']?.toDouble() ?? 0.0;
        // Fetch payment for amount
        final paymentSnapshot = await FirebaseFirestore.instance
            .collection('payments')
            .where('residentId', isEqualTo: _residentId)
            .where('billId', isEqualTo: billId)
            .where('status', isEqualTo: 'approved')
            .limit(1)
            .get();
        if (paymentSnapshot.docs.isNotEmpty) {
          final paymentData = paymentSnapshot.docs.first.data();
          final amount = paymentData['billAmount']?.toDouble() ?? 0.0;
          // Fetch user data for name, address, etc.
          final userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(_residentId)
              .get();
          final userData = userSnapshot.data() ?? {};
          // Fetch current reading from meter_readings
          final meterSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(_residentId)
              .collection('meter_readings')
              .doc('latest')
              .get();
          final currentReading = meterSnapshot.exists
              ? (meterSnapshot.data()!['currentConsumedWaterMeter'] as num?)
                      ?.toDouble() ??
                  0.0
              : 0.0;
          final previousReading = currentReading - cubicMeterUsed;
          final processedDate =
              (paymentData['processedDate'] as Timestamp?)?.toDate() ??
                  DateTime.now();
          return {
            'fullName': userData['fullName'] ?? 'N/A',
            'address': userData['address'] ?? 'N/A',
            'contactNumber': userData['contactNumber'] ?? 'N/A',
            'meterNumber': userData['meterNumber'] ?? 'N/A',
            'purok': userData['purok'] ?? 'PUROK 1',
            'periodStart': periodStart?.toDate(),
            'previousReading': previousReading,
            'currentReading': currentReading,
            'cubicMeterUsed': cubicMeterUsed,
            'currentMonthBill': amount,
            'processedDate': processedDate,
            'status': 'PAID',
          };
        }
      }
      return null;
    } catch (e) {
      print('Error fetching paid bill details: $e');
      return null;
    }
  }

  void _showPaidBillModal(Map<String, dynamic> notification) async {
    if (notification['type'] != 'payment' ||
        notification['status'] != 'approved') return;
    final billDetails = await _fetchPaidBillDetails(
        notification['billId'], notification['month']);
    if (billDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load bill details.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: _PaidBillDialog(billDetails: billDetails),
      ),
    );
  }

  void _showNotificationOverlay() {
    if (_notificationOverlay != null) {
      _removeNotificationOverlay();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _notificationButtonKey.currentContext == null) return;
      try {
        final RenderBox renderBox = _notificationButtonKey.currentContext!
            .findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final screenSize = MediaQuery.of(context).size;
        _notificationOverlay = OverlayEntry(
          builder: (context) {
            return Positioned(
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
                    onMarkAsRead: _markNotificationAsRead,
                    onShowPaidBill: (notification) {
                      _removeNotificationOverlay();
                      _showPaidBillModal(notification);
                    },
                    onReportTap: () {
                      _removeNotificationOverlay();
                      Future.microtask(() {
                        _onSelectPage(ResidentPage.report);
                      });
                    },
                    fetchNotifications: _fetchNotifications,
                    onClose: _removeNotificationOverlay,
                  ),
                ),
              ),
            );
          },
        );
        if (mounted) {
          Overlay.of(context).insert(_notificationOverlay!);
        }
      } catch (e) {
        print('Error showing notification overlay: $e');
        _removeNotificationOverlay();
      }
    });
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  @override
  void dispose() {
    _removeNotificationOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF87CEEB)),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Auth error: ${snapshot.error}',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
          );
        }
        if (snapshot.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
              (route) => false,
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildHomeContent(context);
      },
    );
  }

  Widget _buildHomeContent(BuildContext context) {
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
                    if (!mounted) return;
                    if (_notificationOverlay == null) {
                      // Use Future.delayed with a minimal delay to ensure UI is ready
                      Future.delayed(const Duration(milliseconds: 50), () {
                        if (mounted && _notificationOverlay == null) {
                          // Add it to the next frame to ensure build is complete
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _notificationOverlay == null) {
                              _showNotificationOverlay();
                            }
                          });
                        }
                      });
                    } else {
                      _removeNotificationOverlay();
                    }
                  },
                ),
                if (_unreadNotifCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadNotifCount',
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
        body: PageStorage(
          bucket: _bucket,
          child: Stack(
            children: [
              Offstage(
                offstage: _selectedPage != ResidentPage.home,
                child: TickerMode(
                  enabled: _selectedPage == ResidentPage.home,
                  child: _buildDashboard(),
                ),
              ),
              Offstage(
                offstage: _selectedPage != ResidentPage.report,
                child: TickerMode(
                  enabled: _selectedPage == ResidentPage.report,
                  child: _reportPage,
                ),
              ),
              Offstage(
                offstage: _selectedPage != ResidentPage.billing,
                child: TickerMode(
                  enabled: _selectedPage == ResidentPage.billing,
                  child: _billingPage,
                ),
              ),
            ],
          ),
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
            Navigator.of(context).pop(); // Close drawer
            _onSelectPage(page); // Then switch page
          },
        ),
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
              height: 160,
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
                            title: 'Total Water Consumption',
                            value: value,
                            description: 'All-time usage',
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
          maxY = maxY < 50 ? 50 : maxY;
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
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
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

// Notification classes remain the same...
class NotificationDropdown extends StatefulWidget {
  final Function(String) onMarkAsRead;
  final Function(Map<String, dynamic>) onShowPaidBill;
  final VoidCallback? onReportTap;
  final Future<Map<String, List<Map<String, dynamic>>>> Function()
      fetchNotifications;
  final VoidCallback onClose;
  const NotificationDropdown({
    super.key,
    required this.onMarkAsRead,
    required this.onShowPaidBill,
    this.onReportTap,
    required this.fetchNotifications,
    required this.onClose,
  });
  @override
  State<NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown>
    with AutomaticKeepAliveClientMixin {
  int _page = 0;
  static const int _itemsPerPage = 3;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: widget.fetchNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF87CEEB)),
              ),
            ),
          );
        }
        final notificationsData = snapshot.data ?? {'unread': [], 'read': []};
        final unread = notificationsData['unread']!;
        final read = notificationsData['read']!;
        final allNotifications = [...unread, ...read];
        if (allNotifications.isEmpty) {
          return const SizedBox(
            height: 50,
            child: Center(child: Text('No notifications')),
          );
        }
        allNotifications.sort((a, b) =>
            (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
        final totalPages = (allNotifications.length / _itemsPerPage).ceil();
        final currentItems = allNotifications
            .skip(_page * _itemsPerPage)
            .take(_itemsPerPage)
            .toList();
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Notifications',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              ...currentItems.map((notif) =>
                  _buildNotificationItem(context, notif, notif['isRead'])),
              if (totalPages > 1)
                _buildPaginationRow(
                  currentPage: _page,
                  totalPages: totalPages,
                  onPrev: () => setState(
                      () => _page = (_page - 1).clamp(0, totalPages - 1)),
                  onNext: () => setState(
                      () => _page = (_page + 1).clamp(0, totalPages - 1)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, Map<String, dynamic> notification, bool isRead) {
    String text;
    IconData icon;
    Color iconColor;
    int titleMaxLines = 1;
    if (notification['type'] == 'report_status') {
      text = notification['message'] ?? 'Issue fixed';
      icon = Icons.check_circle;
      iconColor = isRead ? Colors.grey[400]! : Colors.green;
      titleMaxLines = 2;
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
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
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
            widget.onMarkAsRead(notification['id']);
          }
          if (notification['type'] == 'payment' &&
              notification['status'] == 'approved') {
            widget.onShowPaidBill(notification);
          } else if (notification['type'] == 'report_status') {
            widget.onReportTap?.call();
          } else {
            widget.onClose();
          }
        },
      ),
    );
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

class _PaidBillDialog extends StatefulWidget {
  final Map<String, dynamic> billDetails;
  const _PaidBillDialog({required this.billDetails});
  @override
  State<_PaidBillDialog> createState() => _PaidBillDialogState();
}

class _PaidBillDialogState extends State<_PaidBillDialog> {
  bool _showRates = false;
  final GlobalKey _boundaryKey = GlobalKey();
  Future<void> _downloadReceipt() async {
    try {
      final RenderRepaintBoundary boundary = _boundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: 'paid_receipt_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        if (result['isSuccess']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt saved to gallery successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save receipt to gallery.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading receipt: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.billDetails['fullName'] ?? 'N/A';
    final address = widget.billDetails['address'] ?? 'N/A';
    final contactNumber = widget.billDetails['contactNumber'] ?? 'N/A';
    final meterNumber = widget.billDetails['meterNumber'] ?? 'N/A';
    final purok = widget.billDetails['purok'] ?? 'PUROK 1';
    final periodStart = widget.billDetails['periodStart'] as DateTime?;
    final previousReading =
        widget.billDetails['previousReading']?.toDouble() ?? 0.0;
    final currentReading =
        widget.billDetails['currentReading']?.toDouble() ?? 0.0;
    final cubicMeterUsed =
        widget.billDetails['cubicMeterUsed']?.toDouble() ?? 0.0;
    final amount = widget.billDetails['currentMonthBill']?.toDouble() ?? 0.0;
    final processedDate = widget.billDetails['processedDate'] as DateTime?;
    final formattedPeriodStart = periodStart != null
        ? DateFormat('MM-dd-yyyy').format(periodStart)
        : 'N/A';
    final formattedProcessedDate = processedDate != null
        ? DateFormat.yMMMd().format(processedDate)
        : DateFormat.yMMMd().format(DateTime.now());
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFEDF7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Text(
                  'PAID',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Image.asset('assets/images/icon.png',
                                    height: 36),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'San Jose Water Services',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4A90E2),
                                      ),
                                    ),
                                    Text(
                                      purok,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'WATER BILL STATEMENT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _dashedDivider(),
                        _receiptRow('Name', fullName),
                        _receiptRow('Address', address),
                        _receiptRow('Contact', contactNumber),
                        _receiptRow('Meter No.', meterNumber),
                        _receiptRow(
                            'Billing Period Start', formattedPeriodStart),
                        _receiptRow('Issue Date', formattedProcessedDate),
                        _dashedDivider(),
                        _receiptRow('Previous Reading',
                            '${previousReading.toStringAsFixed(2)} m³'),
                        _receiptRow('Current Reading',
                            '${currentReading.toStringAsFixed(2)} m³'),
                        _receiptRow('Cubic Meter Used',
                            '${cubicMeterUsed.toStringAsFixed(2)} m³'),
                        _dashedDivider(),
                        _receiptRow(
                            'Amount Paid', '₱${amount.toStringAsFixed(2)}',
                            valueColor: Colors.green,
                            isBold: true,
                            fontSize: 13),
                        const SizedBox(height: 12),
                        // Rate Information
                        GestureDetector(
                          onTap: () => setState(() => _showRates = !_showRates),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Rate Information',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A90E2),
                                  ),
                                ),
                                Icon(
                                  _showRates
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                  color: const Color(0xFF4A90E2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.grey[200]!, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _rateRow('Residential',
                                    'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                                const SizedBox(height: 6),
                                _rateRow('Commercial',
                                    'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                                const SizedBox(height: 6),
                                _rateRow('Non Residence',
                                    'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                                const SizedBox(height: 6),
                                _rateRow('Industrial',
                                    'Min 10 m³ = 100.00 PHP\nExceed = 15.00 PHP/m³'),
                              ],
                            ),
                          ),
                          crossFadeState: _showRates
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 400),
                          sizeCurve: Curves.easeInOut,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Thank you for your timely payment!',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.green,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        // Payment Status
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Payment Approved',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const Text(
                                      'Your payment has been confirmed.',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _downloadReceipt,
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        'Download Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashedDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: List.generate(
            30,
            (i) => Expanded(
              child: Container(
                height: 1,
                color: i.isEven ? Colors.grey[300] : Colors.transparent,
              ),
            ),
          ),
        ),
      );
  Widget _receiptRow(String label, String value,
      {Color? valueColor, bool isBold = false, double fontSize = 11}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: fontSize,
                color: valueColor ?? Colors.grey[700],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateRow(String category, String details) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              details,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      );
}
