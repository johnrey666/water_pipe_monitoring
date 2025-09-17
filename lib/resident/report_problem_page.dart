// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, unnecessary_const, unused_element, use_build_context_synchronously, unnecessary_string_interpolations, unnecessary_to_list_in_spreads, unused_local_variable

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  XFile? _imageFile;
  latlong.LatLng? _selectedLocation;
  String? _selectedPlaceName;
  final _issueController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  final _dateTimeController = TextEditingController();
  final _locationController = TextEditingController();
  final _imageNameController = TextEditingController();
  MapController? _mapController;
  DateTime? _selectedDateTime;
  bool _isSubmitting = false;
  bool _isSearchingLocation = false;
  bool _isPublicReport = false;
  String? _errorMessage;
  final Color primaryColor = const Color(0xFF87CEEB);
  final Color accentColor = const Color(0xFF0288D1);
  final Color iconGrey = Colors.grey;

  int _recentPage = 0;

  @override
  void dispose() {
    _issueController.dispose();
    _additionalInfoController.dispose();
    _dateTimeController.dispose();
    _locationController.dispose();
    _imageNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    final permission = sdkInt >= 33 ? Permission.photos : Permission.storage;
    final status = await permission.request();
    if (!status.isGranted) {
      setState(() {
        _errorMessage = 'Permission denied to access gallery';
      });
      return;
    }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
        _imageNameController.text = image.name;
        _errorMessage = null;
      });
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
          final placeName = data[0]['display_name'];
          setState(() {
            _selectedLocation = latlong.LatLng(lat, lon);
            _selectedPlaceName = placeName;
            _locationController.text = placeName;
          });
          if (_mapController != null) {
            _mapController!.move(_selectedLocation!, 16);
          }
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

  Future<String> _getPlaceName(latlong.LatLng position) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json'),
        headers: {'User-Agent': 'WaterPipeMonitoring/1.0'},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Reverse geocoding timed out');
          return http.Response('{"display_name": "Unknown location"}', 200);
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
      return 'Unknown location';
    } catch (e) {
      print('Error in _getPlaceName: $e');
      return 'Unknown location';
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: accentColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: accentColor,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );
      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          _selectedDateTime = selectedDateTime;
          _dateTimeController.text =
              DateFormat('yyyy-MM-dd HH:mm').format(selectedDateTime);
          _errorMessage = null;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _getUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) {
        throw Exception('User data not found');
      }
      final data = userDoc.data()!;
      final location = data['location'] as GeoPoint?;
      return {
        'userId': user.uid,
        'fullName': data['fullName'] ?? 'Unknown',
        'contactNumber': data['contactNumber'] ?? 'Unknown',
        'location': location != null
            ? latlong.LatLng(location.latitude, location.longitude)
            : null,
        'placeName': data['placeName'] ?? 'Unknown location',
      };
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching user info: $e';
      });
      return null;
    }
  }

  Future<String?> _convertImageToBase64(XFile? imageFile) async {
    if (imageFile == null) return null;
    try {
      final bytes = await File(imageFile.path).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error encoding image: $e';
      });
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CustomLoadingDialog(),
    );

    try {
      final userInfo = await _getUserInfo();
      if (userInfo == null) {
        throw Exception('Failed to fetch user info');
      }
      if (_issueController.text.trim().isEmpty) {
        throw Exception('Issue description is required');
      }
      if (_selectedDateTime == null) {
        throw Exception('Date and time is required');
      }
      if (_isPublicReport && _selectedLocation == null) {
        throw Exception('Please select a location for public report');
      }
      if (!_isPublicReport && userInfo['location'] == null) {
        throw Exception('User location not found');
      }

      final reportData = {
        'userId': userInfo['userId'],
        'fullName': userInfo['fullName'],
        'contactNumber': userInfo['contactNumber'],
        'issueDescription': _issueController.text,
        'location': _isPublicReport
            ? GeoPoint(
                _selectedLocation!.latitude, _selectedLocation!.longitude)
            : GeoPoint(
                (userInfo['location'] as latlong.LatLng).latitude,
                (userInfo['location'] as latlong.LatLng).longitude,
              ),
        'placeName': _isPublicReport
            ? (_selectedPlaceName ?? 'Unknown location')
            : userInfo['placeName'],
        'dateTime': Timestamp.fromDate(_selectedDateTime!),
        'createdAt': Timestamp.now(),
        'status': 'Unfixed Reports',
        'isPublic': _isPublicReport,
      };
      if (_additionalInfoController.text.isNotEmpty) {
        reportData['additionalLocationInfo'] = _additionalInfoController.text;
      }
      final base64Image = await _convertImageToBase64(_imageFile);
      if (base64Image != null) {
        reportData['image'] = base64Image;
      }
      await FirebaseFirestore.instance.collection('reports').add(reportData);

      // Log the report submission
      await FirebaseFirestore.instance.collection('logs').add({
        'action': 'Report Submitted',
        'userId': userInfo['userId'],
        'details':
            'Report submitted by ${userInfo['fullName']}: ${_issueController.text}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );
      setState(() {
        _issueController.clear();
        _additionalInfoController.clear();
        _dateTimeController.clear();
        _imageFile = null;
        _imageNameController.clear();
        _selectedLocation = null;
        _selectedPlaceName = null;
        _locationController.clear();
        _selectedDateTime = null;
        _isPublicReport = false;
        _recentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      setState(() {
        _errorMessage = 'Error submitting report: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openMapPicker() {
    latlong.LatLng initial = _selectedLocation ??
        const latlong.LatLng(13.294678436001885, 123.75569591912894);
    latlong.LatLng? tempLocation = _selectedLocation;
    String? tempPlaceName = _selectedPlaceName;
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
                        const latlong.LatLng(
                            13.292678436001885, 123.75369591912894),
                        const latlong.LatLng(
                            13.296678436001885, 123.75769591912894),
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
                      final placeName = await _getPlaceName(position);
                      modalSetState(() {
                        tempLocation = position;
                        tempPlaceName = placeName;
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
                        print('Tile loading error: $error');
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
                        tempPlaceName = _selectedPlaceName;
                        searchController.text = tempPlaceName ?? '';
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
                                _selectedPlaceName = tempPlaceName;
                                _locationController.text = tempPlaceName ?? '';
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

  Widget _modernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    String? hint,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: 100 * (maxLines == 2 ? 1 : maxLines + 2)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          validator: validator,
          cursorColor: accentColor,
          style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            labelText: label.replaceAll('*', '').trim(),
            labelStyle: GoogleFonts.poppins(color: iconGrey, fontSize: 13),
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            prefixIcon: Icon(icon, size: 22, color: iconGrey),
            suffixIcon: suffixIcon,
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
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIconConstraints:
                const BoxConstraints(minHeight: 32, minWidth: 32),
          ),
        ),
      ),
    );
  }

  Widget _recentReports() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FadeInUp(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 500),
            child: Container(
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Error loading recent reports',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.red.shade800),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }
        final docs = snapshot.data!.docs;
        final totalPages = docs.length;
        final index = _recentPage.clamp(0, docs.length - 1);
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;

        return FadeInUp(
          duration: const Duration(milliseconds: 400),
          delay: const Duration(milliseconds: 500),
          child: Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: accentColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Report',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (totalPages > 1)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left, color: accentColor),
                            onPressed: _recentPage > 0
                                ? () => setState(() => _recentPage--)
                                : null,
                          ),
                          Text(
                            '${_recentPage + 1}/$totalPages',
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.black87),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, color: accentColor),
                            onPressed: _recentPage < totalPages - 1
                                ? () => setState(() => _recentPage++)
                                : null,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.report, color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['issueDescription'] ?? 'No description',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (data['placeName'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  data['placeName'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(
                                    (data['dateTime'] as Timestamp).toDate()),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Chip(
                        label: Text(
                          (data['status'] ?? '')
                              .toString()
                              .replaceAll('Reports', ''),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: data['status'] == 'Fixed'
                                ? Colors.green.shade700
                                : (data['status'] == 'Unfixed Reports'
                                    ? Colors.red.shade700
                                    : Colors.orange.shade800),
                          ),
                        ),
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Dirty white background
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 400),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.report_problem_outlined,
                      color: accentColor,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Report a Problem',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color.fromARGB(255, 43, 43, 43),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Error Message
              if (_errorMessage != null)
                FadeIn(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
              // Form Fields
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _modernField(
                      controller: _issueController,
                      label: 'Issue Description *',
                      icon: Icons.report_problem_outlined,
                      maxLines: 2,
                      validator: (v) => v!.isEmpty
                          ? 'Please enter the issue description'
                          : null,
                    ),
                    FadeInUp(
                      duration: const Duration(milliseconds: 400),
                      delay: const Duration(milliseconds: 200),
                      child: CheckboxListTile(
                        title: Text(
                          'Public Report',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        value: _isPublicReport,
                        onChanged: (value) {
                          setState(() {
                            _isPublicReport = value ?? false;
                            if (!_isPublicReport) {
                              _selectedLocation = null;
                              _selectedPlaceName = null;
                              _locationController.clear();
                            }
                          });
                        },
                        activeColor: accentColor,
                        checkColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    if (_isPublicReport)
                      _modernField(
                        controller: _locationController,
                        label: 'Location *',
                        icon: Icons.location_on_outlined,
                        readOnly: true,
                        onTap: _openMapPicker,
                        hint: 'Tap to select or search location',
                        validator: (v) => _selectedLocation == null
                            ? 'Please select a location'
                            : null,
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
                            : IconButton(
                                icon: Icon(Icons.map, color: iconGrey),
                                onPressed: _openMapPicker,
                              ),
                      ),
                    if (_isPublicReport)
                      _modernField(
                        controller: _additionalInfoController,
                        label: 'Additional Location Information',
                        icon: Icons.info_outline,
                        hint: 'Optional details about the location',
                        validator: (v) => null,
                      ),
                    _modernField(
                      controller: _dateTimeController,
                      label: 'Date & Time *',
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: _selectDateTime,
                      hint: 'Tap to select date and time',
                      validator: (v) => _selectedDateTime == null
                          ? 'Please select date and time'
                          : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _modernField(
                            controller: _imageNameController,
                            label: 'Upload Image',
                            icon: Icons.image_outlined,
                            readOnly: true,
                            validator: (v) => null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          delay: const Duration(milliseconds: 400),
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.upload,
                                  size: 20, color: Colors.white),
                              label: Text(
                                'Upload',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_imageFile != null)
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 450),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_imageFile!.path),
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _imageFile = null;
                                    _imageNameController.clear();
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 20, color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FadeInUp(
                      duration: const Duration(milliseconds: 400),
                      delay: const Duration(milliseconds: 500),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
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
                            _isSubmitting ? 'Submitting...' : 'Submit Report',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      duration: const Duration(milliseconds: 400),
                      delay: const Duration(milliseconds: 550),
                      child: Text(
                        'Fields marked with * are required',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              _recentReports(),
            ],
          ),
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
                'Submitting Report...',
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
