import 'package:flutter/material.dart';

class ResidentHomePage extends StatelessWidget {
  const ResidentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resident Home'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Welcome, Resident!',
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
