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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // User is signed in, check if admin
            return FutureBuilder<bool>(
              future: _checkAdminRole(snapshot.data!.uid),
              builder: (context, adminSnapshot) {
                if (adminSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (adminSnapshot.data == true) {
                  return const AdminHomePage();
                } else {
                  FirebaseAuth.instance.signOut();
                  return kIsWeb ? const AdminLoginPage() : const LandingPage();
                }
              },
            );
          }
          // No user signed in
          return kIsWeb ? const AdminLoginPage() : const LandingPage();
        },
      ),
      routes: {
        '/admin-login': (context) => const AdminLoginPage(),
        '/dashboard': (context) => const AdminHomePage(),
        '/monitor': (context) => const MonitorPage(reportId: ''),
        '/reports': (context) => const ViewReportsPage(),
        '/users': (context) => const UsersPage(),
        '/bills': (context) => const BillsPage(),
        '/logs': (context) => const LogsPage(),
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

  Future<bool> _checkAdminRole(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc.exists && userDoc.data()?['role'] == 'admin';
    } catch (e) {
      print('Error checking admin role: $e');
      return false;
    }
  }
}
