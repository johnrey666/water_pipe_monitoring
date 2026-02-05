import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// Create a state management class for badge counts
class BadgeCountProvider extends ChangeNotifier {
  int _newReportsCount = 0;
  int _newUsersCount = 0;
  int _newLogsCount = 0;
  int _newPaymentsCount = 0;
  StreamSubscription? _reportsSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _logsSubscription;
  StreamSubscription? _paymentsSubscription;

  // Store last visited timestamps for each page
  DateTime? _lastVisitedReports;
  DateTime? _lastVisitedUsers;
  DateTime? _lastVisitedLogs;

  int get newReportsCount => _newReportsCount;
  int get newUsersCount => _newUsersCount;
  int get newLogsCount => _newLogsCount;
  int get newPaymentsCount => _newPaymentsCount;

  // Initialize real-time listeners
  void initializeListeners() {
    _loadLastVisitedTimesAndSetupListeners();
  }

  // Load times and setup listeners in correct order
  Future<void> _loadLastVisitedTimesAndSetupListeners() async {
    await _loadLastVisitedTimes();
    _setupReportsListener();
    _setupUsersListener();
    _setupLogsListener();
    _setupPaymentsListener();
  }

  // Load last visited times from Firestore
  Future<void> _loadLastVisitedTimes() async {
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      if (adminId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc(adminId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        _lastVisitedReports =
            (data?['lastVisitedReports'] as Timestamp?)?.toDate();
        _lastVisitedUsers = (data?['lastVisitedUsers'] as Timestamp?)?.toDate();
        _lastVisitedLogs = (data?['lastVisitedLogs'] as Timestamp?)?.toDate();
      }
    } catch (e) {
      print('Error loading last visited times: $e');
    }
  }

  // Save visited timestamp
  Future<void> _saveVisitedTimestamp(String pageKey) async {
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      if (adminId == null) return;

      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc(adminId)
          .set(
              {pageKey: FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (e) {
      print('Error saving visited timestamp: $e');
    }
  }

  // Method to update all counts
  Future<void> updateAllCounts() async {
    await Future.wait([
      _fetchNewReportsCount(),
      _fetchNewUsersCount(),
      _fetchNewLogsCount(),
      _fetchNewPaymentsCount(),
    ]);
    notifyListeners();
  }

  Future<void> _fetchNewReportsCount() async {
    try {
      final query = FirebaseFirestore.instance
          .collection('reports')
          .where('status', whereIn: ['Unfixed Reports', 'Monitoring']);

      final baseSnapshot = await query.get();

      if (_lastVisitedReports != null) {
        final filtered = baseSnapshot.docs.where((doc) {
          final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
          return createdAt != null && createdAt.isAfter(_lastVisitedReports!);
        }).toList();
        _newReportsCount = filtered.length;
      } else {
        _newReportsCount = baseSnapshot.docs.length;
      }
    } catch (e) {
      print('Error fetching new reports count: $e');
      _newReportsCount = 0;
    }
  }

  Future<void> _fetchNewUsersCount() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      if (_lastVisitedUsers != null) {
        final filtered = snapshot.docs.where((doc) {
          final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
          return createdAt != null && createdAt.isAfter(_lastVisitedUsers!);
        }).toList();
        _newUsersCount = filtered.length;
      } else {
        _newUsersCount = snapshot.docs.length;
      }
    } catch (e) {
      print('Error fetching new users count: $e');
      _newUsersCount = 0;
    }
  }

  Future<void> _fetchNewLogsCount() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('logs').get();

