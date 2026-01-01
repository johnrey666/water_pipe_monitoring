import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

  // Updated minimalist illegal tapping report dialog
  void _showCreateIllegalTappingDialog(BuildContext context) {
    String locationName = '';
    String type = 'Unauthorized Connection';
    String description = '';
    String evidenceNotes = '';
    LatLng? selectedLocation;
    List<String> base64Images = [];
    bool isUploading = false;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 70,
                maxWidth: 1200,
              );
              if (pickedFile != null) {
                final bytes = await File(pickedFile.path).readAsBytes();
                final base64String = base64Encode(bytes);
                setState(() {
                  base64Images.add(base64String);
                });
              }
            }

            void removeImage(int index) {
              setState(() {
                base64Images.removeAt(index);
              });
            }

            Widget _buildImagePreview(String base64Image) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(base64Image),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            }

            Future<void> submitReport() async {
              if (formKey.currentState!.validate() &&
                  selectedLocation != null) {
                formKey.currentState!.save();
                setState(() => isUploading = true);

                try {
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
                                ElevatedButton(
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
                                    minimumSize: Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text('Select Location on Map'),
                                ),

                              if (selectedLocation != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
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
                              TextFormField(
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
                                onSaved: (value) => locationName = value ?? '',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter location name';
                                  }
                                  return null;
                                },
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
                              DropdownButtonFormField(
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
                              TextFormField(
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

                              OutlinedButton.icon(
                                onPressed:
                                    base64Images.length < 10 ? pickImage : null,
                                icon: Icon(Icons.photo_camera, size: 18),
                                label: Text('Upload Photos'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),

                              if (base64Images.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Uploaded Photos (${base64Images.length}/10):',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(base64Images.length,
                                      (index) {
                                    return Stack(
                                      children: [
                                        _buildImagePreview(base64Images[index]),
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: IconButton(
                                            icon: CircleAvatar(
                                              backgroundColor: Colors.red,
                                              radius: 10,
                                              child: Icon(Icons.close,
                                                  size: 12,
                                                  color: Colors.white),
                                            ),
                                            onPressed: () => removeImage(index),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Additional Notes (Optional)
                              TextFormField(
                                maxLines: 2,
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
                                onSaved: (value) => evidenceNotes = value ?? '',
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
                              child: OutlinedButton(
                                onPressed: isUploading
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isUploading ? null : submitReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                // For illegal tapping, show special badge
                                final displayStatus = isIllegalTapping
                                    ? 'Illegal Tapping'
                                    : status;
                                return FadeInUp(
                                  duration: const Duration(milliseconds: 300),
                                  child: Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
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
                                            color:
                                                _getStatusColor(displayStatus),
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
                                                              color: Colors.grey
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
                                                                      left: 8),
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color:
                                                                    Colors.red,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                              child: Text(
                                                                'ILLEGAL',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontSize: 10,
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
                                                                      left: 4),
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
                                                                      width: 2),
                                                                  Text(
                                                                    '${evidenceImages.length}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          8,
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
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
                                                    color: Colors.grey.shade600,
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
                                                        margin: EdgeInsets.only(
                                                            left: 8),
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .orange.shade100,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          border: Border.all(
                                                            color: Colors.orange
                                                                .shade300,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          'HIGH PRIORITY',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 10,
                                                            color: Colors.orange
                                                                .shade800,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
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
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: const Color(0xFF4FC3F7),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildPaginationButtons(),
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
