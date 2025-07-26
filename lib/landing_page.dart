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
                    MaterialPageRoute(
                        builder: (_) => const ResidentLoginPage()),
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
