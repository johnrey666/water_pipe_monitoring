import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'view_schedule_page.dart';
import 'view_reports_page.dart';
import 'geographic_mapping_page.dart';
import 'auth/plumber_login.dart';

enum PlumberPage { home, schedule, reports, mapping }

class PlumberHomePage extends StatefulWidget {
  const PlumberHomePage({super.key});

  @override
  State<PlumberHomePage> createState() => _PlumberHomePageState();
}

class _PlumberHomePageState extends State<PlumberHomePage> {
  PlumberPage _selectedPage = PlumberPage.home;

  void _onSelectPage(PlumberPage page) {
    Navigator.of(context).pop();
    setState(() {
      _selectedPage = page;
    });
  }

  Widget _getPageContent() {
    switch (_selectedPage) {
      case PlumberPage.schedule:
        return const ViewSchedulePage();
      case PlumberPage.reports:
        return const ViewReportsPage();
      case PlumberPage.mapping:
        return const GeographicMappingPage();
      case PlumberPage.home:
      default:
        return const Center(
          child: Text(
            'Welcome, Plumber!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1F618D), Color(0xFF2980B9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.only(topRight: Radius.circular(24)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.plumbing, color: Colors.white, size: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hello, Plumber!',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
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
          IconButton(
            icon: const Icon(Icons.notifications_none),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: _getPageContent(),
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
