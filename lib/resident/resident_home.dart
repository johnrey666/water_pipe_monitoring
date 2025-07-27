import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth/resident_login.dart';
import 'report_problem_page.dart';
import 'view_billing_page.dart';

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
        return const Center(
          child: Text(
            'Welcome, Resident!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        );
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
                    colors: [Color(0xFF5B2C6F), Color(0xFF8E44AD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.account_circle, color: Colors.white, size: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hello, Resident!',
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
                  title:
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () => _logout(context),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('Resident Portal'),
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
            icon: const Icon(Icons.notifications_outlined),
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
    required ResidentPage page,
  }) {
    final bool isSelected = _selectedPage == page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        tileColor: isSelected ? Colors.deepPurple.withOpacity(0.1) : null,
        leading: Icon(icon,
            color: isSelected ? Colors.deepPurple : Colors.grey.shade700),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.deepPurple : Colors.black87,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        onTap: () => _onSelectPage(page),
      ),
    );
  }
}
