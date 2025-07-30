import 'package:flutter/material.dart';
import '../components/admin_layout.dart';

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Bills',
      selectedRoute: '/bills',
      child: Center(
        child: Text(
          'View and manage water billing details here.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
