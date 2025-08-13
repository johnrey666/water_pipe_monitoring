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
                Spacer(),
                _sidebarItem(context, 'Log Out', Icons.logout, '/login',
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
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
          onTap: () {
            if (!isSelected) {
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
              vertical: isLogout ? 14 : 12,
              horizontal: isLogout ? 14 : 16,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : isLogout
                      ? Colors.redAccent.withOpacity(0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isLogout
                  ? Border.all(color: Colors.redAccent, width: 1.5)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isLogout
                      ? Colors.redAccent
                      : isSelected
                          ? Colors.white
                          : Colors.white70,
                  size: isLogout ? 24 : 22,
                ),
                SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isLogout
                        ? Colors.redAccent
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
