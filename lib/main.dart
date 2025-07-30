import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'landing_page.dart';
import 'admin/admin_login_page.dart';
import 'admin/admin_pages/admin_home_page.dart';
import 'admin/admin_pages/monitor_page.dart';
import 'admin/admin_pages/users_page.dart';
import 'admin/admin_pages/bills_page.dart';
import 'admin/admin_pages/view_reports_page.dart';

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
      home: kIsWeb ? const AdminLoginPage() : const LandingPage(),
      routes: {
        '/dashboard': (context) => const AdminHomePage(),
        '/monitor': (context) => const MonitorPage(),
        '/reports': (context) => const ViewReportsPage(),
        '/users': (context) => const UsersPage(),
        '/bills': (context) => const BillsPage(),
        '/logout': (context) => const AdminLoginPage(),
      },
    );
  }
}
