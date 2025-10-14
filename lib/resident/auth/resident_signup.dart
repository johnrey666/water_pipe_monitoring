import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'resident_login.dart';

class ResidentSignupPage extends StatefulWidget {
  const ResidentSignupPage({super.key});

  @override
  State<ResidentSignupPage> createState() => _ResidentSignupPageState();
}

class _ResidentSignupPageState extends State<ResidentSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;
  latlong.LatLng? _selectedLocation;
  bool _isSearchingLocation = false;
  final Color primaryColor = const Color(0xFF87CEEB);
  final Color accentColor = const Color(0xFF0288D1);

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CustomLoadingDialog(),
    );

    try {
      print('Starting signup for ${_emailController.text.trim()}');

      // Create user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
              'Authentication timed out. Please check your connection and try again.');
        },
      );

      print('User created with UID: ${userCredential.user!.uid}');

      // Prepare user data
      Map<String, dynamic> userData = {
        'fullName': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'Resident',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedLocation != null) {
        userData['location'] = GeoPoint(
            _selectedLocation!.latitude, _selectedLocation!.longitude);
        userData['placeName'] = _addressController.text.trim();
      }

      // Save user data to Firestore with retry logic
      await _saveUserDataWithRetry(userCredential.user!.uid, userData);

      print('User data saved for UID: ${userCredential.user!.uid}');

      // Add log entry (non-blocking)
      _addLogEntry(userCredential.user!.uid, _nameController.text.trim());

      // Sign out the user immediately after registration
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please sign in.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate to login page after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
      });
      print('FirebaseAuthException: ${e.code} - ${e.message}');
    } on TimeoutException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _errorMessage = e.message;
      });
      print('TimeoutException: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      print('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUserDataWithRetry(String uid, Map<String, dynamic> userData,
      {int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('User data save timed out');
              },
            );

        // Verify the write was successful
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (doc.exists) {
          print('User data verified in Firestore');
          return; // Success!
        } else {
          throw Exception('User data verification failed');
        }
      } catch (e) {
        print('Attempt ${i + 1} failed: $e');
        if (i == retries - 1) {
          throw Exception('Failed to save user data after $retries attempts');
        }
        // Wait before retrying
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  void _addLogEntry(String uid, String fullName) {
    // Non-blocking log entry
    FirebaseFirestore.instance.collection('logs').add({
      'action': 'New User Created',
      'userId': uid,
      'details': 'New User $fullName Created',
      'timestamp': FieldValue.serverTimestamp(),
    }).then((_) {
      print('Log entry added successfully');
    }).catchError((e) {
      print('Error writing log entry: $e');
      // Don't throw - this is non-critical
    });
  }

  String _getFriendlyErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'The password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email sign-up is disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isSearchingLocation = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1'),
        headers: {'User-Agent': 'WaterPipeMonitoring/1.0'},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Location search timed out');
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          setState(() {
            _selectedLocation = latlong.LatLng(lat, lon);
          });
        } else {
          setState(() {
            _errorMessage = 'Location not found';
          });
        }
      } else {
        throw Exception('Failed to search location: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching location: $e';
      });
    } finally {
      setState(() {
        _isSearchingLocation = false;
      });
    }
  }

  void _openMapPicker() {
    latlong.LatLng initial = _selectedLocation ??
        const latlong.LatLng(13.294678436001885, 123.75569591912894);
    latlong.LatLng? tempLocation = _selectedLocation;
    MapController tempMapController = MapController();
    TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.95,
        child: Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: StatefulBuilder(
            builder: (context, modalSetState) => Stack(
              children: [
                FlutterMap(
                  mapController: tempMapController,
                  options: MapOptions(
                    initialCenter: tempLocation ?? initial,
                    initialZoom: 16,
                    minZoom: 15,
                    maxZoom: 17,
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds(
                        latlong.LatLng(13.292678436001885, 123.75369591912894),
                        latlong.LatLng(13.296678436001885, 123.75769591912894),
                      ),
                      padding: const EdgeInsets.all(50),
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all &
                          ~InteractiveFlag.doubleTapZoom &
                          ~InteractiveFlag.flingAnimation,
                    ),
                    onTap: (tapPosition, position) async {
                      modalSetState(() {
                        _isSearchingLocation = true;
                      });
                      modalSetState(() {
                        tempLocation = position;
                        _isSearchingLocation = false;
                      });
                      tempMapController.move(position, 16);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.water_pipe_monitoring',
                      errorTileCallback: (tile, error, stackTrace) {
                        setState(() {
                          _errorMessage =
                              'Failed to load map tiles. Check your internet connection.';
                        });
                      },
                      maxNativeZoom: 19,
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: const latlong.LatLng(
                              13.294678436001885, 123.75569591912894),
                          width: 140,
                          height: 40,
                          child: FadeIn(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              'San Jose',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.red[900],
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        if (tempLocation != null)
                          Marker(
                            point: tempLocation!,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 36,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: TextField(
                    controller: searchController,
                    cursorColor: accentColor,
                    decoration: InputDecoration(
                      hintText: 'e.g., San Jose, Malilipot',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _isSearchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.95),
                    ),
                    onSubmitted: (value) async {
                      await _searchLocation(value);
                      modalSetState(() {
                        tempLocation = _selectedLocation;
                        searchController.text = '';
                      });
                    },
                  ),
                ),
                Positioned(
                  top: 60,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      'Approx. 100m',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: tempLocation != null
                          ? () {
                              setState(() {
                                _selectedLocation = tempLocation;
                              });
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor: Colors.grey.withOpacity(0.5),
                      ),
                      child: Text(
                        'Confirm Location',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
        );
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE0F7FA), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: FadeInLeft(
                duration: const Duration(milliseconds: 300),
                child: const BackButtonStyled(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 400),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.person_add_alt,
                              size: 80,
                              color: Color(0xFF0288D1),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Resident Sign Up',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Create an account to report issues',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_errorMessage != null)
                        FadeIn(
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.red.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      if (_errorMessage != null) const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 100),
                        child: TextFormField(
                          controller: _nameController,
                          cursorColor: const Color(0xFF0288D1),
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'Full Name',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF87CEEB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            prefixIcon: const Icon(Icons.person_outline,
                                color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 150),
                        child: TextFormField(
                          controller: _addressController,
                          cursorColor: const Color(0xFF0288D1),
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'Enter your exact address',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF87CEEB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            prefixIcon: const Icon(Icons.location_on_outlined,
                                color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your address';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 175),
                        child: GestureDetector(
                          onTap: _isSearchingLocation ? null : _openMapPicker,
                          child: Text(
                            'Pin Location',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _isSearchingLocation
                                  ? Colors.grey.shade400
                                  : const Color(0xFF0288D1),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: _isSearchingLocation
                                  ? Colors.grey.shade400
                                  : const Color(0xFF0288D1).withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 200),
                        child: TextFormField(
                          controller: _contactController,
                          cursorColor: const Color(0xFF0288D1),
                          keyboardType: TextInputType.phone,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'Contact Number',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF87CEEB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            prefixIcon: const Icon(Icons.phone_outlined,
                                color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your contact number';
                            }
                            if (value.trim().length < 7) {
                              return 'Please enter a valid contact number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 250),
                        child: TextFormField(
                          controller: _emailController,
                          cursorColor: const Color(0xFF0288D1),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'Email Address',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF87CEEB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            prefixIcon: const Icon(Icons.email_outlined,
                                color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 300),
                        child: TextFormField(
                          controller: _passwordController,
                          cursorColor: const Color(0xFF0288D1),
                          obscureText: !_passwordVisible,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF87CEEB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: Colors.grey),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 350),
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          cursorColor: const Color(0xFF0288D1),
                          obscureText: !_confirmPasswordVisible,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'Confirm Password',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF87CEEB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: Colors.grey),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _confirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _confirmPasswordVisible =
                                      !_confirmPasswordVisible;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please confirm your password';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 400),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0288D1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: Colors.grey.withOpacity(0.5),
                            ),
                            child: Text(
                              _isLoading ? 'Signing Up...' : 'Sign Up',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 450),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ResidentLoginPage()),
                                );
                              },
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: const Color(0xFF0288D1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomLoadingDialog extends StatelessWidget {
  const CustomLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Spin(
                duration: const Duration(milliseconds: 800),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF87CEEB)),
                  strokeWidth: 5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Signing Up...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
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
      icon: const Icon(Icons.arrow_back_ios_new_rounded,
          size: 22, color: Colors.black87),
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
        );
      },
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}