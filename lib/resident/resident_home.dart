// ignore_for_file: unused_import
import 'dart:async';
import 'dart:convert';
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
import 'transaction_history_page.dart';

enum ResidentPage { home, report, billing, transactionHistory }

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage>
    with TickerProviderStateMixin {
  ResidentPage _selectedPage = ResidentPage.home;
  String _residentName = 'Resident';
  String? _residentId;
  int _unreadNotifCount = 0;
  // ignore: unused_field
  double _currentBillAmount = 0.0;
  // ignore: unused_field
  bool _hasPendingPayment = false;
  String _meterNumber = 'N/A';
  String _purok = 'N/A';
  String _address = 'N/A';
  // Create page instances once and reuse them
  late final ReportProblemPage _reportPage;
  late final ViewBillingPage _billingPage;
  bool _pagesInitialized = false;
  // PageStorage bucket to preserve state
  final PageStorageBucket _bucket = PageStorageBucket();
  // Stream subscription for new bills
  StreamSubscription<QuerySnapshot>? _billsSubscription;

  // Cached futures to prevent refetching on every rebuild
  late Future<double> _totalConsumptionFuture;
  late Future<double> _thisMonthConsumptionFuture;
  late Future<double> _averageConsumptionFuture;
  late Future<List<Map<String, dynamic>>> _lastSixMonthsFuture;

  // Ads rotation variables - moved to separate stateful widget to prevent reloads
  late GlobalKey<_DashboardContentState> _dashboardContentKey;

  @override
  void initState() {
    super.initState();
    _dashboardContentKey = GlobalKey<_DashboardContentState>();
    _totalConsumptionFuture = _fetchTotalWaterConsumption();
    _thisMonthConsumptionFuture = _fetchThisMonthConsumption();
    _averageConsumptionFuture = _fetchAverageMonthlyConsumption();
    _lastSixMonthsFuture = _fetchLastSixMonthsConsumption();
    _fetchResidentData();
    _fetchUnreadNotifCount();
    _setupBillNotificationListener();
    _fetchCurrentBill();
    _fetchUserProfile();
    // Initialize pages that don't need residentId
    if (!_pagesInitialized) {
      _reportPage = const ReportProblemPage();
      _billingPage = const ViewBillingPage();
      _pagesInitialized = true;
    }
  }

  @override
  void dispose() {
    _billsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _meterNumber = data['meterNumber']?.toString() ?? 'N/A';
          _purok = data['purok']?.toString() ?? 'N/A';
          _address = data['address']?.toString() ?? 'N/A';
        });
      }
    } catch (e) {
      print('DEBUG: Error fetching user profile: $e');
    }
  }

  Future<void> _fetchCurrentBill() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bills')
          .where('year', isEqualTo: currentYear)
          .where('month', isEqualTo: currentMonth)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final bill = snapshot.docs.first.data();
        final amount = bill['currentMonthBill']?.toDouble() ?? 0.0;
        final status = bill['status']?.toString() ?? 'unpaid';
        if (mounted) {
          setState(() {
            _currentBillAmount = amount;
            _hasPendingPayment = status == 'unpaid';
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error fetching current bill: $e');
    }
  }

  Future<void> _setupBillNotificationListener() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _residentId = user.uid;
    });
    // Listen for new bills
    _billsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_residentId)
        .collection('bills')
        .orderBy('issueDate', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final bill = snapshot.docs.first;
        final billData = bill.data();
        final billTimestamp = billData['issueDate'] as Timestamp?;
        if (billTimestamp != null) {
          final billTime = billTimestamp.toDate();
          final now = DateTime.now();
          // Check if bill was created within the last 5 minutes (to avoid duplicate notifications)
          if (now.difference(billTime).inMinutes < 5) {
            // Check if notification already exists for this bill
            final existingNotif = await FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: _residentId)
                .where('billId', isEqualTo: bill.id)
                .where('type', isEqualTo: 'new_bill')
                .limit(1)
                .get();
            if (existingNotif.docs.isEmpty) {
              // Create notification for new bill
              await _createNewBillNotification(bill.id, billData);
            }
          }
        }
      }
    });
  }

  Future<void> _createNewBillNotification(
      String billId, Map<String, dynamic> billData) async {
    try {
      final periodStart = (billData['periodStart'] as Timestamp?)?.toDate();
      final month = periodStart != null
          ? DateFormat('MMM yyyy').format(periodStart)
          : 'Current Month';
      final amount = billData['currentMonthBill']?.toDouble() ?? 0.0;
      final notificationData = {
        'userId': _residentId!,
        'type': 'new_bill',
        'title': 'New Water Bill Generated',
        'message':
            'A new water bill of ₱${amount.toStringAsFixed(2)} has been generated for $month.',
        'billId': billId,
        'month': month,
        'amount': amount,
        'status': 'unread',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);
      // Update notification count
      _fetchUnreadNotifCount();
    } catch (e) {
      print('Error creating new bill notification: $e');
    }
  }

  Future<void> _fetchResidentData() async {
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
          .where('userId', isEqualTo: user.uid)
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

  Future<double> _fetchAverageMonthlyConsumption() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0.0;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('consumption_history')
          .limit(12)
          .get();
      if (snapshot.docs.isEmpty) return 0.0;
      final totalConsumption = snapshot.docs.fold<double>(
        0.0,
        (sum, doc) => sum + (doc['cubicMeterUsed']?.toDouble() ?? 0.0),
      );
      return totalConsumption / snapshot.docs.length;
    } catch (e) {
      print('DEBUG: Error fetching average consumption: $e');
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

  Future<Map<String, dynamic>> _fetchCurrentMonthBillDetails() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'amount': 0.0, 'status': 'No bill'};
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bills')
          .where('year', isEqualTo: currentYear)
          .where('month', isEqualTo: currentMonth)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final bill = snapshot.docs.first.data();
        return {
          'amount': bill['currentMonthBill']?.toDouble() ?? 0.0,
          'status': bill['status']?.toString() ?? 'unpaid',
          'dueDate': (bill['dueDate'] as Timestamp?)?.toDate(),
        };
      }
      return {'amount': 0.0, 'status': 'No bill'};
    } catch (e) {
      print('DEBUG: Error fetching current month bill: $e');
      return {'amount': 0.0, 'status': 'Error'};
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
                color: const Color(0xFF00BCD4),
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
      setState(() {
        _totalConsumptionFuture = _fetchTotalWaterConsumption();
        _thisMonthConsumptionFuture = _fetchThisMonthConsumption();
        _averageConsumptionFuture = _fetchAverageMonthlyConsumption();
        _lastSixMonthsFuture = _fetchLastSixMonthsConsumption();
      });
      _fetchResidentData();
      _fetchUnreadNotifCount();
      _fetchCurrentBill();
      _fetchUserProfile();
    }
  }

  void _onSelectPage(ResidentPage page) {
    if (!mounted) return;
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
      // Fetch all notifications for this user
      final unreadSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      final readSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      final unreadNotifications = unreadSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'reportId': data['reportId'],
          'assessment': data['assessment'],
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
          'billId': data['billId'],
          'status': data['status'],
          'month': data['month'],
          'amount': data['amount']?.toDouble(),
          'rejectionReason': data['rejectionReason'],
          'receiptImage': data['receiptImage'],
          'isRead': false,
        };
      }).toList();
      final readNotifications = readSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'reportId': data['reportId'],
          'assessment': data['assessment'],
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
          'billId': data['billId'],
          'status': data['status'],
          'month': data['month'],
          'amount': data['amount']?.toDouble(),
          'rejectionReason': data['rejectionReason'],
          'receiptImage': data['receiptImage'],
          'isRead': true,
        };
      }).toList();
      return {'unread': unreadNotifications, 'read': readNotifications};
    } catch (e) {
      print('DEBUG: Error fetching notifications: $e');
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
    }
  }

  // FIXED: Improved notification tap handler to prevent app reload
  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read if unread - do this asynchronously without waiting
    if (!notification['isRead'] && notification['id'] != null) {
      Future.microtask(() => _markNotificationAsRead(notification['id']));
    }
    // Handle different notification types WITHOUT calling setState
    final type = notification['type'];
    if (type == 'new_bill' || type == 'bill_updated') {
      // For bill notifications, navigate to billing page WITHOUT setState
      if (_selectedPage != ResidentPage.billing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedPage = ResidentPage.billing;
            });
          }
        });
      }

      // Show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notification['message'] ?? 'New bill available'),
            backgroundColor: const Color(0xFF00BCD4),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (type == 'payment') {
      // Handle payment notifications
      if (notification['status'] == 'approved') {
        _showPaidBillModal(notification);
      } else if (notification['status'] == 'rejected') {
        _showRejectedPaymentModal(notification);
      } else {
        // For pending payments, just show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(notification['message'] ?? 'Payment notification'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      // For other notifications, show a snackbar with the message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notification['message'] ?? 'Notification')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchPaidBillDetails(
      String billId, String month) async {
    try {
      final monthDate = DateFormat('MMM yyyy').parse(month);
      final year = monthDate.year;
      final monthNum = monthDate.month;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_residentId!)
          .collection('consumption_history')
          .where('year', isEqualTo: year)
          .where('month', isEqualTo: monthNum)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final periodStart = (data['periodStart'] as Timestamp?)?.toDate();
        final cubicMeterUsed = data['cubicMeterUsed']?.toDouble() ?? 0.0;
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
          final userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(_residentId)
              .get();
          final userData = userSnapshot.data() ?? {};
          final meterSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(_residentId!)
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
            'periodStart': periodStart,
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

  Future<Map<String, dynamic>?> _fetchRejectedPaymentDetails(String billId,
      String month, String? rejectionReason, String? receiptImage) async {
    try {
      final monthDate = DateFormat('MMM yyyy').parse(month);
      final year = monthDate.year;
      final monthNum = monthDate.month;
      // Try to get bill details from consumption history
      final consumptionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_residentId!)
          .collection('consumption_history')
          .where('year', isEqualTo: year)
          .where('month', isEqualTo: monthNum)
          .limit(1)
          .get();
      double cubicMeterUsed = 0.0;
      DateTime? periodStart;
      if (consumptionSnapshot.docs.isNotEmpty) {
        final data = consumptionSnapshot.docs.first.data();
        final periodStartTimestamp = data['periodStart'] as Timestamp?;
        periodStart = periodStartTimestamp?.toDate();
        cubicMeterUsed = data['cubicMeterUsed']?.toDouble() ?? 0.0;
      }
      // Get payment details
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('residentId', isEqualTo: _residentId)
          .where('billId', isEqualTo: billId)
          .where('status', isEqualTo: 'rejected')
          .limit(1)
          .get();
      double amount = 0.0;
      DateTime? processedDate;
      if (paymentSnapshot.docs.isNotEmpty) {
        final paymentData = paymentSnapshot.docs.first.data();
        amount = paymentData['billAmount']?.toDouble() ?? 0.0;
        final processedDateTimestamp =
            paymentData['processedDate'] as Timestamp?;
        processedDate = processedDateTimestamp?.toDate();
      }
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_residentId!)
          .get();
      final userData = userSnapshot.data() ?? {};
      final meterSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_residentId!)
          .collection('meter_readings')
          .doc('latest')
          .get();
      final currentReading = meterSnapshot.exists
          ? (meterSnapshot.data()!['currentConsumedWaterMeter'] as num?)
                  ?.toDouble() ??
              0.0
          : 0.0;
      final previousReading = currentReading - cubicMeterUsed;
      return {
        'fullName': userData['fullName'] ?? 'N/A',
        'address': userData['address'] ?? 'N/A',
        'contactNumber': userData['contactNumber'] ?? 'N/A',
        'meterNumber': userData['meterNumber'] ?? 'N/A',
        'purok': userData['purok'] ?? 'PUROK 1',
        'periodStart': periodStart,
        'previousReading': previousReading,
        'currentReading': currentReading,
        'cubicMeterUsed': cubicMeterUsed,
        'currentMonthBill': amount,
        'processedDate': processedDate ?? DateTime.now(),
        'status': 'REJECTED',
        'rejectionReason': rejectionReason ?? 'No reason provided',
        'receiptImage': receiptImage,
      };
    } catch (e) {
      print('Error fetching rejected payment details: $e');
      return null;
    }
  }

  void _showPaidBillModal(Map<String, dynamic> notification) async {
    if (notification['type'] != 'payment' ||
        notification['status'] != 'approved') return;
    final billDetails = await _fetchPaidBillDetails(
        notification['billId'], notification['month']);
    if (billDetails == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load bill details.')),
        );
      }
      return;
    }
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _PaidBillDialog(billDetails: billDetails),
        ),
      );
    }
  }

  void _showRejectedPaymentModal(Map<String, dynamic> notification) async {
    if (notification['type'] != 'payment' ||
        notification['status'] != 'rejected') return;
    final paymentDetails = await _fetchRejectedPaymentDetails(
        notification['billId'],
        notification['month'],
        notification['rejectionReason'],
        notification['receiptImage']);
    if (paymentDetails == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load payment details.')),
        );
      }
      return;
    }
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _RejectedPaymentDialog(paymentDetails: paymentDetails),
        ),
      );
    }
  }

  // FIXED: Use showMenu instead of PopupMenuButton to avoid reloads
  void _showNotificationDropdown() async {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    // Fetch notifications first
    final notifications = await _fetchNotifications();

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 200, // Left position
        position.dy + 50, // Top position (below the button)
        position.dx + 150, // Right position
        position.dy + 450, // Bottom position
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      constraints: const BoxConstraints(
        minWidth: 350,
        maxWidth: 350,
        minHeight: 200,
        maxHeight: 400,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 350,
            height: 400,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: NotificationDropdown(
                notificationsData: notifications,
                onNotificationTap: (notification) {
                  Navigator.of(context).pop();
                  _handleNotificationTap(notification);
                },
                onMarkAsRead: _markNotificationAsRead,
                onClose: () => Navigator.of(context).pop(),
                onRefreshCount: _fetchUnreadNotifCount,
                fetchNotifications: _fetchNotifications,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // NEW: Water droplet loading screen
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WaterDropletLoading(),
                  const SizedBox(height: 30),
                  Text(
                    'Loading your dashboard...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF00BCD4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please wait a moment',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
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
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WaterDropletLoading(),
                  const SizedBox(height: 30),
                  Text(
                    'Redirecting to login...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF00BCD4),
                    ),
                  ),
                ],
              ),
            ),
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
        backgroundColor: const Color(0xFFE0F7FA), // Aqua blue background
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            _getAppBarTitle(),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF00BCD4), // Aqua blue text
            ),
          ),
          elevation: 2,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF00BCD4)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            // Simple IconButton with overlay dropdown
            Stack(
              children: [
                IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE0F7FA), // Aqua blue
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF00BCD4),
                        size: 24,
                      ),
                    ),
                  ),
                  onPressed: () {
                    if (!mounted) return;
                    _showNotificationDropdown();
                  },
                ),
                if (_unreadNotifCount > 0)
                  Positioned(
                    right: 8,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
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
                        Color(0xFF00BCD4), // Aqua blue
                        Color(0xFF4DD0E1), // Lighter aqua blue
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
                            size: 36, color: Color(0xFF00BCD4)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome!',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _residentName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
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
                      _buildDrawerItem(
                        icon: Icons.history_outlined,
                        title: 'Transaction History',
                        page: ResidentPage.transactionHistory,
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
                  child: DashboardContent(
                    key: _dashboardContentKey,
                    residentName: _residentName,
                    address: _address,
                    purok: _purok,
                    meterNumber: _meterNumber,
                    totalConsumptionFuture: _totalConsumptionFuture,
                    thisMonthConsumptionFuture: _thisMonthConsumptionFuture,
                    averageConsumptionFuture: _averageConsumptionFuture,
                    lastSixMonthsFuture: _lastSixMonthsFuture,
                    refreshDashboard: _refreshDashboard,
                  ),
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
              Offstage(
                offstage: _selectedPage != ResidentPage.transactionHistory,
                child: TickerMode(
                  enabled: _selectedPage == ResidentPage.transactionHistory,
                  // FIXED: Create TransactionHistoryPage on demand with the residentId
                  child: _residentId != null && _residentId!.isNotEmpty
                      ? TransactionHistoryPage(residentId: _residentId!)
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              WaterDropletLoading(size: 40),
                              const SizedBox(height: 16),
                              Text(
                                'Loading transaction history...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: const Color(0xFF00BCD4),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedPage) {
      case ResidentPage.home:
        return 'Resident Dashboard';
      case ResidentPage.report:
        return 'Report Problem';
      case ResidentPage.billing:
        return 'View Billing';
      case ResidentPage.transactionHistory:
        return 'Transaction History';
      default:
        return 'Resident';
    }
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
        color: isSelected ? const Color(0xFFE0F7FA) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color:
                isSelected ? const Color(0xFF00BCD4) : const Color(0xFF00BCD4),
            size: 24,
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? const Color(0xFF00BCD4)
                  : const Color(0xFF00BCD4),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          selected: isSelected,
          onTap: () {
            Navigator.of(context).pop();
            _onSelectPage(page);
          },
        ),
      ),
    );
  }
}

