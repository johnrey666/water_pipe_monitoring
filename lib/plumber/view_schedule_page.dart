import 'package:flutter/material.dart';

class ViewSchedulePage extends StatelessWidget {
  const ViewSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your Work Schedule will appear here.',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}
