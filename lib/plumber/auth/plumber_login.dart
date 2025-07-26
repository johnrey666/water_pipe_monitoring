import 'package:flutter/material.dart';
import 'plumber_signup.dart';

class PlumberLoginPage extends StatelessWidget {
  const PlumberLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: 40,
            left: 16,
            child: BackButtonStyled(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.plumbing, size: 80, color: Colors.teal),
                  const SizedBox(height: 8),
                  const Text(
                    'Plumber Login',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  const TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'Email Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline),
                      hintText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: const Text('Log In',
                          style: TextStyle(color: Colors.white)),
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlumberSignupPage()));
                    },
                    child:
                        const Text('Sign Up', style: TextStyle(fontSize: 16)),
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

class BackButtonStyled extends StatelessWidget {
  const BackButtonStyled({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
      onPressed: () => Navigator.pop(context),
    );
  }
}