// NEW: DashboardContent as a separate StatefulWidget to preserve ad state
class DashboardContent extends StatefulWidget {
  final String residentName;
  final String address;
  final String purok;
  final String meterNumber;
  final Future<double> totalConsumptionFuture;
  final Future<double> thisMonthConsumptionFuture;
  final Future<double> averageConsumptionFuture;
  final Future<List<Map<String, dynamic>>> lastSixMonthsFuture;
  final Future<void> Function() refreshDashboard;

  const DashboardContent({
    super.key,
    required this.residentName,
    required this.address,
    required this.purok,
    required this.meterNumber,
    required this.totalConsumptionFuture,
    required this.thisMonthConsumptionFuture,
    required this.averageConsumptionFuture,
    required this.lastSixMonthsFuture,
    required this.refreshDashboard,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent>
    with SingleTickerProviderStateMixin {
  // Ads rotation variables
  final List<String> _adImages = [
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1562157873-818bc0726f68?w-800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1562077981-4d7eafd8d4b0?w-800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&auto=format&fit=crop',
  ];
  final List<String> _adTitles = [
    'Save Water, Save Money!',
    'Conserve Water Today',
    'Smart Water Usage Tips',
    'Fix Leaks, Save Resources',
  ];
  final List<String> _adSubTitles = [
    'Learn how to reduce your water bill by 20%',
    'Check our water conservation guide',
    'Get free water-saving devices',
    'Detect and repair leaks efficiently',
  ];
  int _currentAdIndex = 0;
  late Timer _adRotateTimer;
  late AnimationController _adController;
  late Animation<double> _adFadeAnimation;

  @override
  void initState() {
    super.initState();
    _adController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _adFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _adController,
        curve: Curves.easeInOut,
      ),
    );

    // Start ad rotation timer
    _startAdRotationTimer();
  }

  void _startAdRotationTimer() {
    _adRotateTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _currentAdIndex = (_currentAdIndex + 1) % _adImages.length;
        });
        // Start fade animation
        _adController.reset();
        _adController.forward();
      }
    });
  }

  @override
  void dispose() {
    _adRotateTimer.cancel();
    _adController.dispose();
    super.dispose();
  }

  void _nextAd() {
    if (mounted) {
      setState(() {
        _currentAdIndex = (_currentAdIndex + 1) % _adImages.length;
      });
      _adController.reset();
      _adController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.refreshDashboard,
      color: const Color(0xFF00BCD4),
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card with User Info
                  FadeInDown(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE0F7FA),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFE0F7FA),
                            child: Icon(
                              Icons.person,
                              color: const Color(0xFF00BCD4),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${widget.residentName}!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF00BCD4),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  widget.address,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF4DD0E1),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F7FA),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF00BCD4),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  widget.purok,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF00BCD4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Meter: ${widget.meterNumber}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: const Color(0xFF4DD0E1),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Ad Banner Section - Fixed overflow
                  FadeInLeft(
                    duration: const Duration(milliseconds: 400),
                    child: _buildAdBanner(constraints),
                  ),

                  const SizedBox(height: 16),

                  // Water Conservation Reminder (Replaced Daily Water Challenge)
                  FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: _buildWaterConservationReminder(),
                  ),

                  const SizedBox(height: 16),

                  // Quick Stats Row - Made responsive
                  SizedBox(
                    height: constraints.maxWidth < 600 ? 140 : 130,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElasticIn(
                            duration: const Duration(milliseconds: 300),
                            child: FutureBuilder<double>(
                              future: widget.totalConsumptionFuture,
                              builder: (context, snapshot) {
                                String value = 'Loading...';
                                if (snapshot.hasData) {
                                  value =
                                      '${snapshot.data!.toStringAsFixed(1)} m³';
                                } else if (snapshot.hasError) {
                                  value = 'Error';
                                }
                                return _buildStatCard(
                                  title: 'Total Consumption',
                                  value: value,
                                  subtitle: 'All-time usage',
                                  icon: Icons.water_drop,
                                  color: const Color(0xFF00BCD4),
                                  constraints: constraints,
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
                              future: widget.thisMonthConsumptionFuture,
                              builder: (context, snapshot) {
                                String value = 'Loading...';
                                if (snapshot.hasData) {
                                  value =
                                      '${snapshot.data!.toStringAsFixed(1)} m³';
                                } else if (snapshot.hasError) {
                                  value = 'Error';
                                }
                                return _buildStatCard(
                                  title: 'This Month',
                                  value: value,
                                  subtitle: 'Current usage',
                                  icon: Icons.calendar_today,
                                  color: const Color(0xFF4DD0E1),
                                  constraints: constraints,
                                );
                              },
                            ),
                          ),
                        ),
                        if (constraints.maxWidth > 400) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElasticIn(
                              duration: const Duration(milliseconds: 300),
                              delay: const Duration(milliseconds: 200),
                              child: FutureBuilder<double>(
                                future: widget.averageConsumptionFuture,
                                builder: (context, snapshot) {
                                  String value = 'Loading...';
                                  if (snapshot.hasData) {
                                    value =
                                        '${snapshot.data!.toStringAsFixed(1)} m³';
                                  } else if (snapshot.hasError) {
                                    value = 'Error';
                                  }
                                  return _buildStatCard(
                                    title: 'Monthly Avg',
                                    value: value,
                                    subtitle: 'Average usage',
                                    icon: Icons.trending_up,
                                    color: const Color(0xFF26C6DA),
                                    constraints: constraints,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Show average consumption as separate card on small screens
                  if (constraints.maxWidth <= 400) ...[
                    const SizedBox(height: 12),
                    ElasticIn(
                      duration: const Duration(milliseconds: 300),
                      delay: const Duration(milliseconds: 200),
                      child: FutureBuilder<double>(
                        future: widget.averageConsumptionFuture,
                        builder: (context, snapshot) {
                          String value = 'Loading...';
                          if (snapshot.hasData) {
                            value = '${snapshot.data!.toStringAsFixed(1)} m³';
                          } else if (snapshot.hasError) {
                            value = 'Error';
                          }
                          return _buildStatCard(
                            title: 'Monthly Average',
                            value: value,
                            subtitle: 'Average monthly usage',
                            icon: Icons.trending_up,
                            color: const Color(0xFF26C6DA),
                            constraints: constraints,
                            isFullWidth: true,
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Monthly Usage Chart
                  FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: _buildMonthlyUsageChart(constraints),
                  ),
                  const SizedBox(height: 16),
                  // Water Conservation Tips - Aqua Blue Version
                  FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE0F7FA),
                            Color(0xFFB2EBF2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF00BCD4),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BCD4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.eco,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '💧 Water Conservation Tips',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00838F),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildTipChip(
                                '🚿 Short showers',
                                'Save 10L per minute!',
                                const Color(0xFF00BCD4),
                              ),
                              _buildTipChip(
                                '💧 Fix leaks',
                                'Save 90L per day!',
                                const Color(0xFF4DD0E1),
                              ),
                              _buildTipChip(
                                '🌱 Smart watering',
                                'Save 50% water!',
                                const Color(0xFF26C6DA),
                              ),
                              _buildTipChip(
                                '🚰 Turn off tap',
                                'Save 6L per minute!',
                                const Color(0xFF80DEEA),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Water Usage Insights (Replaced Community Leaderboard)
                  FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE0F7FA),
                            Color(0xFFB2EBF2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF00BCD4),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.insights,
                                  color: Color(0xFF00BCD4)),
                              const SizedBox(width: 8),
                              Text(
                                '📈 Water Usage Insights',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00BCD4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildUsageInsightItem(
                            '📊 Your Usage Pattern',
                            'Your consumption is 15% lower than community average',
                            Icons.trending_down,
                            const Color(0xFF4CAF50),
                          ),
                          const SizedBox(height: 8),
                          _buildUsageInsightItem(
                            '💰 Potential Savings',
                            'Reducing shower time by 2 mins saves ₱150/month',
                            Icons.savings,
                            const Color(0xFFFF9800),
                          ),
                          const SizedBox(height: 8),
                          _buildUsageInsightItem(
                            '🌍 Environmental Impact',
                            'You\'ve saved 2,500L water this year',
                            Icons.eco,
                            const Color(0xFF00BCD4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Important Contacts with Aqua Blue Design
                  FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    delay: const Duration(milliseconds: 400),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Color(0xFFE0F7FA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFB2EBF2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.contacts,
                                  color: Color(0xFF00BCD4)),
                              const SizedBox(width: 8),
                              Text(
                                '📞 Quick Contacts',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00BCD4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildContactItem(
                            icon: Icons.emergency,
                            title: '24/7 Emergency',
                            subtitle: '(0912) 345-6789',
                            color: const Color(0xFF00BCD4),
                            emoji: '🚨',
                          ),
                          const SizedBox(height: 8),
                          _buildContactItem(
                            icon: Icons.support_agent,
                            title: 'Customer Care',
                            subtitle: '(0912) 987-6543',
                            color: const Color(0xFF4DD0E1),
                            emoji: '💁',
                          ),
                          const SizedBox(height: 8),
                          _buildContactItem(
                            icon: Icons.email,
                            title: 'Email Support',
                            subtitle: 'support@waterutility.com',
                            color: const Color(0xFF26C6DA),
                            emoji: '📧',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Water Conservation Reminder Widget (Replaced Daily Water Challenge)
  Widget _buildWaterConservationReminder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE0F7FA),
            Color(0xFFB2EBF2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00BCD4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tips_and_updates,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                '💡 Water Conservation Reminder',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00838F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Every Drop Counts!',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF00796B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReminderItem(
                            '🚰 Check faucets for leaks regularly'),
                        const SizedBox(height: 6),
                        _buildReminderItem('🚿 Keep showers under 5 minutes'),
                        const SizedBox(height: 6),
                        _buildReminderItem(
                            '💧 Use washing machine with full loads'),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BCD4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TODAY',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'TIP',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB2EBF2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF80DEEA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop,
                        color: Color(0xFF00796B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Small changes make big differences in water conservation',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF00796B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF00BCD4), size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF00796B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipChip(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageInsightItem(
      String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 4),
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
    );
  }

  // Ad Banner Widget - Fixed overflow with proper constraints
  Widget _buildAdBanner(BoxConstraints constraints) {
    return AnimatedBuilder(
      animation: _adController,
      builder: (context, child) {
        return Opacity(
          opacity: _adFadeAnimation.value,
          child: Container(
            width: double.infinity,
            height: 100, // Reduced height to prevent overflow
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00BCD4),
                  Color(0xFF4DD0E1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background image - smaller to prevent overflow
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Container(
                      width: 100, // Reduced width
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(_adImages[_currentAdIndex]),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.1),
                            BlendMode.darken,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(12), // Reduced padding
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ADVERTISEMENT',
                                style: GoogleFonts.poppins(
                                  fontSize: 8, // Smaller font
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00BCD4),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _adTitles[_currentAdIndex],
                              style: GoogleFonts.poppins(
                                fontSize: constraints.maxWidth < 400 ? 12 : 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _adSubTitles[_currentAdIndex],
                              style: GoogleFonts.poppins(
                                fontSize: constraints.maxWidth < 400 ? 9 : 10,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Navigation and indicator dots - made smaller
                      Container(
                        width: 40, // Fixed width to prevent overflow
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Manual next button
                            IconButton(
                              onPressed: _nextAd,
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 14, // Smaller icon
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(height: 4),
                            // Indicator dots - smaller
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < _adImages.length; i++)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentAdIndex == i
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                              ],
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
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required BoxConstraints constraints,
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      color: color, size: constraints.maxWidth < 400 ? 18 : 20),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: constraints.maxWidth < 400 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: constraints.maxWidth < 400 ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: constraints.maxWidth < 400 ? 9 : 10,
                      color: color.withOpacity(0.7),
                    ),
                    maxLines: 1,
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

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String emoji,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: color),
        ],
      ),
    );
  }

  Widget _buildMonthlyUsageChart(BoxConstraints constraints) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.lastSixMonthsFuture,
      builder: (context, snapshot) {
        List<BarChartGroupData> barGroups = [];
        double maxY = 250.0;
        List<String> monthNames = [];
        if (snapshot.hasData) {
          final months = snapshot.data!;
          monthNames = months.map((m) => m['monthName'].toString()).toList();
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
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BCD4).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE0F7FA),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📊 Water Consumption Trend',
                      style: GoogleFonts.poppins(
                        fontSize: constraints.maxWidth < 400 ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00BCD4),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00BCD4),
                            Color(0xFF4DD0E1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Last 6 Months',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
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
                              '${rod.toY.toStringAsFixed(1)} m³',
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
                              final monthName = monthNames[value.toInt()];
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4,
                                child: Text(
                                  monthName,
                                  style: GoogleFonts.poppins(
                                    fontSize:
                                        constraints.maxWidth < 400 ? 10 : 11,
                                    color: const Color(0xFF00BCD4),
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
                            reservedSize: constraints.maxWidth < 400 ? 30 : 40,
                            interval: maxY / 5,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4,
                                child: Text(
                                  value.toInt().toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize:
                                        constraints.maxWidth < 400 ? 9 : 10,
                                    color: const Color(0xFF4DD0E1),
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
                            color: const Color(0xFFE0F7FA),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                      groupsSpace: constraints.maxWidth < 400 ? 8 : 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00BCD4),
                            Color(0xFF4DD0E1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Water Consumption (m³)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF4DD0E1),
                      ),
                    ),
                  ],
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
          width: 14,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(4),
          ),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00BCD4),
              Color(0xFF4DD0E1),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
      ],
    );
  }
}

// NEW: Water Droplet Loading Animation Widget
class WaterDropletLoading extends StatefulWidget {
  final double size;
  final Color color;

  const WaterDropletLoading({
    super.key,
    this.size = 60,
    this.color = const Color(0xFF00BCD4),
  });

  @override
  State<WaterDropletLoading> createState() => _WaterDropletLoadingState();
}

class _WaterDropletLoadingState extends State<WaterDropletLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _sizeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.3), weight: 30),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _positionAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, 0), end: const Offset(0, -0.2)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, -0.2), end: const Offset(0, 0.1)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, 0.1), end: const Offset(0, 0)),
        weight: 20,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _positionAnimation.value * widget.size,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _sizeAnimation.value,
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: WaterDropletPainter(
                  progress: _controller.value,
                  color: widget.color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WaterDropletPainter extends CustomPainter {
  final double progress;
  final Color color;

  WaterDropletPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;

    // Draw water droplet
    final dropletPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.9),
          color.withOpacity(0.6),
          color.withOpacity(0.3),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Create droplet shape
    final path = Path();
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(
      center.dx + radius * 0.8,
      center.dy - radius * 0.2,
      center.dx,
      center.dy + radius,
    );
    path.quadraticBezierTo(
      center.dx - radius * 0.8,
      center.dy - radius * 0.2,
      center.dx,
      center.dy - radius,
    );
    path.close();

    canvas.drawPath(path, dropletPaint);

    // Draw ripple effect
    final ripplePaint = Paint()
      ..color = color.withOpacity(0.15 * (1 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rippleRadius = radius * (1 + progress * 0.5);
    canvas.drawCircle(center, rippleRadius, ripplePaint);

    // Draw highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final highlightPath = Path();
    final highlightRadius = radius * 0.3;
    highlightPath.addOval(Rect.fromCircle(
      center: Offset(center.dx - radius * 0.2, center.dy - radius * 0.3),
      radius: highlightRadius,
    ));
    canvas.drawPath(highlightPath, highlightPaint);

    // Draw falling water droplets
    final dropCount = 3;
    for (int i = 0; i < dropCount; i++) {
      final dropProgress = (progress + i * 0.2) % 1.0;
      if (dropProgress < 0.8) {
        final dropY = center.dy + radius + dropProgress * radius * 1.5;
        final dropX = center.dx + (i - 1) * radius * 0.3;

        final dropPaint = Paint()
          ..color = color.withOpacity(0.7 * (1 - dropProgress / 0.8))
          ..style = PaintingStyle.fill;

        final dropSize = radius * 0.15 * (1 - dropProgress / 0.8);
        canvas.drawCircle(Offset(dropX, dropY), dropSize, dropPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WaterDropletPainter oldDelegate) {
    return progress != oldDelegate.progress || color != oldDelegate.color;
  }
}

// UPDATED: NotificationDropdown now accepts notificationsData to prevent reloads
class NotificationDropdown extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> notificationsData;
  final Function(Map<String, dynamic>) onNotificationTap;
  final Function(String) onMarkAsRead;
  final VoidCallback onClose;
  final VoidCallback? onRefreshCount;
  final Future<Map<String, List<Map<String, dynamic>>>> Function()
      fetchNotifications;

  const NotificationDropdown({
    super.key,
    required this.notificationsData,
    required this.onNotificationTap,
    required this.onMarkAsRead,
    required this.onClose,
    this.onRefreshCount,
    required this.fetchNotifications,
  });

  @override
  State<NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown>
    with AutomaticKeepAliveClientMixin {
  late Map<String, List<Map<String, dynamic>>> _notificationsData;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _notificationsData = widget.notificationsData;
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final data = await widget.fetchNotifications();
      if (mounted) {
        setState(() {
          _notificationsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Container(
        width: 350,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WaterDropletLoading(size: 40),
              const SizedBox(height: 16),
              Text(
                'Loading notifications...',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF00BCD4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final unread = _notificationsData['unread']!;
    final read = _notificationsData['read']!;
    final allNotifications = [...unread, ...read];
    if (allNotifications.isEmpty) {
      return Container(
        width: 350,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_off,
                  size: 40, color: const Color(0xFFB2EBF2)),
              const SizedBox(height: 8),
              Text(
                'No notifications',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF00BCD4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You\'re all caught up!',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF4DD0E1),
                ),
              ),
            ],
          ),
        ),
      );
    }
    allNotifications.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    return Container(
      width: 350,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF00BCD4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    if (unread.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${unread.length} new',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00BCD4),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Notifications list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 4),
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: allNotifications.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: const Color(0xFFE0F7FA),
                indent: 12,
                endIndent: 12,
              ),
              itemBuilder: (context, index) {
                final notification = allNotifications[index];
                return _buildNotificationItem(notification);
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              border: Border(
                top: BorderSide(color: const Color(0xFFE0E0E0)),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Mark all as read button
                if (unread.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      for (final notification in unread) {
                        if (notification['id'] != null) {
                          widget.onMarkAsRead(notification['id']);
                        }
                      }
                      _loadNotifications(); // Refresh the list
                      widget.onRefreshCount?.call(); // Update badge count
                    },
                    icon: Icon(Icons.mark_chat_read,
                        size: 14, color: const Color(0xFF00BCD4)),
                    label: Text(
                      'Mark all read',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF00BCD4),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                const Spacer(),
                // Show counts
                Text(
                  '${unread.length} unread • ${read.length} read',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? true;
    final type = notification['type'] ?? 'unknown';
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final timestamp = notification['timestamp'] as DateTime?;
    final status = notification['status'];
    final month = notification['month'];
    final amount = notification['amount'];
    // Determine icon and color based on type and status
    IconData icon;
    Color iconColor;
    Color backgroundColor = isRead ? Colors.white : const Color(0xFFE0F7FA);
    switch (type) {
      case 'new_bill':
        icon = Icons.receipt;
        iconColor = const Color(0xFF00BCD4);
        backgroundColor = isRead
            ? const Color(0xFFE0F7FA)
            : const Color(0xFFB2EBF2).withOpacity(0.5);
        break;
      case 'bill_updated':
        icon = Icons.edit_note;
        iconColor = const Color(0xFF8E24AA);
        backgroundColor = isRead
            ? const Color(0xFFF3E5F5)
            : const Color(0xFFE1BEE7).withOpacity(0.5);
        break;
      case 'report_fixed':
        icon = Icons.check_circle_outline;
        iconColor = const Color(0xFF43A047);
        backgroundColor = isRead
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFC8E6C9).withOpacity(0.5);
        break;
      case 'payment':
        icon = status == 'approved'
            ? Icons.check_circle
            : status == 'rejected'
                ? Icons.cancel
                : Icons.payment;
        iconColor = status == 'approved'
            ? const Color(0xFF43A047)
            : status == 'rejected'
                ? const Color(0xFFE53935)
                : const Color(0xFFFB8C00);
        backgroundColor = isRead
            ? (status == 'approved'
                ? const Color(0xFFE8F5E9)
                : status == 'rejected'
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFFFF3E0))
            : (status == 'approved'
                ? const Color(0xFFC8E6C9).withOpacity(0.5)
                : status == 'rejected'
                    ? const Color(0xFFFFCDD2).withOpacity(0.5)
                    : const Color(0xFFFFE0B2).withOpacity(0.5));
        break;
      default:
        icon = Icons.notifications;
        iconColor = const Color(0xFF00BCD4);
    }
    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () => widget.onNotificationTap(notification),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification icon with read/unread indicator
              Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: iconColor.withOpacity(0.1),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                  ),
                  if (!isRead)
                    Positioned(
                      right: 8,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.bold,
                              color: isRead
                                  ? const Color(0xFF424242)
                                  : const Color(0xFF212121),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // New indicator dot
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 4, top: 3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    // Message
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isRead
                              ? const Color(0xFF757575)
                              : const Color(0xFF424242),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // New bill details (if applicable)
                    if (type == 'new_bill' &&
                        month != null &&
                        amount != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F7FA),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFB2EBF2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 12,
                              color: const Color(0xFF00BCD4),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₱${amount.toStringAsFixed(2)} for $month',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF006064),
                                    ),
                                  ),
                                  Text(
                                    'Tap to view bill',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: const Color(0xFF00BCD4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Timestamp
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timestamp != null
                              ? DateFormat('MMM d, h:mm a').format(timestamp)
                              : 'Recently',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isRead
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                        if (isRead)
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 10, color: const Color(0xFF43A047)),
                              const SizedBox(width: 4),
                              Text(
                                'Read',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: const Color(0xFF43A047),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// FIXED: Rejected Payment Dialog with proper scrolling
class _RejectedPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> paymentDetails;
  const _RejectedPaymentDialog({required this.paymentDetails});

  @override
  State<_RejectedPaymentDialog> createState() => _RejectedPaymentDialogState();
}

class _RejectedPaymentDialogState extends State<_RejectedPaymentDialog> {
  bool _showRates = false;
  bool _showReceipt = false;

  @override
  Widget build(BuildContext context) {
    final fullName = widget.paymentDetails['fullName'] ?? 'N/A';
    final address = widget.paymentDetails['address'] ?? 'N/A';
    final contactNumber = widget.paymentDetails['contactNumber'] ?? 'N/A';
    final meterNumber = widget.paymentDetails['meterNumber'] ?? 'N/A';
    final purok = widget.paymentDetails['purok'] ?? 'PUROK 1';
    final periodStart = widget.paymentDetails['periodStart'] as DateTime?;
    final previousReading =
        widget.paymentDetails['previousReading']?.toDouble() ?? 0.0;
    final currentReading =
        widget.paymentDetails['currentReading']?.toDouble() ?? 0.0;
    final cubicMeterUsed =
        widget.paymentDetails['cubicMeterUsed']?.toDouble() ?? 0.0;
    final amount = widget.paymentDetails['currentMonthBill']?.toDouble() ?? 0.0;
    final processedDate = widget.paymentDetails['processedDate'] as DateTime?;
    final rejectionReason =
        widget.paymentDetails['rejectionReason'] ?? 'No reason provided';
    final receiptImage = widget.paymentDetails['receiptImage'] as String?;
    final formattedPeriodStart = periodStart != null
        ? DateFormat('MM-dd-yyyy').format(periodStart)
        : 'N/A';
    final formattedProcessedDate = processedDate != null
        ? DateFormat.yMMMd().format(processedDate)
        : DateFormat.yMMMd().format(DateTime.now());

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Container(
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x55E53935),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'PAYMENT REJECTED',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please resubmit with corrections',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00BCD4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.water_drop,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'San Jose Water Services',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00BCD4),
                                        ),
                                      ),
                                      Text(
                                        purok,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFE53935),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Text(
                              formattedProcessedDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF757575),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'PAYMENT REJECTION NOTICE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE53935),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _dashedDivider(),
                      _receiptRow('Name', fullName),
                      _receiptRow('Address', address),
                      _receiptRow('Contact', contactNumber),
                      _receiptRow('Meter No.', meterNumber),
                      _receiptRow('Billing Period Start', formattedPeriodStart),
                      _receiptRow('Processed Date', formattedProcessedDate),
                      _dashedDivider(),
                      _receiptRow('Previous Reading',
                          '${previousReading.toStringAsFixed(2)} m³'),
                      _receiptRow('Current Reading',
                          '${currentReading.toStringAsFixed(2)} m³'),
                      _receiptRow('Cubic Meter Used',
                          '${cubicMeterUsed.toStringAsFixed(2)} m³'),
                      _dashedDivider(),
                      _receiptRow('Amount', '₱${amount.toStringAsFixed(2)}',
                          valueColor: const Color(0xFFE53935),
                          isBold: true,
                          fontSize: 14),
                      // Rejection Reason Section
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: const Color(0xFFE53935), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Rejection Reason',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFE53935),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rejectionReason,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFD32F2F),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Receipt Image Section
                      if (receiptImage != null) ...[
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showReceipt = !_showReceipt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFB2EBF2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [
                                      Icon(Icons.receipt,
                                          color: const Color(0xFF00BCD4),
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'View Submitted Receipt',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF00BCD4),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _showReceipt
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 18,
                                  color: const Color(0xFF00BCD4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFE0E0E0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Submitted Receipt',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF757575),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      base64.decode(receiptImage),
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.error,
                                                  color:
                                                      const Color(0xFFEF5350),
                                                  size: 40),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Unable to load receipt',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      const Color(0xFF9E9E9E),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: _showReceipt
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Rate Information
                      GestureDetector(
                        onTap: () => setState(() => _showRates = !_showRates),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Rate Information',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF424242),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                _showRates
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                                color: const Color(0xFF757575),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRateRow('Residential',
                                  'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                              const SizedBox(height: 6),
                              _buildRateRow('Commercial',
                                  'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                              const SizedBox(height: 6),
                              _buildRateRow('Non Residence',
                                  'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                              const SizedBox(height: 6),
                              _buildRateRow('Industrial',
                                  'Min 10 m³ = 100.00 PHP\nExceed = 15.00 PHP/m³'),
                            ],
                          ),
                        ),
                        crossFadeState: _showRates
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                      const SizedBox(height: 16),
                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFF59D)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: const Color(0xFFF57C00), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please correct the issue mentioned above and resubmit your payment.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFFEF6C00),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F7FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB2EBF2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.phone,
                                color: const Color(0xFF00BCD4), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GCash Payment',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF006064),
                                    ),
                                  ),
                                  Text(
                                    '09853886411',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: const Color(0xFF00838F),
                                      fontWeight: FontWeight.w600,
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
                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Navigate to billing page to resubmit payment
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            'Resubmit Payment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BCD4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF757575),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
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
                color: i.isEven ? const Color(0xFFE0E0E0) : Colors.transparent,
              ),
            ),
          ),
        ),
      );

  Widget _receiptRow(String label, String value,
      {Color? valueColor, bool isBold = false, double fontSize = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF424242),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: fontSize,
                color: valueColor ?? const Color(0xFF424242),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateRow(String category, String details) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Color(0xFF424242),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              details,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF757575),
              ),
            ),
          ),
        ],
      );
}

