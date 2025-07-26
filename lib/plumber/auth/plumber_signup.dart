import 'package:flutter/material.dart';

class PlumberSignupPage extends StatefulWidget {
  const PlumberSignupPage({super.key});

  @override
  State<PlumberSignupPage> createState() => _PlumberSignupPageState();
}

class _PlumberSignupPageState extends State<PlumberSignupPage> {
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Back Button at the top
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Form Centered
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.plumbing_outlined,
                      size: 80, color: Colors.teal),
                  const SizedBox(height: 8),
                  const Text(
                    'Plumber Sign Up',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),

                  // Full Name
                  const TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: 'Full Name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address
                  const TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.location_on_outlined),
                      hintText: 'Address',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contact Number
                  const TextField(
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: 'Contact Number',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Address
                  const TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'Email Address',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: 'Password',
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextField(
                    obscureText: !_confirmPasswordVisible,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: 'Confirm Password',
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                      suffixIcon: IconButton(
                        icon: Icon(_confirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() =>
                            _confirmPasswordVisible = !_confirmPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1,
                          color: Colors.white),
                      label: const Text('Sign Up',
                          style: TextStyle(color: Colors.white)),
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
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
