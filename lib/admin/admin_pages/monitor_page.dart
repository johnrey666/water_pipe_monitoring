import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/admin_layout.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';

class MonitorPage extends StatefulWidget {
  final String? reportId; // Optional report ID to open modal

  const MonitorPage({super.key, this.reportId});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  OverlayEntry? _errorOverlay;

  Future<List<Map<String, dynamic>>> _fetchPlumbers() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Plumber') // Match the exact case
          .get();
      print('Fetched plumbers: ${querySnapshot.docs.length} documents');
      final plumbers = querySnapshot.docs
          .map((doc) => {
                'uid': doc.id,
                'fullName': doc.data()['fullName'] ?? 'Unknown Plumber'
              })
          .toList();
      print('Plumbers data: $plumbers');
      return plumbers;
    } catch (e) {
      print('Error fetching plumbers: $e');
      _showErrorOverlay('Failed to load plumbers: $e');
      return [];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check authentication and trigger modal if reportId is valid
    if (FirebaseAuth.instance.currentUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (widget.reportId != null && widget.reportId!.isNotEmpty) {
      _fetchAndShowReportModal(widget.reportId!);
    }
  }

  Future<void> _fetchAndShowReportModal(String reportId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _showReportModal(context, data, reportId);
      } else {
        _showErrorOverlay('Report not found. Please try again.');
      }
    } catch (e) {
      print('Error fetching report: $e');
      _showErrorOverlay('Error loading report: $e');
    }
  }

  void _showErrorOverlay(String message) {
    _errorOverlay?.remove();
    _errorOverlay = OverlayEntry(
      builder: (context) => Positioned(
        right: 16,
        bottom: 16,
        child: FadeOut(
          duration: const Duration(seconds: 3),
          animate: true,
          child: Material(
            color: Colors.red.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_errorOverlay!);
    Future.delayed(const Duration(seconds: 3), () {
      _errorOverlay?.remove();
      _errorOverlay = null;
    });
  }

  void _showReportModal(
      BuildContext context, Map<String, dynamic> data, String reportId) async {
    String? selectedPlumberUid = data['assignedPlumber'] as String?;
    List<Map<String, dynamic>> plumbers = await _fetchPlumbers();

    void _assignPlumber() async {
      if (selectedPlumberUid == null) {
        _showErrorOverlay('Please select a plumber first.');
        return;
      }
      try {
        final docRef =
            FirebaseFirestore.instance.collection('reports').doc(reportId);
        final doc = await docRef.get();
        if (!doc.exists) {
          throw Exception('Report document does not exist');
        }
        await docRef.update({
          'assignedPlumber': selectedPlumberUid,
          'status': 'Monitoring' // Update status to Monitoring
        });
        _showErrorOverlay(
            'Plumber assigned successfully.'); // Reuse error overlay for success
        Navigator.of(context).pop();
      } catch (e) {
        print('Error assigning plumber: $e');
        _showErrorOverlay('Failed to assign plumber: $e');
      }

      
    }

    

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF4A2C6F),
                          backgroundImage: data['avatarUrl'] != null &&
                                  data['avatarUrl'] is String
                              ? NetworkImage(data['avatarUrl'])
                              : null,
                          child: data['avatarUrl'] == null ||
                                  data['avatarUrl'] is! String
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 28)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['fullName'] ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['contactNumber'] ?? 'No contact',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(data['createdAt']),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (data['image'] != null &&
                        data['image'] is String &&
                        data['image'].isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(data['image']),
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.center,
                            height: 180,
                            color: Colors.grey[100],
                            child: const Text('Unable to load image'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      data['issueDescription'] ?? 'No issue description',
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    Chip(
                      label: Text(
                        data['status'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor:
                          _getStatusColor(data['status'] ?? 'Unknown')
                              .withOpacity(0.2),
                    ),
                    if (data['assignedPlumber'] != null)
                      const SizedBox(height: 12),
                    if (data['assignedPlumber'] != null)
                      Text(
                        plumbers.firstWhere(
                            (p) => p['uid'] == data['assignedPlumber'],
                            orElse: () => {'fullName': 'Unknown'})['fullName'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF4A2C6F),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Assign Plumber',
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF4A2C6F)),
                        ),
                      ),
                      value: selectedPlumberUid,
                      dropdownColor: Colors.white,
                      items: plumbers.isNotEmpty
                          ? plumbers.map((plumber) {
                              return DropdownMenuItem<String>(
                                value: plumber['uid'],
                                child: Text(
                                  plumber['fullName'],
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              );
                            }).toList()
                          : [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('No plumbers available',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            ],
                      onChanged: plumbers.isNotEmpty
                          ? (value) {
                              setState(() {
                                selectedPlumberUid = value;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _assignPlumber,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A2C6F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          data['assignedPlumber'] != null
                              ? 'Re-assign Plumber'
                              : 'Assign Plumber for Monitoring',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Monitoring':
        return const Color(0xFF2F8E2F);
      case 'Unfixed':
        return const Color(0xFFD94B3B);
      case 'Fixed':
        return const Color(0xC18B00);
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMMMMd().add_jm().format(timestamp.toDate());
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Monitor',
      selectedRoute: '/monitor',
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          color: const Color(0xFFF5F5F5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('reports').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('StreamBuilder error: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'No reports available',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final markers = snapshot.data!.docs
                    .map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final location = data['location'];
                      if (location == null || location is! GeoPoint)
                        return null;

                      return Marker(
                        point: LatLng(location.latitude, location.longitude),
                        width: 140,
                        height: 70,
                        child: GestureDetector(
                          onTap: () => _fetchAndShowReportModal(doc.id),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data['fullName'] ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4A2C6F),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Icon(
                                Icons.location_pin,
                                color: Color(0xFF4A2C6F),
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .whereType<Marker>()
                    .toList();

                return FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(13.1486, 123.7156),
                    initialZoom: 12,
                    interactionOptions: InteractionOptions(
                        flags: InteractiveFlag.all &
                            ~InteractiveFlag.doubleTapZoom),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
