// lib/admin/admin_pages/admin_view_illegal_tapping_reports.dart
// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../components/admin_layout.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:html' as html;

class ViewIllegalTappingReportsPage extends StatefulWidget {
  const ViewIllegalTappingReportsPage({super.key});

  @override
  State<ViewIllegalTappingReportsPage> createState() =>
      _ViewIllegalTappingReportsPageState();
}

class _ViewIllegalTappingReportsPageState
    extends State<ViewIllegalTappingReportsPage> {
  int _currentPage = 0;
  final int _pageSize = 10;
  String _selectedStatus = 'All';
  String? _selectedPlumberUid;
  List<Map<String, dynamic>> _plumbers = [];
  DocumentSnapshot? _lastDocument;
  int _totalPages = 1;
  bool _isLoading = false;
  
  // NEW: Pending illegal tapping reports count
  int _pendingIllegalReportsCount = 0;
  StreamSubscription? _illegalReportsSubscription;
  List<DocumentSnapshot> _allIllegalReports = [];

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

  Future<void> _fetchTotalPages() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('reports')
          .where('isIllegalTapping', isEqualTo: true);

      if (_selectedStatus != 'All') {
        query = query.where('status', isEqualTo: _selectedStatus);
      }
      if (_selectedPlumberUid != null) {
        query = query.where('assignedPlumbers', arrayContains: _selectedPlumberUid);
      }
      
      final snapshot = await query.get();
      setState(() {
        _totalPages = (snapshot.docs.length / _pageSize).ceil();
      });
    } catch (e) {
      print('Error fetching total pages: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // NEW: Function to count pending illegal tapping reports (Illegal Tapping + Monitoring)
  void _updatePendingIllegalReportsCount() {
    int count = 0;
    for (final report in _allIllegalReports) {
      final data = report.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'Illegal Tapping';
      
      // Count reports with status "Illegal Tapping" or "Monitoring"
      if (status == 'Illegal Tapping' || status == 'Monitoring') {
        count++;
      }
    }
    
    setState(() {
      _pendingIllegalReportsCount = count;
    });
  }

  // NEW: Fetch all illegal tapping reports
  Future<void> _fetchAllIllegalReports() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('reports')
          .where('isIllegalTapping', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      
      setState(() {
        _allIllegalReports = snapshot.docs;
        _updatePendingIllegalReportsCount();
      });
      
      // Set up real-time listener for illegal tapping reports updates
      _setupIllegalReportsListener();
    } catch (e) {
      print('Error fetching illegal reports: $e');
    }
  }

  // NEW: Set up real-time listener for illegal tapping reports
  void _setupIllegalReportsListener() {
    // Cancel existing subscription if any
    _illegalReportsSubscription?.cancel();
    
    _illegalReportsSubscription = FirebaseFirestore.instance
        .collection('reports')
        .where('isIllegalTapping', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      // Update illegal reports list
      setState(() {
        _allIllegalReports = snapshot.docs;
        _updatePendingIllegalReportsCount();
      });
      
      // Update total pages
      _fetchTotalPages();
    }, onError: (error) {
      print('Error listening to illegal reports: $error');
    });
  }

  Stream<QuerySnapshot> _getIllegalTappingReportsStream() {
    Query query = FirebaseFirestore.instance
        .collection('reports')
        .where('isIllegalTapping', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_selectedStatus != 'All') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    if (_selectedPlumberUid != null) {
      query = query.where('assignedPlumbers', arrayContains: _selectedPlumberUid);
    }

    if (_currentPage > 0 && _lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    return query.snapshots();
  }

  Future<void> _deleteIllegalTappingReport(
      String reportId, BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Delete',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this illegal tapping report? This action cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .delete();

        // Log the action
        await FirebaseFirestore.instance.collection('logs').add({
          'action': 'Deleted Illegal Tapping Report',
          'userId': 'admin',
          'details': 'Deleted illegal tapping report #$reportId',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting report: $e')),
          );
        }
      }
    }
  }

  // NEW: Build notification badge for pending illegal tapping reports
  Widget _buildPendingIllegalNotificationBadge() {
    if (_pendingIllegalReportsCount <= 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _pendingIllegalReportsCount > 99 ? '99+' : _pendingIllegalReportsCount.toString(),
          style: GoogleFonts.poppins(
            fontSize: _pendingIllegalReportsCount > 99 ? 8 : 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> reportData, String reportId) {
    final fullName = reportData['fullName'] ?? 'Unknown';
    final issueDescription = reportData['issueDescription'] ?? 'No description';
    final placeName = reportData['placeName'] ?? 'Unknown location';
    final createdAt = reportData['createdAt']?.toDate();
    final formattedDate = createdAt != null
        ? DateFormat.yMMMd().add_jm().format(createdAt)
        : 'Unknown';
    final status = reportData['status'] ?? 'Illegal Tapping';
    final illegalTappingType = reportData['illegalTappingType'] ?? 'Unknown Type';
    final evidenceNotes = reportData['evidenceNotes'] ?? '';
    final evidenceImages = reportData['evidenceImages'] != null
        ? List<String>.from(reportData['evidenceImages'])
        : <String>[];
    final assignedPlumbers = reportData['assignedPlumbers'] != null
        ? List<String>.from(reportData['assignedPlumbers'])
        : <String>[];
    final reportedByName = reportData['reportedByName'] ?? 'Unknown';
    final reportedBy = reportData['reportedBy'] ?? 'Unknown';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Illegal Tapping Report',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.grey, size: 24),
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
                      // Priority Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.priority_high,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '🚨 HIGH PRIORITY: ILLEGAL TAPPING',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: status == 'Fixed'
                              ? Colors.green.shade100
                              : status == 'Monitoring'
                                  ? Colors.orange.shade100
                                  : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: status == 'Fixed'
                                ? Colors.green.shade300
                                : status == 'Monitoring'
                                    ? Colors.orange.shade300
                                    : Colors.red.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status == 'Fixed'
                                  ? Icons.check_circle
                                  : status == 'Monitoring'
                                      ? Icons.track_changes
                                      : Icons.warning,
                              size: 18,
                              color: status == 'Fixed'
                                  ? Colors.green.shade800
                                  : status == 'Monitoring'
                                      ? Colors.orange.shade800
                                      : Colors.red.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: $status',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: status == 'Fixed'
                                    ? Colors.green.shade800
                                    : status == 'Monitoring'
                                        ? Colors.orange.shade800
                                        : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Report Information
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reported by',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.blue.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        reportedByName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                      Text(
                                        reportedBy,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.blue.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reported: $formattedDate',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  color: Colors.blue.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Type: $illegalTappingType',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Location Information
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Location',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              placeName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Description',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              issueDescription,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Evidence Notes
                      if (evidenceNotes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.note,
                                    color: Colors.purple.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Evidence Notes',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                evidenceNotes,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Assigned Plumbers
                      if (assignedPlumbers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    color: Colors.teal.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Assigned Investigators',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _getPlumberDetails(assignedPlumbers),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  }
                                  if (snapshot.hasError || !snapshot.hasData) {
                                    return Text(
                                      'Error loading plumber details',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    );
                                  }
                                  final plumbers = snapshot.data!;
                                  return Column(
                                    children: plumbers.map((plumber) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• ${plumber['fullName']}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.teal.shade900,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Evidence Images
                      if (evidenceImages.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blueGrey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    color: Colors.blueGrey.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Evidence Images (${evidenceImages.length})',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildEvidenceImagesCarousel(evidenceImages),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
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
  }

  // Build evidence images carousel
  Widget _buildEvidenceImagesCarousel(List<String> base64Images) {
    if (base64Images.isEmpty) {
      return const SizedBox.shrink();
    }

    if (base64Images.length == 1) {
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, base64Images[0], 0, base64Images),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(base64Images[0]),
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: base64Images.length,
          options: CarouselOptions(
            height: 200,
            aspectRatio: 16 / 9,
            viewportFraction: 0.8,
            initialPage: 0,
            enableInfiniteScroll: base64Images.length > 1,
            reverse: false,
            autoPlay: false,
            enlargeCenterPage: true,
            enlargeFactor: 0.3,
            scrollDirection: Axis.horizontal,
            onPageChanged: (index, reason) {
              // Optional: track current image
            },
          ),
          itemBuilder: (context, index, realIndex) {
            return GestureDetector(
              onTap: () => _showFullScreenImage(context, base64Images[index], index, base64Images),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(base64Images[index]),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                'Image ${index + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (base64Images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 16, color: Colors.blueGrey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Tap to view full screen • ${base64Images.length} images',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Show full screen image viewer with save button
  void _showFullScreenImage(BuildContext context, String base64Image, int initialIndex, List<String> allImages) {
    int currentIndex = initialIndex;
    final PageController pageController = PageController(initialPage: initialIndex);
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Image viewer with swipe support
              PageView.builder(
                controller: pageController,
                itemCount: allImages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.memory(
                        base64Decode(allImages[index]),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image, size: 60, color: Colors.white),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load image',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              // Top controls
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                      onPressed: () {
                        pageController.dispose();
                        Navigator.pop(context);
                      },
                    ),
                    // Save image button (like Facebook)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download, color: Colors.white, size: 24),
                      ),
                      onPressed: () async {
                        await _saveImage(allImages[currentIndex]);
                      },
                    ),
                  ],
                ),
              ),
              // Bottom controls - Image counter
              if (allImages.length > 1)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${currentIndex + 1} / ${allImages.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              // Navigation arrows for multiple images
              if (allImages.length > 1) ...[
                // Previous arrow
                if (currentIndex > 0)
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                        ),
                        onPressed: () {
                          pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                // Next arrow
                if (currentIndex < allImages.length - 1)
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right, color: Colors.white, size: 30),
                        ),
                        onPressed: () {
                          pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Save image function - works on all platforms
  Future<void> _saveImage(String base64Image) async {
    try {
      // Decode base64 image
      final bytes = base64Decode(base64Image);
      
      // Check if we're on web
      bool isWeb = false;
      try {
        // Check if we're on web by trying to access html.window
        // ignore: unnecessary_null_comparison
        if (html.window != null) {
          isWeb = true;
        }
      } catch (e) {
        isWeb = false;
      }
      
      if (isWeb) {
        // Web download approach
        final blob = html.Blob([bytes], 'image/jpeg');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..download = 'illegal_tapping_${DateTime.now().millisecondsSinceEpoch}.jpg'
          ..style.display = 'none';
        
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove(); // Fixed: use remove() instead of removeChild()
        html.Url.revokeObjectUrl(url);
        
        _showSnackBar('Image downloaded successfully!', isError: false);
      } else {
        // Mobile/desktop approach using share_plus
        // Create a temporary file
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'illegal_tapping_$timestamp.jpg';
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        
        // Share the file - user can choose to save it
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Illegal Tapping Evidence',
          text: 'Illegal tapping evidence image - saved on ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
        );
        
        _showSnackBar('Image shared - you can save it from the share dialog!', isError: false);
        
        // Clean up after a delay
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            print('Error cleaning up temp file: $e');
          }
        });
      }
    } catch (e) {
      print('Error saving image: $e');
      _showSnackBar('Error saving image: ${e.toString().split('\n').first}', isError: true);
    }
  }

  // Helper function to show snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red : Colors.green,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getPlumberDetails(List<String> plumberIds) async {
    final plumbers = <Map<String, dynamic>>[];
    for (final id in plumberIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        if (doc.exists) {
          plumbers.add({
            'uid': id,
            'fullName': doc.data()?['fullName'] ?? 'Unknown Plumber',
          });
        }
      } catch (e) {
        print('Error fetching plumber $id: $e');
      }
    }
    return plumbers;
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
                _lastDocument = null;
                _fetchTotalPages();
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

  @override
  void initState() {
    super.initState();
    _fetchPlumbers();
    _fetchTotalPages();
    _fetchAllIllegalReports(); // NEW: Fetch illegal reports on init
  }

  @override
  void dispose() {
    // Cancel the subscription when the widget is disposed
    _illegalReportsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Illegal Tapping Reports',
      selectedRoute: '/illegal_tapping_reports',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter buttons with notification
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // NEW: Add notification badge to Illegal Tapping button
                          Stack(
                            children: [
                              _buildFilterButton('Illegal Tapping'),
                              // Show badge only on Illegal Tapping button when selected
                              if (_selectedStatus == 'Illegal Tapping' && _pendingIllegalReportsCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: const Color(0xFF4FC3F7), width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _pendingIllegalReportsCount > 99 ? '99+' : _pendingIllegalReportsCount.toString(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          _buildFilterButton('All'),
                          _buildFilterButton('Monitoring'),
                          _buildFilterButton('Fixed'),
                          
                          // NEW: Pending illegal reports indicator (separate badge)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 16,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Pending:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Show notification badge with count
                                _buildPendingIllegalNotificationBadge(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                  _lastDocument = null;
                                  _fetchTotalPages();
                                });
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getIllegalTappingReportsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('StreamBuilder error: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error loading illegal tapping reports: ${snapshot.error}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {
                                  _currentPage = 0;
                                  _lastDocument = null;
                                  _fetchTotalPages();
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
                            'No illegal tapping reports found.',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }

                      if (reports.isNotEmpty) {
                        _lastDocument = reports.last;
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
                                final formattedDate = createdAt != null
                                    ? DateFormat.yMMMd().format(createdAt)
                                    : 'Unknown date';
                                final status = data['status'] ?? 'Illegal Tapping';
                                final illegalTappingType =
                                    data['illegalTappingType'] ?? 'Unknown Type';
                                final assignedPlumbers =
                                    data['assignedPlumbers'] != null
                                        ? List<String>.from(
                                            data['assignedPlumbers'])
                                        : <String>[];
                                final hasEvidence = data['hasEvidence'] ?? false;
                                final evidenceCount = data['imageCount'] ?? 0;

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
                                            height: 80,
                                            color: Colors.red,
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
                                                      Icons.warning,
                                                      size: 14,
                                                      color: Colors.red,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        '$illegalTappingType',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors
                                                              .red.shade800,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (hasEvidence)
                                                      Container(
                                                        margin:
                                                            const EdgeInsets
                                                                    .only(
                                                                left: 4),
                                                        padding:
                                                            const EdgeInsets
                                                                    .symmetric(
                                                                horizontal: 4,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.green,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .photo_camera,
                                                              size: 10,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            const SizedBox(
                                                                width: 2),
                                                            Text(
                                                              '$evidenceCount',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 8,
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
                                                const SizedBox(height: 4),
                                                Text(
                                                  issueDescription,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Reported by: $fullName',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '$status • $formattedDate',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey.shade600,
                                                      ),
                                                    ),
                                                    if (assignedPlumbers
                                                        .isNotEmpty)
                                                      Container(
                                                        margin:
                                                            const EdgeInsets
                                                                    .only(
                                                                left: 8),
                                                        padding:
                                                            const EdgeInsets
                                                                    .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .teal.shade100,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          border: Border.all(
                                                            color: Colors
                                                                .teal.shade300,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          '${assignedPlumbers.length} investigator${assignedPlumbers.length == 1 ? '' : 's'}',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .teal.shade800,
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
                                          Column(
                                            children: [
                                              IconButton(
                                                onPressed: () =>
                                                    _showReportDetails(
                                                        data, report.id),
                                                icon: const Icon(
                                                  Icons.visibility,
                                                  color: Color(0xFF4FC3F7),
                                                ),
                                                tooltip: 'View Details',
                                              ),
                                              const SizedBox(height: 4),
                                              IconButton(
                                                onPressed: () =>
                                                    _deleteIllegalTappingReport(
                                                        report.id, context),
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                tooltip: 'Delete Report',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Pagination
                          Row(
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
                                    color: _currentPage > 0
                                        ? const Color(0xFF4FC3F7)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_totalPages, (i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () =>
                                              setState(() => _currentPage = i),
                                      style: TextButton.styleFrom(
                                        backgroundColor: _currentPage == i
                                            ? const Color(0xFF4FC3F7)
                                            : Colors.grey.shade200,
                                        foregroundColor: _currentPage == i
                                            ? Colors.white
                                            : Colors.grey.shade800,
                                        minimumSize: const Size(32, 32),
                                        padding: const EdgeInsets.all(0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
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
                                onPressed: _currentPage < _totalPages - 1 &&
                                        !_isLoading
                                    ? () {
                                        setState(() {
                                          _currentPage++;
                                        });
                                      }
                                    : null,
                                child: Text(
                                  'Next',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _currentPage < _totalPages - 1
                                        ? const Color(0xFF4FC3F7)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
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