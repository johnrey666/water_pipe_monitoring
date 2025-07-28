import 'package:flutter/material.dart';

class ResidentDrawerHeader extends StatelessWidget {
  const ResidentDrawerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: const BoxDecoration(
        color: Color(0xFF4A2C6F),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(12),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.account_circle, color: Colors.white, size: 50),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hello, Resident!',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}
