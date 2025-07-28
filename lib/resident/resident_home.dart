import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'auth/resident_login.dart';
import 'report_problem_page.dart';
import 'view_billing_page.dart';
import 'resident_drawer_header.dart';

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
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: const Color(0xFF00695C),
          secondary: const Color(0xFF4CAF50),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          margin: const EdgeInsets.all(8),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 4,
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titleMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Colors.black54,
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
        title: const Text('Resident Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 24),
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
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
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
      child: Material(
        color: isSelected ? const Color(0xFFE0F2F1) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade700,
            size: 24,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
            ),
          ),
          selected: isSelected,
          onTap: () => _onSelectPage(page),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Today\'s Usage',
                  value: '185 gal',
                  description: '40% of daily avg',
                  icon: Icons.water,
                  color: const Color(0xFF00796B),
                  progress: 0.4,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Flow Rate',
                  value: '20.3 gal/min',
                  description: 'Water Running',
                  icon: Icons.speed,
                  color: const Color(0xFF00838F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildWeeklyUsageChart(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color color,
    double? progress,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Icon(icon, size: 24, color: color),
              ],
            ),
            const SizedBox(height: 12),
            if (progress != null)
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyUsageChart() {
    final List<BarChartGroupData> barGroups = [
      _buildBarGroup(0, 150, 'Mon', const Color(0xFF00796B)),
      _buildBarGroup(1, 200, 'Tue', const Color(0xFF00838F)),
      _buildBarGroup(2, 180, 'Wed', const Color(0xFF0097A7)),
      _buildBarGroup(3, 220, 'Thu', const Color(0xFF00ACC1)),
      _buildBarGroup(4, 190, 'Fri', const Color(0xFF26C6DA)),
      _buildBarGroup(5, 160, 'Sat', const Color(0xFF4DD0E1)),
      _buildBarGroup(6, 170, 'Sun', const Color(0xFF80DEEA)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Water Usage',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 250,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipColor: (_) => Colors.white,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toStringAsFixed(0)} gal',
                          TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
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
                          final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4,
                            child: Text(
                              days[value.toInt()],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 50,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4,
                            child: Text(
                              value.toInt().toString(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, String day, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(4),
          ),
        ),
      ],
    );
  }
}
