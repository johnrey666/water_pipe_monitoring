import 'package:flutter/material.dart';

class PlumberHomePage extends StatelessWidget {
  const PlumberHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plumber Home'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Welcome, Plumber!',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
