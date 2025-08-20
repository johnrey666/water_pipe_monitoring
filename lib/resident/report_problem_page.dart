// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, unnecessary_const, unused_element, use_build_context_synchronously, unnecessary_string_interpolations, unnecessary_to_list_in_spreads, unused_local_variable, unused_import

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
  final _locationController = TextEditingController();
  final _dateTimeController = TextEditingController();
  MapController? _mapController;
  DateTime? _selectedDateTime;
  bool _isSubmitting = false;
  final Color focusBlue = const Color(0xFF87CEEB);
  final Color fieldLabelColor = Colors.grey[800]!;
  final Color iconGrey = Colors.grey[800]!;
  final Color asteriskColor = Colors.red;

  // Pagination for recent reports
  int _recentPage = 0;

  // Color scheme updates
  Color get accentColor => const Color(0xFF4A2C6F);

  Future<void> _pickImage() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    final permission = sdkInt >= 33 ? Permission.photos : Permission.storage;
    final status = await permission.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access gallery')),
      );
      return;
    }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1'),
        headers: {'User-Agent': 'WaterPipeMonitoring/1.0'},
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found')),
          );
        }
      } else {
        throw Exception('Failed to search location: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    }
  }

  Future<String> _getPlaceName(latlong.LatLng position) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json'),
        headers: {'User-Agent': 'WaterPipeMonitoring/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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
              '${selectedDateTime.toLocal().toString().substring(0, 16)}';
        });
      }
    }
  }

  Future<Map<String, String>?> _getUserInfo() async {
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
      return {
        'userId': user.uid,
        'fullName': userDoc.data()?['fullName'] ?? 'Unknown',
        'contactNumber': userDoc.data()?['contactNumber'] ?? 'Unknown',
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user info: $e')),
      );
      return null;
    }
  }

  Future<String?> _convertImageToBase64(XFile? imageFile) async {
    if (imageFile == null) return null;
    try {
      final bytes = await File(imageFile.path).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error encoding image: $e')),
      );
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });
    try {
      final userInfo = await _getUserInfo();
      if (userInfo == null) {
        throw Exception('Failed to fetch user info');
      }
      final reportData = {
        'userId': userInfo['userId'],
        'fullName': userInfo['fullName'],
        'contactNumber': userInfo['contactNumber'],
        'issueDescription': _issueController.text,
        'location': GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        'placeName': _selectedPlaceName ?? 'Unknown location',
        'dateTime': Timestamp.fromDate(_selectedDateTime!),
        'createdAt': Timestamp.now(),
        'status': 'Unfixed Reports',
      };
      final base64Image = await _convertImageToBase64(_imageFile);
      if (base64Image != null) {
        reportData['image'] = base64Image;
      }
      await FirebaseFirestore.instance.collection('reports').add(reportData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );
      setState(() {
        _issueController.clear();
        _locationController.clear();
        _dateTimeController.clear();
        _imageFile = null;
        _selectedLocation = null;
        _selectedPlaceName = null;
        _selectedDateTime = null;
        _recentPage = 0; // Reset to first page to show newest report
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting report: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _openMapPicker() {
    latlong.LatLng initial = _selectedLocation ??
        const latlong.LatLng(13.294678436001885, 123.75569591912894);
    latlong.LatLng? tempLocation = _selectedLocation;
    String? tempPlaceName = _selectedPlaceName;
    MapController tempMapController = MapController();

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
                      final placeName = await _getPlaceName(position);
                      modalSetState(() {
                        tempLocation = position;
                        tempPlaceName = placeName;
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to load map tiles. Check your internet connection.')),
                        );
                      },
                    ),
                    MarkerLayer(
                      markers: [
                        // San Jose label (no icon)
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
                        // User-selected location marker
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
                    cursorColor: Colors.black,
                    decoration: InputDecoration(
                      labelText: 'Search Location',
                      labelStyle: TextStyle(color: Colors.grey[800]),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: focusBlue, width: 2),
                      ),
                      hintText: 'e.g., San Jose, Malilipot',
                      suffixIcon: Icon(Icons.search, color: iconGrey),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.95),
                    ),
                    onSubmitted: (value) async {
                      if (value.isNotEmpty) {
                        final response = await http.get(
                          Uri.parse(
                              'https://nominatim.openstreetmap.org/search?q=$value&format=json&limit=1'),
                          headers: {'User-Agent': 'WaterPipeMonitoring/1.0'},
                        );
                        if (response.statusCode == 200) {
                          final data = jsonDecode(response.body);
                          if (data.isNotEmpty) {
                            final lat = double.parse(data[0]['lat']);
                            final lon = double.parse(data[0]['lon']);
                            final placeName = data[0]['display_name'];
                            modalSetState(() {
                              tempLocation = latlong.LatLng(lat, lon);
                              tempPlaceName = placeName;
                            });
                            tempMapController.move(tempLocation!, 16);
                          }
                        }
                      }
                    },
                  ),
                ),
                // Manual scale indicator
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
                // Attribution text
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
                // Confirm button
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        if (tempLocation != null) {
                          setState(() {
                            _selectedLocation = tempLocation;
                            _selectedPlaceName = tempPlaceName;
                            _locationController.text = tempPlaceName ?? '';
                          });
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: focusBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('CONFIRM LOCATION',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
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
    Color? iconColor,
    bool readOnly = false,
    VoidCallback? onTap,
    String? hint,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        validator: validator,
        cursorColor: Colors.black,
        style: const TextStyle(fontSize: 15, color: Colors.black),
        decoration: InputDecoration(
          label: RichText(
            text: TextSpan(
              text: label.replaceAll('*', '').trim(),
              style: TextStyle(color: fieldLabelColor, fontSize: 13),
              children: label.contains('*')
                  ? [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: asteriskColor),
                      )
                    ]
                  : [],
            ),
          ),
          hintText: hint,
          prefixIcon: Icon(icon, size: 22, color: iconColor ?? iconGrey),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: focusBlue, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Error loading recent reports',
                style: TextStyle(color: Colors.red)),
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

        return Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.07),
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
                  Icon(Icons.history, color: focusBlue, size: 22),
                  const SizedBox(width: 8),
                  const Text('Recent Report',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  if (totalPages > 1)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _recentPage > 0
                              ? () => setState(() => _recentPage--)
                              : null,
                        ),
                        Text('${_recentPage + 1}/$totalPages',
                            style: const TextStyle(fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _recentPage < totalPages - 1
                              ? () => setState(() => _recentPage++)
                              : null,
                        ),
                      ],
                    ),
                ],
              ),
              ...[doc].map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.report,
                          color: const Color.fromARGB(255, 209, 70, 60),
                          size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['issueDescription'] ?? '',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (data['placeName'] != null)
                              Text(
                                data['placeName'],
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          (data['status'] ?? '')
                              .toString()
                              .replaceAll('Reports', ''),
                          style: TextStyle(
                            color: data['status'] == 'Fixed'
                                ? Colors.green[700]
                                : (data['status'] == 'Unfixed Reports'
                                    ? Colors.red[700]
                                    : Colors.orange[800]),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color.fromARGB(255, 255, 255, 255),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            children: [
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.water_drop, color: focusBlue, size: 38),
                    const SizedBox(height: 4),
                    const Text(
                      'Report a Water Issue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Color.fromRGBO(66, 66, 66, 1),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  children: [
                    _modernField(
                      controller: _issueController,
                      label: 'Issue Description *',
                      icon: Icons.report_problem_outlined,
                      maxLines: 2,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    _modernField(
                      controller: _locationController,
                      label: 'Location *',
                      icon: Icons.location_on_outlined,
                      readOnly: true,
                      onTap: _openMapPicker,
                      hint: 'Tap to select or search location',
                      validator: (v) =>
                          _selectedLocation == null ? 'Required' : null,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.map, color: iconGrey),
                        onPressed: _openMapPicker,
                      ),
                    ),
                    _modernField(
                      controller: _dateTimeController,
                      label: 'Date & Time *',
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: _selectDateTime,
                      hint: 'Tap to select date and time',
                      validator: (v) =>
                          _selectedDateTime == null ? 'Required' : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _modernField(
                            controller: TextEditingController(
                                text: _imageFile?.name ?? ''),
                            label: 'Upload Image',
                            icon: Icons.image_outlined,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(Icons.upload, size: 18, color: iconGrey),
                          label: Text('UPLOAD',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: iconGrey,
                                  fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: focusBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 0),
                          ),
                        ),
                      ],
                    ),
                    if (_imageFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 2),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(_imageFile!.path),
                                height: 110,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _imageFile = null),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white70,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 20, color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: focusBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.zero,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('SUBMIT REPORT',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Fields marked with * are required',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              offset: Offset(0.5, 0.5),
                              blurRadius: 1,
                            ),
                          ],
                        ),
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
