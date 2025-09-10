import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminLayout extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
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
                SizedBox(height: 20),
                _sidebarItem(
                  context,
                  'Dashboard',
                  Icons.dashboard,
                  '/dashboard',
                ),
                _sidebarItem(context, 'Monitor', Icons.monitor, '/monitor'),
                _sidebarItem(context, 'View Reports', Icons.report, '/reports'),
                _sidebarItem(context, 'Users', Icons.people, '/users'),
                _sidebarItem(context, 'Bills', Icons.receipt, '/bills'),
                _sidebarItem(context, 'Logs', Icons.history, '/logs'),
                Spacer(),
                _sidebarItem(context, 'Log Out', Icons.logout, '/admin-login',
                    isLogout: true),
                SizedBox(height: 20),
              ],
            ),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/logs');
                        },
                        icon: Icon(
                          Icons.history,
                          color: Color(0xFF2C3E50),
                          size: 28,
                        ),
                        tooltip: 'View Logs',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Color(0xFFF8F9FA),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context,
    String label,
    IconData icon,
    String route, {
    bool isLogout = false,
  }) {
    final bool isSelected = selectedRoute == route;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
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
                Icon(
                  icon,
                  color: isLogout
                      ? Colors.white
                      : isSelected
                          ? Colors.white
                          : Colors.white70,
                  size: isLogout ? 26 : 22,
                ),
                SizedBox(width: 12),
                Text(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
