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
import 'admin/admin_pages/admin_view_reported_reports.dart';
import 'admin/admin_pages/logs_page.dart';
import 'resident/resident_home.dart';
import 'plumber/plumber_home.dart';
import 'plumber/view_schedule_page.dart';
import 'plumber/view_reports_page.dart' as plumber_reports;
import 'plumber/geographic_mapping_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
        // Admin routes
        '/admin-login': (context) => const AdminLoginPage(),
        '/dashboard': (context) => const AdminHomePage(),
        '/monitor': (context) => const MonitorPage(reportId: ''),
        '/reports': (context) => const ViewReportedReportsPage(),
        '/reported-reports': (context) => const ViewReportedReportsPage(),
        '/users': (context) => const UsersPage(),
        '/bills': (context) => const BillsPage(),
        '/logs': (context) => const LogsPage(),

        // Resident routes
        '/resident-home': (context) => const ResidentHomePage(),

        // Plumber routes
        '/plumber-home': (context) => const PlumberHomePage(),
        '/plumber-schedule': (context) => const ViewSchedulePage(),
        '/plumber-reports': (context) =>
            const plumber_reports.ViewReportsPage(),
        '/plumber-mapping': (context) => const GeographicMappingPage(),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF87CEEB)),
              ),
            ),
          );
        }

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
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

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
                FirebaseAuth.instance.signOut();
                return kIsWeb ? const AdminLoginPage() : const LandingPage();
              }

              final userData = userSnapshot.data;

              if (userData == null) {
                FirebaseAuth.instance.signOut();
                return kIsWeb ? const AdminLoginPage() : const LandingPage();
              }

              final role = userData['role'] as String?;

              switch (role) {
                case 'admin':
                  return const AdminHomePage();
                case 'Resident':
                  return const ResidentHomePage();
                case 'Plumber':
                  return const PlumberHomePage();
                default:
                  FirebaseAuth.instance.signOut();
                  return kIsWeb ? const AdminLoginPage() : const LandingPage();
              }
            },
          );
        }

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
            onTimeout: () =>
                throw TimeoutException('User data fetch timed out'),
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
