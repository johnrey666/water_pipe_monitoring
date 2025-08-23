import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../components/admin_layout.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentPage = 0;
  final int _pageSize = 5;
  // ignore: unused_field
  DocumentSnapshot? _lastDocument;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
                // Users count (Resident and Plumber)
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
                // Reports count
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
                // Invoices (bills) count
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('bills').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _statCard(context, 'Error', 'INVOICES',
                            Icons.receipt_long, Colors.orange);
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _statCard(context, '...', 'INVOICES',
                            Icons.receipt_long, Colors.orange);
                      }
                      final billCount =
                          snapshot.data?.docs.length.toString() ?? '0';
                      return _statCard(context, billCount, 'INVOICES',
                          Icons.receipt_long, Colors.orange);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Chart and Recent Reports
            SizedBox(
              height: 400, // Fixed height for uniformity
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
                  style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(
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
      height: 400, // Fixed height
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
                'Monthly Water Usage & Leaks',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}k',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      reservedSize: 40,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun',
                          'Jul',
                          'Aug',
                          'Sep',
                          'Oct',
                          'Nov',
                          'Dec'
                        ];
                        return Text(
                          months[value.toInt()],
                          style: GoogleFonts.poppins(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final isUsage = rodIndex == 0;
                      return BarTooltipItem(
                        '${isUsage ? 'Usage' : 'Leaks'}: ${rod.toY.toInt()}k',
                        GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(toY: 65, color: Colors.blue),
                    BarChartRodData(toY: 10, color: Colors.redAccent),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(toY: 70, color: Colors.blue),
                    BarChartRodData(toY: 15, color: Colors.redAccent),
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(toY: 60, color: Colors.blue),
                    BarChartRodData(toY: 20, color: Colors.redAccent),
                  ]),
                  BarChartGroupData(x: 3, barRods: [
                    BarChartRodData(toY: 75, color: Colors.blue),
                    BarChartRodData(toY: 12, color: Colors.redAccent),
                  ]),
                  BarChartGroupData(x: 4, barRods: [
                    BarChartRodData(toY: 80, color: Colors.blue),
                    BarChartRodData(toY: 8, color: Colors.redAccent),
                  ]),
                  BarChartGroupData(x: 5, barRods: [
                    BarChartRodData(toY: 85, color: Colors.blue),
                    BarChartRodData(toY: 5, color: Colors.redAccent),
                  ]),
                ],
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
      height: 400, // Fixed height
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
                style: GoogleFonts.poppins(
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
              stream: _firestore
                  .collection('reports')
                  .orderBy('createdAt', descending: true)
                  .limit(_pageSize)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading reports',
                      style: TextStyle(fontSize: 13, color: Colors.redAccent),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data?.docs ?? [];

                if (reports.isEmpty) {
                  return const Center(
                    child: Text(
                      'No reports available',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                // Update _lastDocument for the next page
                DocumentSnapshot? newLastDocument;
                if (reports.isNotEmpty) {
                  newLastDocument = reports.last;
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final report = reports[index];
                          final fullName = report['fullName'] ?? '';
                          final issueDescription =
                              report['issueDescription'] ?? '';
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
                                                style: GoogleFonts.poppins(
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
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          formattedDate,
                                          style: GoogleFonts.poppins(
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
                                    _lastDocument =
                                        null; // Reset for previous pages
                                  });
                                }
                              : null,
                          child: Text(
                            'Previous',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _currentPage > 0
                                  ? const Color(0xFF4A2C6F)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        Text(
                          'Page ${_currentPage + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        TextButton(
                          onPressed: reports.length == _pageSize &&
                                  newLastDocument != null
                              ? () {
                                  setState(() {
                                    _currentPage++;
                                    _lastDocument =
                                        newLastDocument; // Update for next page
                                  });
                                }
                              : null,
                          child: Text(
                            'Next',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: reports.length == _pageSize &&
                                      newLastDocument != null
                                  ? const Color(0xFF4A2C6F)
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
