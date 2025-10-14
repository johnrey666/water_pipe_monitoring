import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'landing_page.dart';
import 'admin/admin_login_page.dart';
import 'admin/admin_pages/admin_home_page.dart';
import 'admin/admin_pages/monitor_page.dart';
import 'admin/admin_pages/users_page.dart';
import 'admin/admin_pages/bills_page.dart';
import 'admin/admin_pages/view_reports_page.dart';
import 'admin/admin_pages/logs_page.dart';
import 'resident/resident_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable offline persistence for better reliability
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Pipe Monitoring',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/admin-login': (context) => const AdminLoginPage(),
        '/dashboard': (context) => const AdminHomePage(),
        '/monitor': (context) => const MonitorPage(reportId: ''),
        '/reports': (context) => const ViewReportsPage(),
        '/users': (context) => const UsersPage(),
        '/bills': (context) => const BillsPage(),
        '/logs': (context) => const LogsPage(),
        '/resident-home': (context) => const ResidentHomePage(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('404: Page not found')),
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF87CEEB)),
              ),
            ),
          );
        }

        // Handle errors
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Error',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Retry
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getUserData(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF87CEEB)),
                    ),
                  ),
                );
              }

              if (userSnapshot.hasError) {
                // Sign out on error and redirect to landing
                FirebaseAuth.instance.signOut();
                return kIsWeb ? const AdminLoginPage() : const LandingPage();
              }

              final userData = userSnapshot.data;
              
              // Check if user data exists
              if (userData == null) {
                // User data not found, sign out and redirect
                FirebaseAuth.instance.signOut();
                return kIsWeb ? const AdminLoginPage() : const LandingPage();
              }

              // Route based on role
              final role = userData['role'] as String?;
              
              if (role == 'admin') {
                return const AdminHomePage();
              } else if (role == 'Resident') {
                return const ResidentHomePage();
              } else {
                // Unknown role, sign out
                FirebaseAuth.instance.signOut();
                return kIsWeb ? const AdminLoginPage() : const LandingPage();
              }
            },
          );
        }

        // No user signed in - show appropriate landing page
        return kIsWeb ? const AdminLoginPage() : const LandingPage();
      },
    );
  }

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('User data fetch timed out'),
          );

      if (!userDoc.exists) {
        print('User document does not exist for UID: $uid');
        return null;
      }

      return userDoc.data();
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}