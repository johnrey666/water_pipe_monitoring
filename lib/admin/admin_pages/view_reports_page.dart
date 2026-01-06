// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../components/admin_layout.dart';
import 'monitor_page.dart';
import 'admin_view_reported_reports.dart';

class ViewReportsPage extends StatefulWidget {
  const ViewReportsPage({super.key});
  @override
  State<ViewReportsPage> createState() => _ViewReportsPageState();
}

class _ViewReportsPageState extends State<ViewReportsPage> {
  int _currentPage = 0;
  final int _pageSize = 5;
  String _selectedStatus = 'All';
  String? _selectedPlumberUid;
  List<Map<String, dynamic>> _plumbers = [];
  Map<String, List<DocumentSnapshot?>> _lastDocuments = {
    'All': [null],
    'Monitoring': [null],
    'Unfixed Reports': [null],
    'Fixed': [null],
    'Illegal Tapping': [null],
  };
  Map<String, int> _totalPages = {
    'All': 1,
    'Monitoring': 1,
    'Unfixed Reports': 1,
    'Fixed': 1,
    'Illegal Tapping': 1,
  };
  bool _isLoading = false;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Monitoring':
        return const Color(0xFF2F8E2F);
      case 'Unfixed Reports':
        return const Color(0xFFD94B3B);
      case 'Fixed':
        return const Color(0xFFC18B00);
      case 'Illegal Tapping':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _fetchPlumbers() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Plumber')
          .get();
      setState(() {
        _plumbers = querySnapshot.docs
            .map((doc) => {
                  'uid': doc.id,
                  'fullName': doc.data()['fullName'] ?? 'Unknown Plumber'
                })
            .toList();
      });
    } catch (e) {
      print('Error fetching plumbers: $e');
    }
  }

  Future<void> _fetchTotalPages(String status) async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance.collection('reports');
      if (status != 'All') {
        if (status == 'Illegal Tapping') {
          query = query.where('isIllegalTapping', isEqualTo: true);
        } else {
          query = query.where('status', isEqualTo: status);
        }
      }
      if (_selectedPlumberUid != null) {
        query = query.where('assignedPlumber', isEqualTo: _selectedPlumberUid);
      }
      final snapshot = await query.get();
      final totalDocs = snapshot.docs.length;
      setState(() {
        _totalPages[status] = (totalDocs / _pageSize).ceil();
        while (_lastDocuments[status]!.length < _totalPages[status]!) {
          _lastDocuments[status]!.add(null);
        }
      });
    } catch (e) {
      print('Error fetching total pages for $status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Stream<QuerySnapshot> _getReportsStream() {
    Query query = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);
    if (_selectedStatus != 'All') {
      if (_selectedStatus == 'Illegal Tapping') {
        query = query.where('isIllegalTapping', isEqualTo: true);
      } else {
        query = query.where('status', isEqualTo: _selectedStatus);
      }
    }
    if (_selectedPlumberUid != null) {
      query = query.where('assignedPlumber', isEqualTo: _selectedPlumberUid);
    }
    if (_currentPage > 0 &&
        _lastDocuments[_selectedStatus]![_currentPage - 1] != null) {
      query = query.startAfterDocument(
          _lastDocuments[_selectedStatus]![_currentPage - 1]!);
    }
    return query.snapshots();
  }

  Widget _buildPaginationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _currentPage > 0 && !_isLoading
              ? () => setState(() => _currentPage--)
              : null,
          child: Text(
            'Previous',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _currentPage > 0 ? const Color(0xFF4FC3F7) : Colors.grey,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalPages[_selectedStatus]!, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                onPressed:
                    _isLoading ? null : () => setState(() => _currentPage = i),
                style: TextButton.styleFrom(
                  backgroundColor: _currentPage == i
                      ? const Color(0xFF4FC3F7)
                      : Colors.grey.shade200,
                  foregroundColor:
                      _currentPage == i ? Colors.white : Colors.grey.shade800,
                  minimumSize: const Size(32, 32),
                  padding: const EdgeInsets.all(0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
        TextButton(
          onPressed:
              _currentPage < _totalPages[_selectedStatus]! - 1 && !_isLoading
                  ? () {
                      setState(() {
                        _currentPage++;
                        if (_currentPage >=
                            _lastDocuments[_selectedStatus]!.length) {
                          _lastDocuments[_selectedStatus]!.add(null);
                        }
                      });
                    }
                  : null,
          child: Text(
            'Next',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _currentPage < _totalPages[_selectedStatus]! - 1
                  ? const Color(0xFF4FC3F7)
                  : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String status) {
    final isSelected = _selectedStatus == status;
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () {
              setState(() {
                _selectedStatus = status;
                _currentPage = 0;
                _fetchTotalPages(status);
              });
            },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFF4FC3F7) : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.grey.shade800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(status),
    );
  }

  // Fixed map location picker with better interaction
  Future<LatLng?> _showMapLocationPicker(BuildContext context) async {
    LatLng selectedLocation =
        const LatLng(13.294678436001885, 123.75569591912894);
    MapController mapController = MapController();

    return showDialog<LatLng>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 800,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📍 Select Tap Location',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          IconButton(
                            icon:
                                Icon(Icons.close, color: Colors.grey.shade600),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    // Map Area
                    Expanded(
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: selectedLocation,
                              initialZoom: 16,
                              minZoom: 13,
                              maxZoom: 19,
                              interactionOptions: const InteractionOptions(
                                flags: ~InteractiveFlag.rotate,
                              ),
                              onTap: (tapPosition, latLng) {
                                setState(() {
                                  selectedLocation = latLng;
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c'],
                                userAgentPackageName: 'com.example.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: selectedLocation,
                                    width: 60,
                                    height: 60,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_pin,
                                        color: Colors.red,
                                        size: 48,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Location Info
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
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
                                      Icon(Icons.info,
                                          color: Colors.blue.shade600,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tap anywhere on the map to select location',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.green.shade600,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Location Selected',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                              Text(
                                                'Lat: ${selectedLocation.latitude.toStringAsFixed(6)}, Lng: ${selectedLocation.longitude.toStringAsFixed(6)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom Controls
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      mapController.move(
                                        const LatLng(13.294678436001885,
                                            123.75569591912894),
                                        16,
                                      );
                                    },
                                    icon: Icon(Icons.my_location,
                                        color: Colors.blue.shade700),
                                    label: Text(
                                      'Center Map',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(
                                          color: Colors.blue.shade300),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context, selectedLocation);
                                    },
                                    icon:
                                        Icon(Icons.check, color: Colors.white),
                                    label: Text(
                                      'Confirm Location',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Zoom Controls
                          Positioned(
                            right: 16,
                            bottom: 100,
                            child: Column(
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'zoom_in',
                                  onPressed: () {
                                    mapController.move(
                                      mapController.camera.center,
                                      mapController.camera.zoom + 1,
                                    );
                                  },
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue.shade700,
                                  child: const Icon(Icons.add),
                                ),
                                const SizedBox(height: 8),
                                FloatingActionButton.small(
                                  heroTag: 'zoom_out',
                                  onPressed: () {
                                    mapController.move(
                                      mapController.camera.center,
                                      mapController.camera.zoom - 1,
                                    );
                                  },
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue.shade700,
                                  child: const Icon(Icons.remove),
                                ),
                              ],
                            ),
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
      },
    );
  }

  // Platform-aware image handling
  Future<List<String>> _convertImagesToBase64(List<dynamic> imageFiles) async {
    final List<String> base64Images = [];

    for (final imageFile in imageFiles) {
      try {
        if (kIsWeb) {
          // For web: use html.File
          final html.File webFile = imageFile;
          final reader = html.FileReader();

          // Create a completer to wait for the file to load
          final completer = Completer<void>();
          reader.onLoad.listen((event) {
            completer.complete();
          });

          reader.readAsDataUrl(webFile);
          await completer.future;

          final dataUrl = reader.result as String;
          // Remove data:image/*;base64, prefix
          final commaIndex = dataUrl.indexOf(',');
          final base64Data = dataUrl.substring(commaIndex + 1);
          base64Images.add(base64Data);
        } else {
          // For mobile: use File
          final File mobileFile = imageFile;
          final bytes = await mobileFile.readAsBytes();
          final base64Image = base64Encode(bytes);
          base64Images.add(base64Image);
        }
      } catch (e) {
        print('Error encoding image: $e');
      }
    }

    return base64Images;
  }

  // Platform-aware image preview widget
  Widget _buildImagePreview(
      dynamic imageFile, int index, VoidCallback onRemove) {
    if (kIsWeb) {
      // Web: use html.File to create object URL
      return FutureBuilder<String?>(
        future: () async {
          try {
            final html.File webFile = imageFile;
            final String url = html.Url.createObjectUrlFromBlob(webFile);
            return url;
          } catch (e) {
            print('Error creating object URL: $e');
            return null;
          }
        }(),
        builder: (context, snapshot) {
          final url = snapshot.data;
          return Container(
            margin: EdgeInsets.only(
              right: index < 9 ? 8 : 0,
            ),
            width: 120,
            height: 120,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: url != null
                      ? Image.network(
                          url,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 120,
                              height: 120,
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
                        )
                      : Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 24,
                      height: 24,
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
                      child:
                          const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      );
    } else {
      // Mobile: use File
      final File mobileFile = imageFile;
      return Container(
        margin: EdgeInsets.only(
          right: index < 9 ? 8 : 0,
        ),
        width: 120,
        height: 120,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                mobileFile,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
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
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
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
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    }
  }

  // Web-specific file picker
  Future<List<html.File>?> _pickImagesWeb() async {
    final input = html.FileUploadInputElement();
    input
      ..multiple = true
      ..accept = 'image/*'
      ..click();

    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      return input.files!.toList();
    }
    return null;
  }

  // Web-specific camera access (fallback to file picker)
  Future<html.File?> _takePhotoWeb() async {
    final input = html.FileUploadInputElement();
    input
      ..accept = 'image/*'
      ..click();

    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      return input.files!.first;
    }
    return null;
  }

  // NEW FUNCTION: Show assessment/fix details for illegal tapping reports
  void _showAssessmentDetails(BuildContext context, DocumentSnapshot report) {
    final data = report.data() as Map<String, dynamic>;
    final assessment = data['assessment']?.toString();
    final beforeFixImages = data['beforeFixImages'] != null
        ? List<String>.from(data['beforeFixImages'])
        : <String>[];
    final afterFixImages = data['afterFixImages'] != null
        ? List<String>.from(data['afterFixImages'])
        : <String>[];
    final fixedByName = data['fixedByName']?.toString() ?? 'Unknown Plumber';
    final fixedAt = data['fixedAt']?.toDate();
    final status = data['status']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: status == 'Fixed'
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status == 'Fixed'
                            ? Icons.check_circle
                            : Icons.assessment,
                        color: status == 'Fixed'
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          status == 'Fixed'
                              ? 'Fix Details'
                              : 'Assessment Details',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: status == 'Fixed'
                                ? Colors.green.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.grey.shade600, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status and plumber info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: status == 'Fixed'
                                ? Colors.green.shade100
                                : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: status == 'Fixed'
                                  ? Colors.green.shade200
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                status == 'Fixed' ? Icons.check : Icons.person,
                                color: status == 'Fixed'
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status == 'Fixed'
                                          ? 'Fixed by $fixedByName'
                                          : 'Assessed by $fixedByName',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: status == 'Fixed'
                                            ? Colors.green.shade800
                                            : Colors.blue.shade800,
                                      ),
                                    ),
                                    if (fixedAt != null)
                                      Text(
                                        DateFormat.yMMMd()
                                            .add_jm()
                                            .format(fixedAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Assessment text
                        if (assessment != null && assessment.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assessment:',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  assessment,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),

                        // Before fix images
                        if (beforeFixImages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Before Fix Images (${beforeFixImages.length}):',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildImageGrid(beforeFixImages),
                              const SizedBox(height: 20),
                            ],
                          ),

                        // After fix images
                        if (afterFixImages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'After Fix Images (${afterFixImages.length}):',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildImageGrid(afterFixImages),
                            ],
                          ),

                        // No assessment/fix message
                        if (assessment == null &&
                            beforeFixImages.isEmpty &&
                            afterFixImages.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  status == 'Fixed'
                                      ? 'No fix details recorded yet.'
                                      : 'No assessment recorded yet.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FC3F7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper function to build image grid
  Widget _buildImageGrid(List<String> base64Images) {
    if (base64Images.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: base64Images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showFullScreenImage(context, base64Images[index]),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(base64Images[index]),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper function to show full screen image
  void _showFullScreenImage(BuildContext context, String base64Image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.9),
            child: Center(
              child: InteractiveViewer(
                maxScale: 5.0,
                child: Image.memory(
                  base64Decode(base64Image),
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 60,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Updated minimalist illegal tapping report dialog with platform-aware image handling
  void _showCreateIllegalTappingDialog(BuildContext context) {
    String locationName = '';
    String type = 'Unauthorized Connection';
    String description = '';
    String evidenceNotes = '';
    LatLng? selectedLocation;
    List<dynamic> _imageFiles =
        []; // Changed to dynamic for platform compatibility
    bool isUploading = false;
    String? _errorMessage;

    final formKey = GlobalKey<FormState>();
    final _picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _pickImages() async {
              try {
                if (kIsWeb) {
                  final images = await _pickImagesWeb();
                  if (images != null && images.isNotEmpty) {
                    final newImages =
                        images.take(10 - _imageFiles.length).toList();
                    setState(() {
                      _imageFiles.addAll(newImages);
                      _errorMessage = null;
                    });
                  }
                } else {
                  final List<XFile>? images = await _picker.pickMultiImage(
                    maxWidth: 1920,
                    maxHeight: 1080,
                    imageQuality: 85,
                  );

                  if (images != null && images.isNotEmpty) {
                    final newImages =
                        images.take(10 - _imageFiles.length).toList();
                    final newFiles = <File>[];
                    for (var image in newImages) {
                      newFiles.add(File(image.path));
                    }
                    setState(() {
                      _imageFiles.addAll(newFiles);
                      _errorMessage = null;
                    });
                  }
                }
              } catch (e) {
                setState(() {
                  _errorMessage = 'Error picking images: $e';
                });
              }
            }

            Future<void> _takePhoto() async {
              try {
                if (kIsWeb) {
                  final photo = await _takePhotoWeb();
                  if (photo != null) {
                    setState(() {
                      if (_imageFiles.length < 10) {
                        _imageFiles.add(photo);
                      } else {
                        _errorMessage = 'Maximum 10 images allowed';
                      }
                    });
                  }
                } else {
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1920,
                    maxHeight: 1080,
                    imageQuality: 85,
                  );

                  if (image != null) {
                    setState(() {
                      if (_imageFiles.length < 10) {
                        _imageFiles.add(File(image.path));
                      } else {
                        _errorMessage = 'Maximum 10 images allowed';
                      }
                    });
                  }
                }
              } catch (e) {
                setState(() {
                  _errorMessage = 'Error taking photo: $e';
                });
              }
            }

            void removeImage(int index) {
              setState(() {
                _imageFiles.removeAt(index);
              });
            }

            void _clearAllImages() {
              setState(() {
                _imageFiles.clear();
              });
            }

            Widget _selectedImagesPreview() {
              if (_imageFiles.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(top: 12),
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
                            icon: const Icon(Icons.delete,
                                size: 16, color: Colors.red),
                            label: Text(
                              'Clear All',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: _imageFiles.isEmpty
                          ? Container(
                              alignment: Alignment.center,
                              child: Text(
                                'No images selected',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imageFiles.length,
                              itemBuilder: (context, index) {
                                return _buildImagePreview(
                                  _imageFiles[index],
                                  index,
                                  () => removeImage(index),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            }

            Future<void> submitReport() async {
              if (formKey.currentState!.validate() &&
                  selectedLocation != null) {
                formKey.currentState!.save();
                setState(() => isUploading = true);

                try {
                  // Convert images to base64
                  final base64Images =
                      await _convertImagesToBase64(_imageFiles);

                  final reportData = {
                    'fullName': 'Staff Report',
                    'issueDescription': 'ILLEGAL TAPPING: $description',
                    'placeName': locationName,
                    'location': GeoPoint(
                      selectedLocation!.latitude,
                      selectedLocation!.longitude,
                    ),
                    'status': 'Illegal Tapping',
                    'isIllegalTapping': true,
                    'illegalTappingType': type,
                    'evidenceNotes': evidenceNotes,
                    'evidenceImages': base64Images,
                    'priority': 'high',
                    'requiresInvestigation': true,
                    'createdAt': FieldValue.serverTimestamp(),
                    'reportedByStaff': true,
                    'assignedPlumber': null,
                    'hasEvidence': base64Images.isNotEmpty,
                    'imageCount': base64Images.length,
                  };

                  await FirebaseFirestore.instance
                      .collection('reports')
                      .add(reportData);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Illegal tapping report submitted successfully!',
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                  _fetchTotalPages(_selectedStatus);
                } catch (e) {
                  setState(() {
                    _errorMessage = 'Error: ${e.toString()}';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: ${e.toString()}',
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                } finally {
                  setState(() => isUploading = false);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                            'Please select a location and fill all required fields'),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minimal Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.red.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Report Illegal Tapping',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: Colors.grey.shade600, size: 20),
                              onPressed: isUploading
                                  ? null
                                  : () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Error Message
                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),

                              // Location Field
                              Text(
                                'Location',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Location Selection
                              if (selectedLocation == null)
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final location =
                                          await _showMapLocationPicker(context);
                                      if (location != null) {
                                        setState(() {
                                          selectedLocation = location;
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade50,
                                      foregroundColor: Colors.blue.shade800,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text('Select Location on Map'),
                                  ),
                                ),

                              if (selectedLocation != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.green.shade600,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Location Selected',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                            Text(
                                              'Lat: ${selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${selectedLocation!.longitude.toStringAsFixed(6)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit,
                                            size: 18,
                                            color: Colors.blue.shade700),
                                        onPressed: () async {
                                          final location =
                                              await _showMapLocationPicker(
                                                  context);
                                          if (location != null) {
                                            setState(() {
                                              selectedLocation = location;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Location Name
                              SizedBox(
                                height: 70,
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Location Name / Address',
                                    hintText: 'Enter exact address or landmark',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  onSaved: (value) =>
                                      locationName = value ?? '',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter location name';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Type of Illegal Activity
                              Text(
                                'Type of Illegal Activity',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 70,
                                child: DropdownButtonFormField(
                                  value: type,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'Unauthorized Connection',
                                      child: Text('Unauthorized Connection'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Meter Tampering/Bypass',
                                      child: Text('Meter Tampering/Bypass'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Pipe Diversion',
                                      child: Text('Pipe Diversion'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Other Illegal Activity',
                                      child: Text('Other Illegal Activity'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => type = value!);
                                  },
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Description
                              Text(
                                'Description',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 120,
                                child: TextFormField(
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Detailed description',
                                    hintText: 'Describe what you observed...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  onSaved: (value) => description = value ?? '',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter description';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Evidence Photos
                              Text(
                                'Evidence Photos',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload clear photos as evidence (Max 10)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: OutlinedButton.icon(
                                        onPressed: _imageFiles.length < 10
                                            ? _pickImages
                                            : null,
                                        icon:
                                            Icon(Icons.photo_library, size: 18),
                                        label: Text('Gallery'),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: OutlinedButton.icon(
                                        onPressed: _imageFiles.length < 10
                                            ? _takePhoto
                                            : null,
                                        icon: Icon(Icons.camera_alt, size: 18),
                                        label: Text('Camera'),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Display selected images
                              _selectedImagesPreview(),

                              const SizedBox(height: 20),

                              // Additional Notes (Optional)
                              SizedBox(
                                height: 100,
                                child: TextFormField(
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Additional Notes (Optional)',
                                    hintText: 'Witness info, time, etc.',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  onSaved: (value) =>
                                      evidenceNotes = value ?? '',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer Actions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: isUploading
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text('Cancel'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: isUploading ? null : submitReport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: isUploading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.send, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Submit Report',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchPlumbers();
    _fetchTotalPages('All');
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'View Reports',
      selectedRoute: '/reports',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with filter buttons and action buttons
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterButton('All'),
                          _buildFilterButton('Monitoring'),
                          _buildFilterButton('Unfixed Reports'),
                          _buildFilterButton('Fixed'),
                          _buildFilterButton('Illegal Tapping'),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ViewReportedReportsPage(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.report_problem,
                            size: 18,
                          ),
                          label: Text(
                            'View Plumber Reports',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            elevation: 2,
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showCreateIllegalTappingDialog(context);
                          },
                          icon: const Icon(Icons.warning, size: 18),
                          label: Text(
                            'Report Illegal Tapping',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 300,
                  height: 70,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filter by Plumber',
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF4FC3F7), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Colors.grey, width: 1),
                      ),
                    ),
                    value: _selectedPlumberUid,
                    dropdownColor: Colors.white,
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All Plumbers',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                      ..._plumbers.map((plumber) {
                        return DropdownMenuItem<String>(
                          value: plumber['uid'],
                          child: Text(
                            plumber['fullName'],
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _selectedPlumberUid = value;
                              _currentPage = 0;
                              _lastDocuments[_selectedStatus] = [null];
                              _fetchTotalPages(_selectedStatus);
                            });
                          },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getReportsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('StreamBuilder error: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error loading reports: ${snapshot.error}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {
                                  _currentPage = 0;
                                  _lastDocuments[_selectedStatus] = [null];
                                  _fetchTotalPages(_selectedStatus);
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4FC3F7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final reports = snapshot.data?.docs ?? [];
                      if (reports.isEmpty) {
                        return Center(
                          child: Text(
                            _selectedStatus == 'All'
                                ? 'No reports found.'
                                : 'No $_selectedStatus reports found.',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      if (reports.isNotEmpty) {
                        if (_currentPage >=
                            _lastDocuments[_selectedStatus]!.length) {
                          _lastDocuments[_selectedStatus]!.add(reports.last);
                        } else {
                          _lastDocuments[_selectedStatus]![_currentPage] =
                              reports.last;
                        }
                      }
                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: reports.length,
                              itemBuilder: (context, index) {
                                final report = reports[index];
                                final data =
                                    report.data() as Map<String, dynamic>;
                                final fullName = data['fullName'] ?? 'Unknown';
                                final issueDescription =
                                    data['issueDescription'] ??
                                        'No description';
                                final createdAt = data['createdAt']?.toDate();
                                final status =
                                    data['status'] ?? 'Unfixed Reports';
                                final formattedDate = createdAt != null
                                    ? DateFormat.yMMMd().format(createdAt)
                                    : 'Unknown date';
                                final isIllegalTapping =
                                    data['isIllegalTapping'] ?? false;
                                final hasEvidence =
                                    data['hasEvidence'] ?? false;
                                final evidenceImages = data['evidenceImages'] !=
                                        null
                                    ? List<String>.from(data['evidenceImages'])
                                    : <String>[];
                                final hasAssessment =
                                    data['assessment'] != null;
                                final hasFixImages =
                                    data['beforeFixImages'] != null ||
                                        data['afterFixImages'] != null;
                                final isFixed = status == 'Fixed';

                                // For illegal tapping, show special badge
                                final displayStatus = isIllegalTapping
                                    ? 'Illegal Tapping'
                                    : status;
                                return Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: FadeInUp(
                                    duration: const Duration(milliseconds: 300),
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                      shadowColor: Colors.black12,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 60,
                                              color: _getStatusColor(
                                                  displayStatus),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.circle,
                                                        size: 10,
                                                        color: _getStatusColor(
                                                            displayStatus),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              fullName,
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .grey
                                                                    .shade800,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            if (isIllegalTapping)
                                                              Container(
                                                                margin: EdgeInsets
                                                                    .only(
                                                                        left:
                                                                            8),
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .red,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                child: Text(
                                                                  'ILLEGAL',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            if (hasEvidence)
                                                              Container(
                                                                margin: EdgeInsets
                                                                    .only(
                                                                        left:
                                                                            4),
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            4,
                                                                        vertical:
                                                                            2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .green,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .photo_camera,
                                                                      size: 10,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    SizedBox(
                                                                        width:
                                                                            2),
                                                                    Text(
                                                                      '${evidenceImages.length}',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            8,
                                                                        color: Colors
                                                                            .white,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    issueDescription,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '$displayStatus • $formattedDate',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                      if (isIllegalTapping &&
                                                          data['priority'] ==
                                                              'high')
                                                        Container(
                                                          margin:
                                                              EdgeInsets.only(
                                                                  left: 8),
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.orange
                                                                .shade100,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                            border: Border.all(
                                                              color: Colors
                                                                  .orange
                                                                  .shade300,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            'HIGH PRIORITY',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .orange
                                                                  .shade800,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Button(s) section
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // View Assessment/Fix button (only for illegal tapping with assessment or fix images)
                                                if (isIllegalTapping &&
                                                    (hasAssessment ||
                                                        hasFixImages ||
                                                        isFixed))
                                                  SizedBox(
                                                    width: 60,
                                                    height: 36,
                                                    child: TextButton(
                                                      onPressed: () {
                                                        _showAssessmentDetails(
                                                            context, report);
                                                      },
                                                      child: Text(
                                                        isFixed
                                                            ? 'View Fix'
                                                            : 'View Assessment',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 10,
                                                          color: isFixed
                                                              ? Colors.green
                                                              : const Color(
                                                                  0xFF4FC3F7),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                SizedBox(
                                                  width: 60,
                                                  height: 36,
                                                  child: TextButton(
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              MonitorPage(
                                                            reportId: report.id,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Text(
                                                      'View',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color: const Color(
                                                            0xFF4FC3F7),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            height: 60,
                            child: _buildPaginationButtons(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
