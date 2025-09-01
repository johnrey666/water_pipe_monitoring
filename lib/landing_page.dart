// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:water_pipe_monitoring/resident/auth/resident_login.dart';
import 'package:water_pipe_monitoring/plumber/auth/plumber_login.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE0F7FA), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and Title
                  FadeInDown(
                    duration: const Duration(milliseconds: 400),
                    child: Column(
                      children: [
                        // Replaced the Icon widget with an Image.asset
                        Image.asset(
                          'assets/images/icon.png',
                          height: 120,
                          width: 120,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Water Monitoring',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Select your role to continue',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Plumber Button
                  FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 100),
                    child: RoleButton(
                      title: 'Plumber',
                      icon: Icons.plumbing,
                      onTap: () {
                        print(
                            'Plumber button tapped, navigating to PlumberLoginPage');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlumberLoginPage()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Resident Button
                  FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 200),
                    child: RoleButton(
                      title: 'Resident',
                      icon: Icons.group_outlined,
                      onTap: () {
                        print(
                            'Resident button tapped, navigating to ResidentLoginPage');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ResidentLoginPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RoleButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const RoleButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.grey.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}