      if (_lastVisitedLogs != null) {
        final filtered = snapshot.docs.where((doc) {
          final timestamp = (doc['timestamp'] as Timestamp?)?.toDate();
          return timestamp != null && timestamp.isAfter(_lastVisitedLogs!);
        }).toList();
        _newLogsCount = filtered.length;
      } else {
        _newLogsCount = snapshot.docs.length;
      }
    } catch (e) {
      print('Error fetching new logs count: $e');
      _newLogsCount = 0;
    }
  }

  Future<void> _fetchNewPaymentsCount() async {
    try {
      // Count pending payments (always show all pending)
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .get();

      _newPaymentsCount = snapshot.docs.length;
    } catch (e) {
      print('Error fetching new payments count: $e');
      _newPaymentsCount = 0;
    }
  }

  // Real-time listener for reports
  void _setupReportsListener() {
    _reportsSubscription?.cancel();

    _reportsSubscription = FirebaseFirestore.instance
        .collection('reports')
        .where('status', whereIn: ['Unfixed Reports', 'Monitoring'])
        .snapshots()
        .listen((snapshot) {
          if (_lastVisitedReports != null) {
            final filtered = snapshot.docs.where((doc) {
              final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
              return createdAt != null &&
                  createdAt.isAfter(_lastVisitedReports!);
            }).toList();
            _newReportsCount = filtered.length;
          } else {
            _newReportsCount = snapshot.docs.length;
          }
          notifyListeners();
        }, onError: (error) {
          print('Error in reports listener: $error');
        });
  }

  // Real-time listener for users
  void _setupUsersListener() {
    _usersSubscription?.cancel();

    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      if (_lastVisitedUsers != null) {
        final filtered = snapshot.docs.where((doc) {
          final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
          return createdAt != null && createdAt.isAfter(_lastVisitedUsers!);
        }).toList();
        _newUsersCount = filtered.length;
      } else {
        _newUsersCount = snapshot.docs.length;
      }
      notifyListeners();
    }, onError: (error) {
      print('Error in users listener: $error');
    });
  }

  // Real-time listener for logs
  void _setupLogsListener() {
    _logsSubscription?.cancel();

    _logsSubscription = FirebaseFirestore.instance
        .collection('logs')
        .snapshots()
        .listen((snapshot) {
      if (_lastVisitedLogs != null) {
        final filtered = snapshot.docs.where((doc) {
          final timestamp = (doc['timestamp'] as Timestamp?)?.toDate();
          return timestamp != null && timestamp.isAfter(_lastVisitedLogs!);
        }).toList();
        _newLogsCount = filtered.length;
      } else {
        _newLogsCount = snapshot.docs.length;
      }
      notifyListeners();
    }, onError: (error) {
      print('Error in logs listener: $error');
    });
  }

  // Real-time listener for payments
  void _setupPaymentsListener() {
    _paymentsSubscription?.cancel();

    _paymentsSubscription = FirebaseFirestore.instance
        .collection('payments')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      _newPaymentsCount = snapshot.docs.length;
      notifyListeners();
    }, onError: (error) {
      print('Error in payments listener: $error');
    });
  }

  // Reset and mark as visited
  void markReportsAsVisited() {
    _lastVisitedReports = DateTime.now();
    _newReportsCount = 0;
    _saveVisitedTimestamp('lastVisitedReports');
    notifyListeners();
  }

  void markUsersAsVisited() {
    _lastVisitedUsers = DateTime.now();
    _newUsersCount = 0;
    _saveVisitedTimestamp('lastVisitedUsers');
    notifyListeners();
  }

  void markLogsAsVisited() {
    _lastVisitedLogs = DateTime.now();
    _newLogsCount = 0;
    _saveVisitedTimestamp('lastVisitedLogs');
    notifyListeners();
  }

  void markBillsAsVisited() {
    // Bills always shows all pending payments, no need to track visited time
    _newPaymentsCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _usersSubscription?.cancel();
    _logsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    super.dispose();
  }
}

class AdminLayout extends StatefulWidget {
  final String title;
  final Widget child;
  final String? selectedRoute;

