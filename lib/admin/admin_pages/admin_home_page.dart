import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../components/admin_layout.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentPage = 0;
  final int _pageSize = 5;
  List<DocumentSnapshot?> _lastDocuments = [null];
  int _totalPages = 1;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> monthLabels = [];
  List<double> waterUsages = [];
  List<double> reportCounts = [];
  bool isLoadingChart = true;

  @override
  void initState() {
    super.initState();
    _loadChartData();
    _fetchTotalPages();
  }

  Future<void> _fetchTotalPages() async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .get();
      final totalDocs = snapshot.docs.length;
      if (mounted) {
        setState(() {
          _totalPages = (totalDocs / _pageSize).ceil();
          while (_lastDocuments.length < _totalPages) {
            _lastDocuments.add(null);
          }
        });
      }
    } catch (e) {
      print('Error fetching total pages: $e');
    }
  }

  Future<void> _loadChartData() async {
    try {
      setState(() {
        isLoadingChart = true;
      });

      DateTime now = DateTime.now();
      DateTime startDate = DateTime(now.year, now.month - 5, 1);
      DateTime endDate = DateTime(now.year, now.month + 1, 1);

      // Fetch all residents
      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Resident')
          .get();

      // Fetch consumption history from each resident's subcollection
      Map<int, double> usageMap = {};
      List<DateTime> months = [];
      DateTime current = startDate;
      while (current.isBefore(endDate)) {
        months.add(current);
        int key = current.month + current.year * 12;
        usageMap[key] = 0.0;
        current = DateTime(current.year, current.month + 1, 1);
      }

      for (var userDoc in userSnapshot.docs) {
        QuerySnapshot historySnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('consumption_history')
            .where('periodStart',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('periodStart', isLessThan: Timestamp.fromDate(endDate))
            .get();

        for (var doc in historySnapshot.docs) {
          Timestamp periodStart = doc['periodStart'];
          DateTime date = periodStart.toDate();
          int key = date.month + date.year * 12;
          double usage = (doc['cubicMeterUsed'] ?? 0).toDouble();
          usageMap[key] = (usageMap[key] ?? 0) + usage;
        }
      }

      // Fetch reports
      QuerySnapshot reportsSnapshot = await _firestore
          .collection('reports')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(endDate))
          .get();

      Map<int, int> reportsMap = {};
      for (var month in months) {
        int key = month.month + month.year * 12;
        reportsMap[key] = 0;
      }

      for (var doc in reportsSnapshot.docs) {
        Timestamp? createdAt = doc['createdAt'];
        if (createdAt != null) {
          DateTime date = createdAt.toDate();
          int key = date.month + date.year * 12;
          reportsMap[key] = (reportsMap[key] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          monthLabels = months.map((m) => DateFormat('MMM').format(m)).toList();
          waterUsages =
              months.map((m) => usageMap[m.month + m.year * 12] ?? 0).toList();
          reportCounts = months
              .map((m) => (reportsMap[m.month + m.year * 12] ?? 0).toDouble())
              .toList();
          isLoadingChart = false;
        });
      }
    } catch (e) {
      print('Error loading chart data: $e');
      if (mounted) {
        setState(() {
          isLoadingChart = false;
        });
      }
    }
  }

  Future<int> _getTotalBillsCount() async {
    try {
      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Resident')
          .get();

      int totalBills = 0;
      for (var userDoc in userSnapshot.docs) {
        QuerySnapshot billsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('bills')
            .get();
        totalBills += billsSnapshot.docs.length;
      }
      return totalBills;
    } catch (e) {
      print('Error fetching total bills count: $e');
      return 0;
    }
  }

  Stream<QuerySnapshot> _getReportsStream() {
    Query query = _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_currentPage > 0 && _lastDocuments[_currentPage - 1] != null) {
      query = query.startAfterDocument(_lastDocuments[_currentPage - 1]!);
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Dashboard',
      selectedRoute: '/dashboard',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top stats
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('users').where('role',
                        whereIn: ['Resident', 'Plumber']).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _statCard(context, 'Error', 'USERS',
                            Icons.people, Colors.blueAccent);
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _statCard(context, '...', 'USERS', Icons.people,
                            Colors.blueAccent);
                      }
                      final userCount =
                          snapshot.data?.docs.length.toString() ?? '0';
                      return _statCard(context, userCount, 'USERS',
                          Icons.people, Colors.blueAccent);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('reports').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _statCard(context, 'Error', 'REPORTS',
                            Icons.description, Colors.green);
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _statCard(context, '...', 'REPORTS',
                            Icons.description, Colors.green);
                      }
                      final reportCount =
                          snapshot.data?.docs.length.toString() ?? '0';
                      return _statCard(context, reportCount, 'REPORTS',
                          Icons.description, Colors.green);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FutureBuilder<int>(
                    future: _getTotalBillsCount(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _statCard(context, 'Error', 'INVOICES',
                            Icons.receipt_long, Colors.orange);
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _statCard(context, '...', 'INVOICES',
                            Icons.receipt_long, Colors.orange);
                      }
                      final billCount = snapshot.data?.toString() ?? '0';
                      return _statCard(context, billCount, 'INVOICES',
                          Icons.receipt_long, Colors.orange);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 400,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildChartCard(),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: _buildRecentReportsCard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, String value, String label,
      IconData icon, Color color) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart,
                color: Colors.blueAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Monthly Water Usage & Reports',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoadingChart
                ? const Center(child: CircularProgressIndicator())
                : monthLabels.isEmpty
                    ? Center(
                        child: Text(
                          'No data available',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) => Text(
                                  value.toInt().toString(),
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                reservedSize: 40,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final int index = value.toInt();
                                  if (index >= 0 &&
                                      index < monthLabels.length) {
                                    return Text(
                                      monthLabels[index],
                                      style: GoogleFonts.inter(fontSize: 12),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(
                              show: true, drawVerticalLine: false),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                final isUsage = rodIndex == 0;
                                return BarTooltipItem(
                                  '${isUsage ? 'Usage' : 'Reports'}: ${rod.toY.toInt()}',
                                  GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          barGroups: List.generate(
                            monthLabels.length,
                            (i) => BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                    toY: waterUsages[i], color: Colors.blue),
                                BarChartRodData(
                                    toY: reportCounts[i],
                                    color: Colors.redAccent),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
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

  Widget _buildRecentReportsCard() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Reports',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReportsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading reports: ${snapshot.error}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.redAccent,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data?.docs ?? [];

                if (reports.isEmpty) {
                  return Center(
                    child: Text(
                      'No reports available',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                if (reports.isNotEmpty) {
                  if (_currentPage >= _lastDocuments.length) {
                    _lastDocuments.add(reports.last);
                  } else {
                    _lastDocuments[_currentPage] = reports.last;
                  }
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final report = reports[index];
                          final fullName = report['fullName'] ?? 'Unknown';
                          final issueDescription =
                              report['issueDescription'] ?? 'No description';
                          final createdAt = report['createdAt']?.toDate();
                          final status = report['status'] ?? 'Unfixed Reports';
                          final formattedDate = createdAt != null
                              ? DateFormat.yMMMd().format(createdAt)
                              : 'Unknown date';

                          return FadeInUp(
                            duration: const Duration(milliseconds: 300),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 40,
                                    color: _getStatusColor(status),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 10,
                                              color: _getStatusColor(status),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                fullName,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade800,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          issueDescription,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          formattedDate,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
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
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _currentPage > 0
                              ? () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                }
                              : null,
                          child: Text(
                            'Previous',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _currentPage > 0
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        Text(
                          'Page ${_currentPage + 1} of $_totalPages',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        TextButton(
                          onPressed: _currentPage < _totalPages - 1
                              ? () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                }
                              : null,
                          child: Text(
                            'Next',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _currentPage < _totalPages - 1
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
