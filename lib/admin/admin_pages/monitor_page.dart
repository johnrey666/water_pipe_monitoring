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
          .where('role', isEqualTo: 'Plumber')
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
    DateTime? selectedDate = data['monitoringDate'] is Timestamp
        ? (data['monitoringDate'] as Timestamp).toDate()
        : null;
    bool isButtonDisabled = data['assignedPlumber'] != null;
    List<Map<String, dynamic>> plumbers = await _fetchPlumbers();

    void _assignPlumber() async {
      if (selectedPlumberUid == null) {
        _showErrorOverlay('Please select a plumber first.');
        return;
      }
      if (selectedDate == null) {
        _showErrorOverlay('Please select a monitoring date.');
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
          'monitoringDate': Timestamp.fromDate(selectedDate!),
          'status': 'Monitoring',
        });
        _showErrorOverlay('Plumber assigned successfully.');
        setState(() {
          isButtonDisabled = true;
        });
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
            constraints: BoxConstraints(
              maxWidth: 450,
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Report Details',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.grey, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF4A2C6F),
                          backgroundImage: data['avatarUrl'] != null &&
                                  data['avatarUrl'] is String
                              ? NetworkImage(data['avatarUrl'])
                              : null,
                          child: data['avatarUrl'] == null ||
                                  data['avatarUrl'] is! String
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['fullName'] ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                data['contactNumber'] ?? 'No contact',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatTimestamp(data['createdAt']),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (data['image'] != null &&
                        data['image'] is String &&
                        data['image'].isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(data['image']),
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            padding: const EdgeInsets.all(10),
                            alignment: Alignment.center,
                            height: 140,
                            color: Colors.grey[100],
                            child: Text(
                              'Unable to load image',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      data['issueDescription'] ?? 'No issue description',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Chip(
                      label: Text(
                        data['status'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor:
                          _getStatusColor(data['status'] ?? 'Unknown')
                              .withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    if (data['assignedPlumber'] != null)
                      const SizedBox(height: 8),
                    if (data['assignedPlumber'] != null)
                      Text(
                        'Assigned: ${plumbers.firstWhere(
                          (p) => p['uid'] == data['assignedPlumber'],
                          orElse: () => {'fullName': 'Unknown'},
                        )['fullName']}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF4A2C6F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Colors.grey),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Assign Plumber',
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey[300]!, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFF5E35B1), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey[300]!, width: 1),
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
                                        style:
                                            GoogleFonts.poppins(fontSize: 12),
                                      ),
                                    );
                                  }).toList()
                                : [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'No plumbers available',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                            onChanged: plumbers.isNotEmpty
                                ? (value) {
                                    setState(() {
                                      selectedPlumberUid = value;
                                      isButtonDisabled = false;
                                    });
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Monitoring Date',
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey[300]!, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFF5E35B1), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey[300]!, width: 1),
                              ),
                              suffixIcon: const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF5E35B1),
                                size: 18,
                              ),
                            ),
                            controller: TextEditingController(
                              text: selectedDate != null
                                  ? DateFormat.yMMMd().format(selectedDate!)
                                  : '',
                            ),
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF5E35B1),
                                        onPrimary: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Color(0xFF5E35B1),
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  selectedDate = pickedDate;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isButtonDisabled ? null : _assignPlumber,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isButtonDisabled
                              ? Colors.grey[400]
                              : const Color(0xFF5E35B1),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: isButtonDisabled ? 0 : 2,
                          shadowColor: isButtonDisabled ? null : Colors.black12,
                        ),
                        child: Text(
                          isButtonDisabled
                              ? 'Plumber Assigned!'
                              : (data['assignedPlumber'] != null
                                  ? 'Re-assign Plumber'
                                  : 'Assign Plumber for Monitoring'),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reports')
                      .snapshots(),
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
                            point:
                                LatLng(location.latitude, location.longitude),
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

                    // Add San Jose label (no icon)
                    markers.add(
                      Marker(
                        point: const LatLng(
                            13.3467, 123.7222), // San Jose, Malilipot, Albay
                        width: 140,
                        height: 40,
                        child: Text(
                          'San Jose',
                          style: GoogleFonts.poppins(
                            fontSize: 18, // Enlarged font size
                            fontWeight: FontWeight.w700,
                            color: Colors.red[900],
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );

                    return FlutterMap(
                      options: MapOptions(
                        initialCenter: const LatLng(
                            13.3467, 123.7222), // San Jose, Malilipot, Albay
                        initialZoom: 16, // Tighter zoom for San Jose focus
                        minZoom: 15, // Prevent zooming out too far
                        maxZoom: 17, // Allow slight zoom-in for detail
                        initialCameraFit: CameraFit.bounds(
                          bounds: LatLngBounds(
                            const LatLng(13.3447, 123.7202), // Southwest
                            const LatLng(13.3487, 123.7242), // Northeast
                          ),
                          padding:
                              const EdgeInsets.all(50), // Margin around bounds
                        ),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all &
                              ~InteractiveFlag.doubleTapZoom &
                              ~InteractiveFlag.flingAnimation,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.example.app',
                          errorTileCallback: (tile, error, stackTrace) {
                            print('Tile loading error: $error');
                            _showErrorOverlay(
                                'Failed to load map tiles. Check your internet connection.');
                          },
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    );
                  },
                ),
                // Manual scale indicator
                Positioned(
                  top: 8,
                  left: 8,
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
                      'Approx. 100m', // Adjusted for zoom 16
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                // Attribution text
                Positioned(
                  bottom: 8,
                  right: 8,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
