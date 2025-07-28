import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'auth/resident_login.dart';
import 'report_problem_page.dart';
import 'view_billing_page.dart';
import 'resident_drawer_header.dart';

enum ResidentPage { home, report, billing }

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  ResidentPage _selectedPage = ResidentPage.home;

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
      (route) => false,
    );
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
    Navigator.of(context).pop();
    setState(() {
      _selectedPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const ResidentDrawerHeader(),
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
                  title: const Text('Logout',
                      style: TextStyle(color: Colors.red, fontSize: 16)),
                  onTap: () => _logout(context),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text(
          'Resident Portal',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 26, color: Colors.black87),
        ),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87, size: 30),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: Colors.black87, size: 30),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("No new notifications"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                      .animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              )),
              child: child,
            ),
          ),
          child: _getPageContent(),
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
      child: ListTile(
        tileColor: isSelected ? const Color(0xFFEDE7F6) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon,
            color: isSelected ? const Color(0xFF4A2C6F) : Colors.grey.shade700,
            size: 30),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? const Color(0xFF4A2C6F) : Colors.black87,
          ),
        ),
        selected: isSelected,
        onTap: () => _onSelectPage(page),
      ),
    );
  }

  Widget _buildDashboard() {
    final List<BarChartGroupData> barGroups = [
      BarChartGroupData(x: 0, barRods: [
        BarChartRodData(
            toY: 150,
            color: const Color(0xFF4CAF50),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))
      ]),
      BarChartGroupData(x: 1, barRods: [
        BarChartRodData(
            toY: 200,
            color: const Color(0xFF2196F3),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))
      ]),
      BarChartGroupData(x: 2, barRods: [
        BarChartRodData(
            toY: 180,
            color: const Color(0xFFFF9800),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))
      ]),
      BarChartGroupData(x: 3, barRods: [
        BarChartRodData(
            toY: 220,
            color: const Color(0xFFF44336),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))
      ]),
      BarChartGroupData(x: 4, barRods: [
        BarChartRodData(
            toY: 190,
            color: const Color(0xFF9C27B0),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))
      ]),
      BarChartGroupData(x: 5, barRods: [
        BarChartRodData(
            toY: 160,
            color: const Color(0xFF009688),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))
      ]),
      BarChartGroupData(x: 6, barRods: [
        BarChartRodData(
            toY: 170,
            color: const Color(0xFF4CAF50),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))
      ]),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 180,
                height: 260,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Today',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        const SizedBox(height: 12),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            const SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: 185 / 462,
                                strokeWidth: 12,
                                backgroundColor: Colors.grey,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1976D2)),
                              ),
                            ),
                            const Text('185 gal',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('40% of daily avg',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                height: 260,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.water_drop,
                            size: 48, color: Color(0xFF00695C)),
                        SizedBox(height: 12),
                        Text('20.3 gal/min',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87)),
                        Text('Water Running',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 16.0),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weekly Water Usage',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 250,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipPadding: const EdgeInsets.all(10),
                            tooltipMargin: 10,
                            getTooltipColor: (_) => Colors.grey.shade900,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final weekDays = [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thurs',
                                'Fri',
                                'Sat',
                                'Sun'
                              ];
                              return BarTooltipItem(
                                '${weekDays[group.x]}\n${rod.toY.toStringAsFixed(0)} gal',
                                const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const weekDays = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thurs',
                                  'Fri',
                                  'Sat',
                                  'Sun'
                                ];
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 10,
                                  child: Text(
                                    weekDays[value.toInt()],
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                  ),
                                );
                              },
                              reservedSize: 32,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              interval: 50,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 10,
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 14),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        barGroups: barGroups,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
