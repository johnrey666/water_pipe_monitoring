import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewReportsPage extends StatefulWidget {
  final String? initialReportId;

  const ViewReportsPage({super.key, this.initialReportId});

  @override
  State<ViewReportsPage> createState() => _ViewReportsPageState();
}

class _ViewReportsPageState extends State<ViewReportsPage> {
  @override
  void initState() {
    super.initState();
    if (widget.initialReportId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showReportModal(widget.initialReportId!);
      });
    }
  }

  void _showReportModal(String reportId) async {
    final doc = await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .get();
    if (doc.exists) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white, // Modal bg white
          child: ReportDetailsModal(report: doc),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Page bg white
      appBar: AppBar(
        backgroundColor: Colors.white, // AppBar bg white
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "View Reports",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .where('assignedPlumber',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    "Error loading reports",
                    style: TextStyle(fontSize: 16, color: Colors.redAccent),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reports = snapshot.data!.docs;

              if (reports.isEmpty) {
                return const Center(
                  child: Text(
                    'No reports submitted yet.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final fullName = report['fullName'] ?? '';
                  final issueDescription = report['issueDescription'] ?? '';
                  final createdAt = report['createdAt']?.toDate();
                  final formattedDate = createdAt != null
                      ? DateFormat.yMMMd().format(createdAt)
                      : 'Unknown date';

                  return FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      color: Colors.white, // Card bg white
                      shadowColor: Colors.black12,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        title: Text(
                          fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              issueDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF87CEEB), // View btn bg
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: const Size(80, 36),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.white,
                                child: ReportDetailsModal(report: report),
                              ),
                            );
                          },
                          child: const Text(
                            "View",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class ReportDetailsModal extends StatefulWidget {
  final DocumentSnapshot report;

  const ReportDetailsModal({super.key, required this.report});

  @override
  State<ReportDetailsModal> createState() => _ReportDetailsModalState();
}

class _ReportDetailsModalState extends State<ReportDetailsModal> {
  bool _showLocation = false;
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.report['fullName'] ?? '';
    final contactNumber = widget.report['contactNumber'] ?? '';
    final issueDescription = widget.report['issueDescription'] ?? '';
    final placeName = widget.report['placeName'] ?? '';
    final dateTime = widget.report['dateTime']?.toDate();
    final location = widget.report['location'];
    final imageBase64 = widget.report['image'];
    final currentStatus = widget.report['status'] ?? 'Unfixed Reports';

    final formattedDate = dateTime != null
        ? DateFormat.yMMMd().add_jm().format(dateTime)
        : 'Unknown';

    Uint8List? imageBytes;
    try {
      imageBytes = base64Decode(imageBase64);
    } catch (_) {}

    latlong.LatLng? mapLocation;
    if (location != null) {
      mapLocation = latlong.LatLng(location.latitude, location.longitude);
    }

    return FadeIn(
      duration: const Duration(milliseconds: 300),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 500,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // Modal bg white
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey, // Profile icon bg gray
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contactNumber,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 24, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    imageBytes,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                issueDescription,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showLocation = !_showLocation;
                  });
                },
                child: Text(
                  _showLocation ? "Hide Location" : "View Location",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800], // Text color
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey[800]?.withOpacity(0.3),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_showLocation && mapLocation != null)
                FadeIn(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: mapLocation,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: ['a', 'b', 'c'],
                            userAgentPackageName:
                                'com.example.water_pipe_monitoring',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: mapLocation,
                                width: 32,
                                height: 32,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_showLocation && mapLocation == null)
                const Text(
                  "No location data available",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              const SizedBox(height: 8),
              Text(
                placeName,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            const SizedBox(height: 16),
Column(
  children: [
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : () => _updateStatus('Monitored'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2F8E2F),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: _isUpdating
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentStatus == 'Monitored')
                    const Icon(Icons.check_circle, size: 18, color: Colors.white),
                  if (currentStatus == 'Monitored') const SizedBox(width: 6),
                  const Text(
                    "Monitoring",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    ),
    const SizedBox(height: 10),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : () => _updateStatus('Fixed'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF87CEEB), // Updated fixed btn bg
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: _isUpdating
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentStatus == 'Fixed')
                    const Icon(Icons.check_circle, size: 18, color: Colors.white),
                  if (currentStatus == 'Fixed') const SizedBox(width: 6),
                  const Text(
                    "Fixed",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    ),
  ],
),

            ],
          ),
        ),
      ),
    );
  }
}
