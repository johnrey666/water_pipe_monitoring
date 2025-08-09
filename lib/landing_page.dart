// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:water_pipe_monitoring/resident/auth/resident_login.dart';
import 'package:water_pipe_monitoring/plumber/auth/plumber_login.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Please Select Your Role',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              RoleButton(
                title: 'PLUMBER',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlumberLoginPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              RoleButton(
                title: 'RESIDENT',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const RoleButton({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF87CEEB),
        foregroundColor: Color.fromARGB(255, 255, 255, 255),
        elevation: 2,
        shadowColor: Colors.grey.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black12),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}