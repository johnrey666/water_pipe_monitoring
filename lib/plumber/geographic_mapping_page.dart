import 'package:flutter/material.dart';

class GeographicMappingPage extends StatelessWidget {
  const GeographicMappingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Interactive geographic map or issue location map will appear here.',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}