// FIXED: PaidBillDialog with proper scrolling
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
              backgroundColor: Color(0xFF43A047),
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save receipt to gallery.'),
              backgroundColor: Color(0xFFE53935),
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Container(
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF43A047),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
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
                RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00BCD4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.water_drop,
                                          color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'San Jose Water Services',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            purok,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF43A047),
                                              fontWeight: FontWeight.bold,
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
                          const SizedBox(height: 12),
                          const Text(
                            'WATER BILL STATEMENT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00BCD4),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _dashedDivider(),
                          _buildReceiptRow('Name', fullName),
                          _buildReceiptRow('Address', address),
                          _buildReceiptRow('Contact', contactNumber),
                          _buildReceiptRow('Meter No.', meterNumber),
                          _buildReceiptRow(
                              'Billing Period Start', formattedPeriodStart),
                          _buildReceiptRow(
                              'Issue Date', formattedProcessedDate),
                          _dashedDivider(),
                          _buildReceiptRow('Previous Reading',
                              '${previousReading.toStringAsFixed(2)} m³'),
                          _buildReceiptRow('Current Reading',
                              '${currentReading.toStringAsFixed(2)} m³'),
                          _buildReceiptRow('Cubic Meter Used',
                              '${cubicMeterUsed.toStringAsFixed(2)} m³'),
                          _dashedDivider(),
                          _buildReceiptRow(
                              'Amount Paid', '₱${amount.toStringAsFixed(2)}',
                              valueColor: const Color(0xFF43A047),
                              isBold: true,
                              fontSize: 13),
                          const SizedBox(height: 12),
                          // Rate Information
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showRates = !_showRates),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Rate Information',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00BCD4),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    _showRates
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 16,
                                    color: const Color(0xFF00BCD4),
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
                                    color: const Color(0xFFE0E0E0), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPaidRateRow('Residential',
                                      'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                                  const SizedBox(height: 6),
                                  _buildPaidRateRow('Commercial',
                                      'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                                  const SizedBox(height: 6),
                                  _buildPaidRateRow('Non Residence',
                                      'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                                  const SizedBox(height: 6),
                                  _buildPaidRateRow('Industrial',
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
                              color: Color(0xFF43A047),
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          // Payment Status
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFA5D6A7)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF43A047),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Payment Approved',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF43A047),
                                        ),
                                      ),
                                      const Text(
                                        'Your payment has been confirmed.',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF757575),
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
                            backgroundColor: const Color(0xFF00BCD4),
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
                          icon: const Icon(Icons.check_circle,
                              color: Colors.white),
                          label: const Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF43A047),
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
                color: i.isEven ? const Color(0xFFE0E0E0) : Colors.transparent,
              ),
            ),
          ),
        ),
      );

  Widget _buildReceiptRow(String label, String value,
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
                color: Color(0xFF424242),
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
                color: valueColor ?? const Color(0xFF757575),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidRateRow(String category, String details) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: Color(0xFF424242),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              details,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF757575),
              ),
            ),
          ),
        ],
      );
}
