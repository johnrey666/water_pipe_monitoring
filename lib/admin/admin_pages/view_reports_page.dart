import 'package:flutter/material.dart';
import '../components/admin_layout.dart';

class ViewReportsPage extends StatelessWidget {
  const ViewReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'View Reports',
      selectedRoute: '/reports',
      child: Center(
        child: Text(
          'List of submitted water issue reports will be displayed here.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
