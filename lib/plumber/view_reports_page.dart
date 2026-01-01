// plumber view reports.dart (updated)
import 'dart:convert';
// ignore: unused_import
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ViewReportsPage extends StatefulWidget {
  final String? initialReportId;

  const ViewReportsPage({super.key, this.initialReportId});

  @override
  State<ViewReportsPage> createState() => _ViewReportsPageState();
}

class _ViewReportsPageState extends State<ViewReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _publicPage = 1;
  int _monitoringPage = 1;
  int _fixedPage = 1;
  final int _pageSize = 10;

  // For reporting public reports
  final TextEditingController _reportReasonController = TextEditingController();
  // ignore: unused_field
  String? _reportingReportId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialReportId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showReportModal(widget.initialReportId!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportReasonController.dispose();
    super.dispose();
  }

  void _showReportModal(String reportId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .get();
      if (doc.exists && mounted) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.white,
            child: ReportDetailsModal(
              report: doc,
              onReportPressed: () => _showReportReasonDialog(reportId),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report not found.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    }
  }

  void _showReportReasonDialog(String reportId) {
    setState(() {
      _reportingReportId = reportId;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Report this Public Report',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Please provide a reason for reporting this public report:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reportReasonController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Report is inaccurate, already fixed, duplicate, etc.',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF87CEEB)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _reportReasonController.clear();
                  Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final reason = _reportReasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please provide a reason')),
                    );
                    return;
                  }

                  await _submitReport(reportId, reason);
                  _reportReasonController.clear();
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text(
                  'Submit Report',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitReport(String reportId, String reason) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get plumber info
      final plumberDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final plumberName = plumberDoc.data()?['fullName'] ?? 'Unknown Plumber';

      // Get report data
      final reportDoc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .get();
      final reportData = reportDoc.data() as Map<String, dynamic>;

      // Create reported report document
      await FirebaseFirestore.instance.collection('reported_reports').add({
        'reportId': reportId,
        'plumberId': user.uid,
        'plumberName': plumberName,
        'reason': reason,
        'reportData': reportData,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed, dismissed
      });

      // Log the action
      await FirebaseFirestore.instance.collection('logs').add({
        'action': 'Reported Public Report',
        'userId': user.uid,
        'details':
            'Plumber $plumberName reported public report #$reportId. Reason: ${reason.length > 50 ? reason.substring(0, 50) + '...' : reason}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: SafeArea(
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            flexibleSpace: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF87CEEB),
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: const Color(0xFF87CEEB),
              indicatorWeight: 3,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              labelStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Public Reports'),
                Tab(text: 'Monitoring'),
                Tab(text: 'Fixed'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildReportList(
                user.uid,
                null, // No status filter for public reports
                _publicPage,
                (page) => setState(() => _publicPage = page),
                isPublic: true,
              ),
              _buildReportList(
                user.uid,
                ['Unfixed Reports', 'Monitoring'],
                _monitoringPage,
                (page) => setState(() => _monitoringPage = page),
              ),
              _buildReportList(
                user.uid,
                ['Fixed'],
                _fixedPage,
                (page) => setState(() => _fixedPage = page),
                includePublicFixed: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportList(String userId, List<String>? statuses,
      int currentPage, Function(int) onPageChange,
      {bool isPublic = false, bool includePublicFixed = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: isPublic
          ? FirebaseFirestore.instance
              .collection('reports')
              .where('isPublic', isEqualTo: true)
              .where('status', isNotEqualTo: 'Fixed')
              .orderBy('createdAt', descending: true)
              .snapshots()
          : includePublicFixed
              ? FirebaseFirestore.instance
                  .collection('reports')
                  .where('status', isEqualTo: 'Fixed')
                  .orderBy('createdAt', descending: true)
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('reports')
                  .where('assignedPlumber', isEqualTo: userId)
                  .where('status', whereIn: statuses ?? [])
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading reports: ${snapshot.error}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF87CEEB),
            ),
          );
        }

        List<QueryDocumentSnapshot> reports = snapshot.data!.docs;
        if (includePublicFixed) {
          reports = reports.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['assignedPlumber'] == userId ||
                data['isPublic'] == true;
          }).toList();
        }

        if (reports.isEmpty) {
          return Center(
            child: Text(
              'No reports available.',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        final totalPages = (reports.length / _pageSize).ceil();
        final startIndex = (currentPage - 1) * _pageSize;
        final endIndex = (startIndex + _pageSize).clamp(0, reports.length);
        final paginatedReports = reports.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: paginatedReports.length,
                itemBuilder: (context, index) {
                  final report = paginatedReports[index];
                  final fullName = report['fullName']?.toString() ?? '';
                  final issueDescription =
                      report['issueDescription']?.toString() ?? '';
                  final createdAt = report['createdAt'] is Timestamp
                      ? (report['createdAt'] as Timestamp).toDate()
                      : null;
                  final formattedDate = createdAt != null
                      ? DateFormat.yMMMd().format(createdAt)
                      : 'Unknown date';

                  return FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                      color: Colors.white,
                      shadowColor: Colors.black.withOpacity(0.05),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        title: Text(
                          fullName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              issueDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        trailing: isPublic
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Report button for public reports
                                  IconButton(
                                    onPressed: () =>
                                        _showReportReasonDialog(report.id),
                                    icon: const Icon(
                                      Icons.report_problem,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                    tooltip: 'Report this public report',
                                  ),
                                  const SizedBox(width: 8),
                                  // View button
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE3F2FD),
                                      foregroundColor: const Color(0xFF87CEEB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: const BorderSide(
                                            color: Color(0xFFBBDEFB)),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      minimumSize: const Size(90, 40),
                                      elevation: 0,
                                    ),
                                    onPressed: () =>
                                        _showReportModal(report.id),
                                    child: Text(
                                      'View',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF87CEEB),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE3F2FD),
                                  foregroundColor: const Color(0xFF87CEEB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                        color: Color(0xFFBBDEFB)),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  minimumSize: const Size(90, 40),
                                  elevation: 0,
                                ),
                                onPressed: () => _showReportModal(report.id),
                                child: Text(
                                  'View',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF87CEEB),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageButton(
                      label: 'Previous',
                      onPressed: currentPage > 1
                          ? () => onPageChange(currentPage - 1)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$currentPage / $totalPages',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildPageButton(
                      label: 'Next',
                      onPressed: currentPage < totalPages
                          ? () => onPageChange(currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPageButton(
      {required String label, required VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF87CEEB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color:
                onPressed != null ? const Color(0xFFBBDEFB) : Colors.grey[300]!,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onPressed != null ? const Color(0xFF87CEEB) : Colors.grey[500],
        ),
      ),
    );
  }
}

class ReportDetailsModal extends StatefulWidget {
  final DocumentSnapshot report;
  final VoidCallback? onReportPressed;

  const ReportDetailsModal({
    super.key,
    required this.report,
    this.onReportPressed,
  });

  @override
  State<ReportDetailsModal> createState() => _ReportDetailsModalState();
}

class _ReportDetailsModalState extends State<ReportDetailsModal> {
  bool _showLocation = false;
  bool _isUpdating = false;
  final TextEditingController _assessmentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<XFile> _beforeFixImages = [];
  List<XFile> _afterFixImages = [];

  @override
  void dispose() {
    _assessmentController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      // Convert images to base64
      List<String> beforeFixBase64 = [];
      List<String> afterFixBase64 = [];

      for (var image in _beforeFixImages) {
        final bytes = await image.readAsBytes();
        beforeFixBase64.add(base64Encode(bytes));
      }

      for (var image in _afterFixImages) {
        final bytes = await image.readAsBytes();
        afterFixBase64.add(base64Encode(bytes));
      }

      // Get plumber info
      final plumber = FirebaseAuth.instance.currentUser;
      String plumberName = 'Unknown Plumber';
      if (plumber != null) {
        final plumberDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(plumber.uid)
            .get();
        if (plumberDoc.exists && plumberDoc.data()?['fullName'] != null) {
          plumberName = plumberDoc.data()!['fullName'];
        }
      }

      final updateData = {
        'status': newStatus,
        'fixedAt': FieldValue.serverTimestamp(),
        'fixedBy': plumber?.uid,
        'fixedByName': plumberName,
      };

      // Add assessment if exists
      final assessment = _assessmentController.text.trim();
      if (assessment.isNotEmpty) {
        updateData['assessment'] = assessment;
      }

      // Add before fix images if any
      if (beforeFixBase64.isNotEmpty) {
        updateData['beforeFixImages'] = beforeFixBase64;
        updateData['beforeFixImageCount'] = beforeFixBase64.length;
      }

      // Add after fix images if any
      if (afterFixBase64.isNotEmpty) {
        updateData['afterFixImages'] = afterFixBase64;
        updateData['afterFixImageCount'] = afterFixBase64.length;
      }

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .update(updateData);

      if (newStatus == 'Fixed') {
        final reportData = widget.report.data() as Map<String, dynamic>;
        final residentId = reportData['userId']?.toString();
        final issueDescription =
            reportData['issueDescription']?.toString() ?? 'Water issue';

        // Send notification to resident
        if (residentId != null) {
          final notificationData = {
            'userId': residentId,
            'type': 'report_fixed',
            'title': 'Report Fixed',
            'message':
                'Your reported issue: "$issueDescription" has been marked as Fixed by $plumberName.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'reportId': widget.report.id,
          };

          // Add assessment to notification if exists
          if (assessment.isNotEmpty) {
            notificationData['assessment'] = assessment;
          }

          await FirebaseFirestore.instance
              .collection('notifications')
              .add(notificationData);
        }

        // Log the action
        await FirebaseFirestore.instance.collection('logs').add({
          'action': 'Report Fixed',
          'userId': plumber?.uid,
          'details':
              'Report "${issueDescription.length > 30 ? issueDescription.substring(0, 30) + '...' : issueDescription}" marked as Fixed by $plumberName.',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report marked as $newStatus')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  // Show assessment dialog
  void _showAssessmentInputDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Add Assessment',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Provide assessment details (estimated time to fix, required materials, etc.)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _assessmentController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Estimated time: 2 hours\nRequired: Pipe fittings, sealant',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF87CEEB)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assessment saved')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF87CEEB),
                ),
                child: Text(
                  'Save Assessment',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show mark as fixed dialog with image upload options
  void _showMarkFixedDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Mark as Fixed',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload images before and after fixing the issue:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Before fix images
                  _buildImageUploadSection(
                    'Before Fix Images',
                    _beforeFixImages,
                    () async {
                      final images = await _picker.pickMultiImage();
                      setDialogState(() {
                        _beforeFixImages.addAll(images);
                      });
                    },
                    (index) {
                      setDialogState(() {
                        _beforeFixImages.removeAt(index);
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // After fix images
                  _buildImageUploadSection(
                    'After Fix Images',
                    _afterFixImages,
                    () async {
                      final images = await _picker.pickMultiImage();
                      setDialogState(() {
                        _afterFixImages.addAll(images);
                      });
                    },
                    (index) {
                      setDialogState(() {
                        _afterFixImages.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateStatus('Fixed');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF87CEEB),
                ),
                child: Text(
                  'Mark as Fixed',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageUploadSection(
    String title,
    List<XFile> images,
    VoidCallback onPickImages,
    void Function(int) onRemoveImage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${images.length})',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onPickImages,
          icon: const Icon(Icons.photo_library, size: 20),
          label: Text(
            'Add Images',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[100],
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
        ),
        if (images.isNotEmpty) const SizedBox(height: 12),
        if (images.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(images[index].path),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemoveImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
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
    );
  }

  // Widget to display images in a carousel
  Widget _buildImageCarousel(
      List<String> base64Images, String issueDescription) {
    if (base64Images.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 40, color: Colors.grey.shade500),
              const SizedBox(height: 8),
              Text(
                'No images attached',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: base64Images.length,
          options: CarouselOptions(
            height: 180,
            aspectRatio: 16 / 9,
            viewportFraction: 0.8,
            initialPage: 0,
            enableInfiniteScroll: base64Images.length > 1,
            reverse: false,
            autoPlay: base64Images.length > 1,
            autoPlayInterval: const Duration(seconds: 3),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            enlargeFactor: 0.3,
            scrollDirection: Axis.horizontal,
          ),
          itemBuilder: (context, index, realIndex) {
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(base64Images[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image,
                                size: 40, color: Colors.grey),
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
            );
          },
        ),
        if (base64Images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Swipe to view ${base64Images.length} images',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Widget for single image display
  Widget _buildSingleImage(String base64Image, String issueDescription) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(base64Image),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image,
                        size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Image not available',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportData = widget.report.data() as Map<String, dynamic>;
    final fullName = reportData['fullName']?.toString() ?? '';
    final contactNumber = reportData['contactNumber']?.toString() ?? '';
    final issueDescription = reportData['issueDescription']?.toString() ?? '';
    final placeName = reportData['placeName']?.toString() ?? '';
    final additionalLocationInfo =
        reportData['additionalLocationInfo']?.toString();
    final dateTime = reportData['createdAt'] is Timestamp
        ? (reportData['createdAt'] as Timestamp).toDate()
        : null;
    final location = reportData['location'] as GeoPoint?;
    final currentStatus = reportData['status']?.toString() ?? 'Unfixed Reports';
    final assessment = reportData['assessment']?.toString();
    final isPublic = reportData['isPublic'] == true;

    // Get images data
    final imageCount = reportData['imageCount'] ?? 0;
    final images =
        (reportData['images'] as List<dynamic>?)?.cast<String>() ?? [];
    final hasImages = images.isNotEmpty;

    final formattedDate = dateTime != null
        ? DateFormat.yMMMd().add_jm().format(dateTime)
        : 'Unknown';

    latlong.LatLng? mapLocation;
    if (location != null) {
      mapLocation = latlong.LatLng(location.latitude, location.longitude);
    }

    return FadeIn(
      duration: const Duration(milliseconds: 300),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE3F2FD), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report Details',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      // Report button for public reports
                      if (isPublic && currentStatus != 'Fixed')
                        IconButton(
                          onPressed: widget.onReportPressed,
                          icon: const Icon(
                            Icons.report_problem,
                            color: Colors.red,
                            size: 24,
                          ),
                          tooltip: 'Report this public report',
                        ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.black54, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFE3F2FD),
                          child: reportData['avatarUrl'] != null &&
                                  reportData['avatarUrl'] is String
                              ? CachedNetworkImage(
                                  imageUrl: reportData['avatarUrl'],
                                  placeholder: (context, url) => const Icon(
                                    Icons.person,
                                    color: Color(0xFF87CEEB),
                                    size: 24,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                    Icons.person,
                                    color: Color(0xFF87CEEB),
                                    size: 24,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Color(0xFF87CEEB),
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contactNumber,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              if (isPublic) const SizedBox(height: 4),
                              if (isPublic)
                                Text(
                                  'Public Report',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Location information
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBDEFB)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  placeName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.blue.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Images section
                    if (hasImages)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Attached Images ($imageCount)',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          images.length == 1
                              ? _buildSingleImage(images[0], issueDescription)
                              : _buildImageCarousel(images, issueDescription),
                          const SizedBox(height: 16),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Issue description
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.report_problem_outlined,
                                size: 16,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Issue Description',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            issueDescription,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isPublic &&
                        additionalLocationInfo != null &&
                        additionalLocationInfo.isNotEmpty)
                      const SizedBox(height: 12),
                    if (isPublic &&
                        additionalLocationInfo != null &&
                        additionalLocationInfo.isNotEmpty)
                      Text(
                        'Additional Location Info: $additionalLocationInfo',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),

                    // Assessment section
                    if (assessment != null && assessment.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.assessment_outlined,
                                      size: 18,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Plumber Assessment',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  assessment,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Map location toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showLocation = !_showLocation;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _showLocation
                                      ? Icons.location_on
                                      : Icons.location_off,
                                  size: 18,
                                  color: const Color(0xFF87CEEB),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _showLocation ? 'Hide Map' : 'Show Map',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: const Color(0xFF87CEEB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              _showLocation
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: const Color(0xFF87CEEB),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Map display
                    if (_showLocation && mapLocation != null)
                      FadeIn(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE3F2FD)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: mapLocation,
                                initialZoom: 14,
                                minZoom: 13,
                                maxZoom: 16,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                  userAgentPackageName:
                                      'WaterPipeMonitoring/1.0',
                                  tileProvider: CachedTileProvider(),
                                  errorTileCallback: (tile, error, stackTrace) {
                                    if (error.toString().contains('403')) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Access blocked by OpenStreetMap. Please contact support or check your internet.'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: mapLocation,
                                      width: 32,
                                      height: 32,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Color(0xFF87CEEB),
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                                const Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Text(
                                    '© OpenStreetMap contributors',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (_showLocation && mapLocation == null)
                      Text(
                        'No location data available',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Status section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentStatus == 'Fixed'
                                  ? Colors.green.shade600
                                  : (currentStatus == 'Monitoring'
                                      ? Colors.orange.shade600
                                      : Colors.red.shade600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Status',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentStatus,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: currentStatus == 'Fixed'
                                        ? Colors.green.shade800
                                        : (currentStatus == 'Monitoring'
                                            ? Colors.orange.shade800
                                            : Colors.red.shade800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action buttons for non-fixed reports (only for assigned plumber or monitoring)
                    if (currentStatus != 'Fixed' && !isPublic)
                      Column(
                        children: [
                          // Add Assessment button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showAssessmentInputDialog,
                              icon: const Icon(Icons.assessment_outlined,
                                  size: 20),
                              label: Text(
                                assessment != null && assessment.isNotEmpty
                                    ? 'Edit Assessment'
                                    : 'Add Assessment',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                elevation: 2,
                                shadowColor: Colors.black.withOpacity(0.1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Mark as Fixed button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isUpdating ? null : _showMarkFixedDialog,
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 20),
                              label: Text(
                                'Mark as Fixed',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF87CEEB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                elevation: 2,
                                shadowColor: Colors.black.withOpacity(0.1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheKey: '${coordinates.x}_${coordinates.y}_${coordinates.z}',
    );
  }
}
