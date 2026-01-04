// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, unnecessary_const, unused_element, use_build_context_synchronously, unnecessary_string_interpolations, unnecessary_to_list_in_spreads, unused_local_variable, body_might_complete_normally_catch_error, unused_field

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

class _ReportProblemPageState extends State<ReportProblemPage>
    with AutomaticKeepAliveClientMixin<ReportProblemPage> {
  @override
  bool get wantKeepAlive => true;

  static bool _stateInitialized = false;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  List<XFile> _imageFiles = [];
  latlong.LatLng? _selectedLocation;
  String? _selectedPlaceName;
  final _issueController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  final _locationController = TextEditingController();
  final _imageNameController = TextEditingController();
  final FocusNode _issueFocusNode = FocusNode();
  final FocusNode _additionalInfoFocusNode = FocusNode();
  MapController? _mapController;
  bool _isSubmitting = false;
  bool _isSearchingLocation = false;
  bool _isPublicReport = false;
  bool _isInitialized = false;
  String? _errorMessage;

  // Add PageStorageKey to preserve ListView state (scroll, focus)
  final PageStorageKey _listKey = PageStorageKey('report_problem_list');

  final Color primaryColor = const Color(0xFF87CEEB);
  final Color accentColor = const Color(0xFF0288D1);
  final Color iconGrey = Colors.grey;

  @override
  void initState() {
    super.initState();
    if (!_stateInitialized) {
      _issueController.text = '';
      _additionalInfoController.text = '';
      _locationController.text = '';
      _imageNameController.text = '';
      _mapController = MapController();
      _stateInitialized = true;
      _isInitialized = true;
    }

    // Add listeners to focus nodes
    _issueFocusNode.addListener(_onFocusChange);
    _additionalInfoFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_issueFocusNode.hasFocus || _additionalInfoFocusNode.hasFocus) {
      // Ensure the page doesn't rebuild when text fields get focus
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    // Remove focus listeners
    _issueFocusNode.removeListener(_onFocusChange);
    _additionalInfoFocusNode.removeListener(_onFocusChange);

    _issueController.dispose();
    _additionalInfoController.dispose();
    _locationController.dispose();
    _imageNameController.dispose();
    _issueFocusNode.dispose();
    _additionalInfoFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Updated to pick multiple images
  Future<void> _pickImages() async {
    try {
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

      // Pick multiple images
      final List<XFile>? images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images != null && images.isNotEmpty) {
        // Limit to 10 images maximum
        final newImages = images.take(10).toList();
        setState(() {
          _imageFiles.addAll(newImages);
          _updateImageNameController();
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking images: $e';
      });
    }
  }

  // Pick single image from camera
  Future<void> _takePhoto() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _errorMessage = 'Permission denied to access camera';
        });
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (_imageFiles.length < 10) {
            _imageFiles.add(image);
            _updateImageNameController();
          } else {
            _errorMessage = 'Maximum 10 images allowed';
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error taking photo: $e';
      });
    }
  }

  // Update image name controller text
  void _updateImageNameController() {
    if (!mounted) return;
    if (_imageFiles.isEmpty) {
      _imageNameController.text = '';
    } else if (_imageFiles.length == 1) {
      _imageNameController.text = _imageFiles[0].name;
    } else {
      _imageNameController.text = '${_imageFiles.length} images selected';
    }
  }

  // Remove specific image
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
      _updateImageNameController();
    });
  }

  // Clear all images
  void _clearAllImages() {
    if (!mounted) {
      _imageFiles.clear();
      return;
    }
    setState(() {
      _imageFiles.clear();
      _imageNameController.text = '';
    });
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

  Future<Map<String, dynamic>?> _getUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Failed to load user data');
        },
      );
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

  // Updated to convert multiple images to base64
  Future<List<String>> _convertImagesToBase64(List<XFile> imageFiles) async {
    final List<String> base64Images = [];

    for (final imageFile in imageFiles) {
      try {
        final bytes = await File(imageFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        base64Images.add(base64Image);
      } catch (e) {
        print('Error encoding image ${imageFile.name}: $e');
        // Continue with other images even if one fails
      }
    }

    return base64Images;
  }

  Future<void> _submitReport() async {
    // Unfocus any text fields before submitting
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    // Capture controller values early to avoid using them after dispose
    final String issueText = _issueController.text.trim();
    final String additionalText = _additionalInfoController.text.trim();
    final List imageFilesSnapshot = List.from(_imageFiles);

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
        throw Exception(
            'Failed to fetch user info. Please try logging in again.');
      }

      if (issueText.isEmpty) {
        throw Exception('Issue description is required');
      }

      if (_isPublicReport && _selectedLocation == null) {
        throw Exception('Please select a location for public report');
      }

      if (!_isPublicReport && userInfo['location'] == null) {
        throw Exception('User location not found. Please update your profile.');
      }

      // Get current date and time for real-time submission
      final now = DateTime.now();

      final reportData = {
        'userId': userInfo['userId'],
        'fullName': userInfo['fullName'],
        'contactNumber': userInfo['contactNumber'],
        'issueDescription': issueText,
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
        'dateTime': Timestamp.fromDate(now), // Current date and time
        'createdAt': Timestamp.now(), // Also store creation timestamp
        'status': 'Unfixed Reports',
        'isPublic': _isPublicReport,
      };

      if (additionalText.isNotEmpty) {
        reportData['additionalLocationInfo'] = additionalText;
      }

      // Convert multiple images to base64 using snapshot
      if (imageFilesSnapshot.isNotEmpty) {
        final base64Images = await _convertImagesToBase64(
            imageFilesSnapshot.cast<XFile>());
        if (base64Images.isNotEmpty) {
          reportData['images'] = base64Images;
          reportData['imageCount'] = base64Images.length;
        }
      }

      // Add report with timeout
      final reportRef = await FirebaseFirestore.instance
          .collection('reports')
          .add(reportData)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
              'Report submission timed out. Please try again.');
        },
      );
      final reportId = reportRef.id;

      // If public report, notify all plumbers
      if (_isPublicReport) {
        final plumbersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Plumber')
            .get();
        for (var plumberDoc in plumbersSnapshot.docs) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': plumberDoc.id,
            'reportId': reportId,
            'type': 'public_report',
            'title': 'New Public Report',
            'message':
                'Resident ${userInfo['fullName']} reported: $issueText at ${reportData['placeName']}',
            'timestamp': Timestamp.now(),
            'read': false,
          });
        }
      }

      // Log the report submission (non-blocking)
      FirebaseFirestore.instance.collection('logs').add({
        'action': 'Report Submitted',
        'userId': userInfo['userId'],
        'details':
            'Report submitted by ${userInfo['fullName']}: $issueText with ${imageFilesSnapshot.length} images',
        'timestamp': FieldValue.serverTimestamp(),
      }).catchError((e) {
        print('Error writing log entry: $e');
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Report submitted successfully with ${imageFilesSnapshot.length} images'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Reset form
      if (mounted) {
        setState(() {
          _issueController.clear();
          _additionalInfoController.clear();
          _imageFiles.clear();
          _imageNameController.clear();
          _selectedLocation = null;
          _selectedPlaceName = null;
          _locationController.clear();
          _isPublicReport = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      String errorMsg = 'Error submitting report';
      if (e is TimeoutException) {
        errorMsg = e.message;
      } else {
        errorMsg = e.toString().replaceAll('Exception: ', '');
      }

      setState(() {
        _errorMessage = errorMsg;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
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
                    autocorrect: false,
                    enableSuggestions: false,
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
    FocusNode? focusNode,
  }) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: 100 * (maxLines == 2 ? 1 : maxLines + 2)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          validator: validator,
          cursorColor: accentColor,
          style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
          // Disable autocorrect and suggestions to prevent lag
          autocorrect: false,
          enableSuggestions: false,
          // Optimize keyboard type
          keyboardType:
              maxLines > 1 ? TextInputType.multiline : TextInputType.text,
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

  // Widget to display selected images
  Widget _selectedImagesPreview() {
    if (_imageFiles.isEmpty) return const SizedBox.shrink();

    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: const Duration(milliseconds: 450),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Selected Images (${_imageFiles.length}/10):',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_imageFiles.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearAllImages,
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: Text(
                      'Clear All',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _imageFiles.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _imageFiles.length - 1 ? 8 : 0,
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_imageFiles[index].path),
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 120,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
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
                                  size: 16, color: Colors.red),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportsCompilationButton() {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.all(16),
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
                Icon(Icons.collections_bookmark, color: accentColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'View All Reports',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'View complete details of all your submitted reports including status, images, location, and more.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportsCompilationPage(),
                    ),
                  );
                },
                icon: Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(
                  'Open Reports Compilation',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: Colors.grey.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super
        .build(context); // Important: Required by AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: _listKey, // Add PageStorageKey here to preserve scroll/focus
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
                      focusNode: _issueFocusNode,
                      label: 'Issue Description *',
                      icon: Icons.report_problem_outlined,
                      maxLines: 2,
                      validator: (v) => v!.trim().isEmpty
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
                        focusNode: _additionalInfoFocusNode,
                        label: 'Additional Location Information',
                        icon: Icons.info_outline,
                        hint: 'Optional details about the location',
                        validator: (v) => null,
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: _modernField(
                            controller: _imageNameController,
                            label: 'Upload Images (${_imageFiles.length}/10)',
                            icon: Icons.image_outlined,
                            readOnly: true,
                            validator: (v) => null,
                            hint: _imageFiles.isEmpty
                                ? 'No images selected'
                                : '${_imageFiles.length} images selected',
                          ),
                        ),
                        const SizedBox(width: 8),
                        FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          delay: const Duration(milliseconds: 400),
                          child: PopupMenuButton<String>(
                            icon: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            onSelected: (value) {
                              if (value == 'gallery') {
                                _pickImages();
                              } else if (value == 'camera') {
                                _takePhoto();
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return [
                                PopupMenuItem<String>(
                                  value: 'gallery',
                                  child: Row(
                                    children: [
                                      Icon(Icons.photo_library,
                                          color: accentColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Choose from Gallery',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'camera',
                                  child: Row(
                                    children: [
                                      Icon(Icons.camera_alt,
                                          color: accentColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Take Photo',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ],
                    ),
                    // Display selected images
                    _selectedImagesPreview(),
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
              // Reports Compilation Button
              _reportsCompilationButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// New Reports Compilation Page
class ReportsCompilationPage extends StatefulWidget {
  const ReportsCompilationPage({super.key});

  @override
  State<ReportsCompilationPage> createState() => _ReportsCompilationPageState();
}

class _ReportsCompilationPageState extends State<ReportsCompilationPage> {
  final Color accentColor = const Color(0xFF0288D1);
  final user = FirebaseAuth.instance.currentUser;
  String _searchQuery = '';
  String _selectedStatus = 'All';
  List<String> statusOptions = [
    'All',
    'Unfixed Reports',
    'Fixed',
    'In Progress'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          'Reports Compilation',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: accentColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 12),
                // Status Filter
                Container(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: statusOptions.length,
                    itemBuilder: (context, index) {
                      final status = statusOptions[index];
                      final isSelected = _selectedStatus == status;
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index < statusOptions.length - 1 ? 8 : 0,
                        ),
                        child: ChoiceChip(
                          label: Text(
                            status,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: accentColor,
                          backgroundColor: Colors.grey.shade200,
                          onSelected: (selected) {
                            setState(() {
                              _selectedStatus = selected ? status : 'All';
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Reports List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: accentColor,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading reports',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reports found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Submit your first report to see it here',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter reports
                List<QueryDocumentSnapshot> filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Status filter
                  if (_selectedStatus != 'All' &&
                      data['status'] != _selectedStatus) {
                    return false;
                  }

                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    final issueDesc = (data['issueDescription'] ?? '')
                        .toString()
                        .toLowerCase();
                    final placeName =
                        (data['placeName'] ?? '').toString().toLowerCase();
                    final status =
                        (data['status'] ?? '').toString().toLowerCase();

                    return issueDesc.contains(_searchQuery.toLowerCase()) ||
                        placeName.contains(_searchQuery.toLowerCase()) ||
                        status.contains(_searchQuery.toLowerCase());
                  }

                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matching reports',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search or filter',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final reportId = doc.id;

                    return _buildReportCard(data, reportId, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
      Map<String, dynamic> data, String reportId, int index) {
    final issueDesc = data['issueDescription'] ?? 'No description';
    final placeName = data['placeName'] ?? 'Unknown location';
    final status = data['status'] ?? 'Unfixed Reports';
    final dateTime =
        (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final imageCount = data['imageCount'] ?? 0;
    final isPublic = data['isPublic'] ?? false;
    final additionalInfo = data['additionalLocationInfo'] ?? '';

    // Status color
    Color statusColor = Colors.red.shade700;
    if (status == 'Fixed') {
      statusColor = Colors.green.shade700;
    } else if (status == 'In Progress') {
      statusColor = Colors.orange.shade800;
    }

    return FadeInUp(
      duration: Duration(milliseconds: 300 + (index * 100)),
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
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
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.report_problem_outlined,
              color: accentColor,
              size: 24,
            ),
          ),
          title: Text(
            issueDesc.length > 40
                ? '${issueDesc.substring(0, 40)}...'
                : issueDesc,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          trailing: Chip(
            label: Text(
              status.replaceAll('Reports', ''),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            backgroundColor: statusColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          ),
          children: [
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report ID
                  Row(
                    children: [
                      Icon(Icons.fingerprint,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Report ID: $reportId',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Full Issue Description
                  Text(
                    'Issue Description:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issueDesc,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location Information
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location:',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              placeName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            if (additionalInfo.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Additional Info: $additionalInfo',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Report Type
                  Row(
                    children: [
                      Icon(Icons.public_outlined,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Report Type: ${isPublic ? 'Public' : 'Private'}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Images Count
                  if (imageCount > 0)
                    Row(
                      children: [
                        Icon(Icons.image_outlined,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Images: $imageCount',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  if (imageCount > 0) const SizedBox(height: 12),

                  // Status with icon
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: $status',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Full Date Time
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM dd, yyyy • hh:mm:ss a')
                            .format(dateTime),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Fixed':
        return Icons.check_circle_outline;
      case 'In Progress':
        return Icons.build_outlined;
      case 'Unfixed Reports':
      default:
        return Icons.report_problem_outlined;
    }
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

class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);

  @override
  String toString() => message;
}