  const AdminLayout({
    super.key,
    required this.title,
    required this.child,
    this.selectedRoute,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  late BadgeCountProvider _badgeCountProvider;

  @override
  void initState() {
    super.initState();
    _badgeCountProvider = BadgeCountProvider();
    // Initialize real-time listeners
    _badgeCountProvider.initializeListeners();

    // Initial fetch of badge counts
    _badgeCountProvider.updateAllCounts();
  }

  @override
  void didUpdateWidget(AdminLayout oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Mark as visited when navigating to specific pages
    if (widget.selectedRoute == '/reports') {
      _badgeCountProvider.markReportsAsVisited();
    } else if (widget.selectedRoute == '/users') {
      _badgeCountProvider.markUsersAsVisited();
    } else if (widget.selectedRoute == '/logs') {
      _badgeCountProvider.markLogsAsVisited();
    } else if (widget.selectedRoute == '/bills') {
      _badgeCountProvider.markBillsAsVisited();
    }
  }

  @override
  void dispose() {
    _badgeCountProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _badgeCountProvider,
      child: Scaffold(
        body: Row(
          children: [
            // Sidebar
            Consumer<BadgeCountProvider>(
              builder: (context, badgeProvider, child) {
                return Container(
                  width: 250,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF2C3E50),
                        Color(0xFF3498DB),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 100,
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ADMIN',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 24,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'BRGY SAN JOSE',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      _sidebarItem(
                        context,
                        'Dashboard',
                        Icons.dashboard,
                        '/dashboard',
                      ),
                      _sidebarItem(
                        context,
                        'Monitor',
                        Icons.monitor,
                        '/monitor',
                      ),
                      _sidebarItem(
                        context,
                        'View Reports',
                        Icons.report,
                        '/reports',
                        badgeCount: badgeProvider.newReportsCount,
                        onTap: () {
                          badgeProvider.markReportsAsVisited();
                        },
                      ),
                      _sidebarItem(
                        context,
                        'Users: New user',
                        Icons.people,
                        '/users',
                        badgeCount: badgeProvider.newUsersCount,
                        onTap: () {
                          badgeProvider.markUsersAsVisited();
                        },
                      ),
                      _sidebarItem(
                        context,
                        'Bills',
                        Icons.receipt,
                        '/bills',
                        badgeCount: badgeProvider.newPaymentsCount,
                        onTap: () {
                          badgeProvider.markBillsAsVisited();
                        },
                      ),
                      _sidebarItem(
                        context,
                        'Logs: New activity',
                        Icons.history,
                        '/logs',
                        badgeCount: badgeProvider.newLogsCount,
                        onTap: () {
                          badgeProvider.markLogsAsVisited();
                        },
                      ),
                      Spacer(),
                      _sidebarItem(
                        context,
                        'Log Out',
                        Icons.logout,
                        '/admin-login',
                        isLogout: true,
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),

            // Main Content
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        // Quick stats in header
                        Consumer<BadgeCountProvider>(
                          builder: (context, badgeProvider, child) {
                            return Row(
                              children: [
                                if (badgeProvider.newReportsCount > 0)
                                  _headerBadge(
                                    '${badgeProvider.newReportsCount} New Reports',
                                    Colors.red,
                                  ),
                                SizedBox(width: 10),
                                if (badgeProvider.newPaymentsCount > 0)
                                  _headerBadge(
                                    '${badgeProvider.newPaymentsCount} Pending Payments',
                                    Colors.orange,
                                  ),
                                SizedBox(width: 10),
                                if (badgeProvider.newUsersCount > 0)
                                  _headerBadge(
                                    '${badgeProvider.newUsersCount} New Users',
                                    Colors.green,
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: Color(0xFFF8F9FA),
                      child: widget.child,
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

  Widget _headerBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context,
    String label,
    IconData icon,
    String route, {
    bool isLogout = false,
    int badgeCount = 0,
    VoidCallback? onTap,
  }) {
    final bool isSelected = widget.selectedRoute == route;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            // Execute custom onTap if provided
            onTap?.call();

            if (isLogout) {
              // Show confirmation dialog for logout
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Colors.white,
                  title: Text(
                    'Confirm Logout',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  content: Text(
                    'Are you sure you want to log out?',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Log Out',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  // Perform logout
                  await FirebaseAuth.instance.signOut();
                  // Ensure navigation occurs after sign-out
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/admin-login',
                      (Route<dynamic> route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error signing out: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                route,
                (Route<dynamic> route) => false,
              );
            }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              vertical: isLogout ? 12 : 12,
              horizontal: isLogout ? 12 : 16,
            ),
            decoration: BoxDecoration(
              gradient: isLogout
                  ? LinearGradient(
                      colors: [
                        Colors.redAccent.withOpacity(0.9),
                        Colors.red.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : isSelected
                      ? LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
              color: isLogout || isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isLogout
                  ? Border.all(
                      color: Colors.redAccent.withOpacity(0.5), width: 1.5)
                  : null,
              boxShadow: isSelected || isLogout
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Icon(
                      icon,
                      color: isLogout
                          ? Colors.white
                          : isSelected
                              ? Colors.white
                              : Colors.white70,
                      size: isLogout ? 26 : 22,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: isLogout
                          ? Colors.white
                          : isSelected
                              ? Colors.white
                              : Colors.white70,
                      fontWeight: isLogout
                          ? FontWeight.w600
                          : isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                      fontSize: isLogout ? 16 : 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
