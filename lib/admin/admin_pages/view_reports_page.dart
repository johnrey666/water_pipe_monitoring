// ignore_for_file: unused_import, unused_field

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
import 'admin_view_illegal_tapping_reports.dart'; // NEW: Import illegal tapping reports page
import 'package:firebase_auth/firebase_auth.dart';

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
  final Map<String, List<DocumentSnapshot?>> _lastDocuments = {
    'All': [null],
    'Monitoring': [null],
    'Unfixed Reports': [null],
    'Fixed': [null],
  };
  final Map<String, int> _totalPages = {
    'All': 1,
    'Monitoring': 1,
    'Unfixed Reports': 1,
    'Fixed': 1,
  };
  bool _isLoading = false;
  bool _showIllegalTappingModal = false;
  List<DocumentSnapshot> _allReports = [];
  bool _isInitialLoad = true;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Monitoring':
        return const Color(0xFF2F8E2F);
      case 'Unfixed Reports':
        return const Color(0xFFD94B3B);
      case 'Fixed':
        return const Color(0xFFC18B00);
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

  Future<void> _fetchAllReports() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      // Filter reports client-side
      _allReports = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Show reports where isIllegalTapping is not true (either false or doesn't exist)
        final isIllegal = data['isIllegalTapping'] ?? false;
        return !isIllegal; // Only show non-illegal tapping reports
      }).toList();

      // Update total pages for each status
      _updateTotalPages();
    } catch (e) {
      print('Error fetching reports: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  void _updateTotalPages() {
    // Filter reports by selected status
    List<DocumentSnapshot> filteredReports = _allReports.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'Unfixed Reports';

      if (_selectedStatus != 'All') {
        return status == _selectedStatus;
      }
      return true;
    }).toList();

    // Filter by plumber if selected
    if (_selectedPlumberUid != null) {
      filteredReports = filteredReports.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final assignedPlumber = data['assignedPlumber'] ?? '';
        return assignedPlumber == _selectedPlumberUid;
      }).toList();
    }

    // Calculate total pages
    final totalDocs = filteredReports.length;
    setState(() {
      _totalPages[_selectedStatus] = (totalDocs / _pageSize).ceil();
      if (_totalPages[_selectedStatus]! < 1) {
        _totalPages[_selectedStatus] = 1;
      }

      // Reset last documents
      _lastDocuments[_selectedStatus] = List.generate(
        _totalPages[_selectedStatus]!,
        (index) => null,
      );
    });
  }

  List<DocumentSnapshot> _getPaginatedReports() {
    if (_allReports.isEmpty) return [];

    // Filter reports by selected status
    List<DocumentSnapshot> filteredReports = _allReports.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'Unfixed Reports';

      if (_selectedStatus != 'All') {
        return status == _selectedStatus;
      }
      return true;
    }).toList();

    // Filter by plumber if selected
    if (_selectedPlumberUid != null) {
      filteredReports = filteredReports.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final assignedPlumber = data['assignedPlumber'] ?? '';
        return assignedPlumber == _selectedPlumberUid;
      }).toList();
    }

    // Apply pagination
    final startIndex = _currentPage * _pageSize;
    final endIndex = startIndex + _pageSize;

    if (startIndex >= filteredReports.length) {
      return [];
    }

    return filteredReports.sublist(
      startIndex,
      endIndex > filteredReports.length ? filteredReports.length : endIndex,
    );
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
                _updateTotalPages();
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

  // NEW: Show illegal tapping report modal
  void _showIllegalTappingReportModal() {
    setState(() {
      _showIllegalTappingModal = true;
    });
  }

  // NEW: Close illegal tapping report modal
  void _closeIllegalTappingModal() {
    setState(() {
      _showIllegalTappingModal = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchPlumbers();
    _fetchAllReports();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AdminLayout(
          title: 'View Reports',
          selectedRoute: '/reports',
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
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
                        ],
                      ),
                    ),
                    // Action buttons
                    Row(
                      children: [
                        // View Illegal Tapping Reports Button - NEW
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ViewIllegalTappingReportsPage(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.warning,
                            size: 18,
                          ),
                          label: Text(
                            'View Illegal Tapping Reports',
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
                        const SizedBox(width: 12),
                        // View Plumber Reports Button
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
                            backgroundColor: Colors.orange,
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
                        const SizedBox(width: 12),
                        // Report Illegal Tapping Button
                        ElevatedButton.icon(
                          onPressed: _showIllegalTappingReportModal,
                          icon: const Icon(
                            Icons.add_circle_outline,
                            size: 18,
                          ),
                          label: Text(
                            'Report Illegal Tapping',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4FC3F7),
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
                              _updateTotalPages();
                            });
                          },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isInitialLoad
                      ? const Center(child: CircularProgressIndicator())
                      : _buildReportsList(),
                ),
              ],
            ),
          ),
        ),
        if (_showIllegalTappingModal)
          IllegalTappingReportModal(
            onClose: _closeIllegalTappingModal,
          ),
      ],
    );
  }

  Widget _buildReportsList() {
    final reports = _getPaginatedReports();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reports.isEmpty) {
      return Center(
        child: Text(
          _selectedStatus == 'All'
              ? 'No regular reports found.'
              : 'No $_selectedStatus reports found.',
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final data = report.data() as Map<String, dynamic>;
              final fullName = data['fullName'] ?? 'Unknown';
              final issueDescription =
                  data['issueDescription'] ?? 'No description';
              final createdAt = data['createdAt']?.toDate();
              final status = data['status'] ?? 'Unfixed Reports';
              final formattedDate = createdAt != null
                  ? DateFormat.yMMMd().format(createdAt)
                  : 'Unknown date';
              final hasEvidence = data['hasEvidence'] ?? false;
              final images = data['images'] != null
                  ? List<String>.from(data['images'])
                  : <String>[];
              final hasAssessment = data['assessment'] != null;
              final hasFixImages = data['beforeFixImages'] != null ||
                  data['afterFixImages'] != null;
              final isFixed = status == 'Fixed';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
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
                            color: _getStatusColor(status),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: _getStatusColor(status),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            fullName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade800,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (hasEvidence)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  left: 4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.photo_camera,
                                                    size: 10,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '${images.length}',
                                                    style: const TextStyle(
                                                      fontSize: 8,
                                                      color: Colors.white,
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
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '$status • $formattedDate',
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
                          // Button(s) section
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // View Assessment/Fix button (only for reports with assessment or fix images)
                              if ((hasAssessment || hasFixImages || isFixed) &&
                                  data['assignedPlumber'] != null)
                                SizedBox(
                                  width: 60,
                                  height: 36,
                                  child: TextButton(
                                    onPressed: () {
                                      _showAssessmentDetails(context, report);
                                    },
                                    child: Text(
                                      isFixed ? 'View Fix' : 'View Assessment',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: isFixed
                                            ? Colors.green
                                            : const Color(0xFF4FC3F7),
                                        fontWeight: FontWeight.w600,
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
                                        builder: (context) => MonitorPage(
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
  }
}

// NEW: Illegal Tapping Report Modal Widget
class IllegalTappingReportModal extends StatefulWidget {
  final VoidCallback onClose;

  const IllegalTappingReportModal({super.key, required this.onClose});

  @override
  State<IllegalTappingReportModal> createState() =>
      _IllegalTappingReportModalState();
}

class _IllegalTappingReportModalState extends State<IllegalTappingReportModal> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _locationNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _evidenceNotesController = TextEditingController();

  String _type = 'Unauthorized Connection';
  LatLng? _selectedLocation;
  final List<html.File> _imageFiles = [];
  final List<String> _selectedPlumbers =
      []; // MULTIPLE plumbers can be selected
  List<Map<String, dynamic>> _allPlumbers = [];
  bool _isUploading = false;
  String? _errorMessage;
  bool _isLoadingPlumbers = true;

  // FIXED: Use CartoDB tile provider which is more reliable and follows usage policies
  final String _mapTileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  final List<String> _tileSubdomains = ['a', 'b', 'c'];

  @override
  void initState() {
    super.initState();
    _fetchPlumbers();
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _descriptionController.dispose();
    _evidenceNotesController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlumbers() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Plumber')
          .orderBy('fullName')
          .get();
      setState(() {
        _allPlumbers = querySnapshot.docs
            .map((doc) => {
                  'uid': doc.id,
                  'fullName': doc.data()['fullName'] ?? 'Unknown Plumber',
                  'email': doc.data()['email'] ?? '',
                })
            .toList();
        _isLoadingPlumbers = false;
      });
    } catch (e) {
      print('Error fetching plumbers: $e');
      setState(() {
        _isLoadingPlumbers = false;
        _errorMessage = 'Failed to load plumbers: $e';
      });
    }
  }

  // Web-specific file picker
  Future<void> _pickImages() async {
    try {
      final input = html.FileUploadInputElement();
      input
        ..multiple = true
        ..accept = 'image/*'
        ..click();

      await input.onChange.first;

      if (input.files != null && input.files!.isNotEmpty) {
        final newImages = input.files!.take(10 - _imageFiles.length).toList();
        setState(() {
          _imageFiles.addAll(newImages);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking images: $e';
      });
    }
  }

  // Convert images to base64
  Future<List<String>> _convertImagesToBase64() async {
    final List<String> base64Images = [];

    for (final imageFile in _imageFiles) {
      try {
        final reader = html.FileReader();
        final completer = Completer<void>();
        reader.onLoad.listen((event) {
          completer.complete();
        });

        reader.readAsDataUrl(imageFile);
        await completer.future;

        final dataUrl = reader.result as String;
        final commaIndex = dataUrl.indexOf(',');
        final base64Data = dataUrl.substring(commaIndex + 1);
        base64Images.add(base64Data);
      } catch (e) {
        print('Error encoding image: $e');
      }
    }

    return base64Images;
  }

  // Image preview widget
  Widget _buildImagePreview(html.File imageFile, int index) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 100,
        maxHeight: 100,
        minWidth: 100,
        minHeight: 100,
      ),
      child: Container(
        margin: EdgeInsets.only(
          right: index < 9 ? 8 : 0,
        ),
        child: Stack(
          children: [
            FutureBuilder<String?>(
              future: () async {
                try {
                  return html.Url.createObjectUrlFromBlob(imageFile);
                } catch (e) {
                  return null;
                }
              }(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      snapshot.data!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 30,
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
              },
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _imageFiles.removeAt(index);
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
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
                  child: const Icon(Icons.close, size: 12, color: Colors.red),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_imageFiles.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 30,
                  ),
                  child: TextButton.icon(
                    onPressed: _clearAllImages,
                    icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                    label: Text(
                      'Clear All',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 100,
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageFiles.length,
              itemBuilder: (context, index) {
                return _buildImagePreview(_imageFiles[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Map location picker dialog
  Future<LatLng?> _showMapLocationPicker() async {
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
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
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
                          Expanded(
                            child: Text(
                              '📍 Select Tap Location',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                            color: Colors.grey.shade600,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
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
                                urlTemplate: _mapTileUrl,
                                subdomains: _tileSubdomains,
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
                                        size: 40,
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
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(12),
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
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Tap anywhere on the map to select location',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
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
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Location Selected',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                              Text(
                                                'Lat: ${selectedLocation.latitude.toStringAsFixed(6)}\nLng: ${selectedLocation.longitude.toStringAsFixed(6)}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade700,
                                                ),
                                                maxLines: 2,
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
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Row(
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 40,
                                    ),
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        mapController.move(
                                          const LatLng(13.294678436001885,
                                              123.75569591912894),
                                          16,
                                        );
                                      },
                                      icon: Icon(Icons.my_location,
                                          color: Colors.blue.shade700,
                                          size: 16),
                                      label: Text(
                                        'Center Map',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        side: BorderSide(
                                            color: Colors.blue.shade300),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 40,
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(
                                            context, selectedLocation);
                                      },
                                      icon: const Icon(Icons.check, size: 16),
                                      label: Text(
                                        'Confirm',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
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
                          ),
                          // Zoom Controls
                          Positioned(
                            right: 8,
                            bottom: 60,
                            child: Column(
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  child: FloatingActionButton.small(
                                    heroTag: 'zoom_in',
                                    onPressed: () {
                                      mapController.move(
                                        mapController.camera.center,
                                        mapController.camera.zoom + 1,
                                      );
                                    },
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.blue.shade700,
                                    child: const Icon(Icons.add, size: 18),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  child: FloatingActionButton.small(
                                    heroTag: 'zoom_out',
                                    onPressed: () {
                                      mapController.move(
                                        mapController.camera.center,
                                        mapController.camera.zoom - 1,
                                      );
                                    },
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.blue.shade700,
                                    child: const Icon(Icons.remove, size: 18),
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
            );
          },
        );
      },
    );
  }

  // Multi-select plumber widget
  Widget _buildPlumberMultiSelect() {
    if (_isLoadingPlumbers) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_allPlumbers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('No plumbers available'),
        ),
      );
    }

    return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Selected plumbers chips
            if (_selectedPlumbers.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedPlumbers.map((plumberUid) {
                    final plumber = _allPlumbers.firstWhere(
                        (p) => p['uid'] == plumberUid,
                        orElse: () => {});
                    final plumberName = plumber['fullName'] ?? 'Unknown';

                    return Chip(
                      label: Text(plumberName),
                      onDeleted: () {
                        setState(() {
                          _selectedPlumbers.remove(plumberUid);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),

            // Plumber list with checkboxes
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 200,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allPlumbers.length,
                itemBuilder: (context, index) {
                  final plumber = _allPlumbers[index];
                  final isSelected = _selectedPlumbers.contains(plumber['uid']);

                  return CheckboxListTile(
                    title: Text(
                      plumber['fullName'],
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    subtitle: Text(
                      plumber['email'],
                      style:
                          GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedPlumbers.add(plumber['uid']);
                        } else {
                          _selectedPlumbers.remove(plumber['uid']);
                        }
                      });
                    },
                    secondary: const Icon(Icons.plumbing, color: Colors.blue),
                  );
                },
              ),
            ),
          ],
        ));
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate() && _selectedLocation != null) {
      _formKey.currentState!.save();
      setState(() => _isUploading = true);

      try {
        // Get admin info
        final currentUser = FirebaseAuth.instance.currentUser;
        String reportedByName = 'Admin';
        String reportedByEmail = currentUser?.email ?? 'admin@email.com';

        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          final userData = userDoc.data();
          reportedByName = userData?['fullName'] ?? 'Admin';
        }

        // Convert images to base64
        final base64Images = await _convertImagesToBase64();

        final reportData = {
          'fullName': reportedByName,
          'issueDescription': 'ILLEGAL TAPPING: ${_descriptionController.text}',
          'placeName': _locationNameController.text,
          'location': GeoPoint(
            _selectedLocation!.latitude,
            _selectedLocation!.longitude,
          ),
          'status': 'Illegal Tapping',
          'isIllegalTapping': true,
          'illegalTappingType': _type,
          'evidenceNotes': _evidenceNotesController.text,
          'evidenceImages': base64Images,
          'priority': 'high',
          'requiresInvestigation': true,
          'createdAt': FieldValue.serverTimestamp(),
          'reportedByMeterReader': false,
          'reportedBy': reportedByEmail,
          'reportedByName': reportedByName,
          'assignedPlumbers': _selectedPlumbers, // Store multiple plumbers
          'hasEvidence': base64Images.isNotEmpty,
          'imageCount': base64Images.length,
        };

        final docRef = await FirebaseFirestore.instance
            .collection('reports')
            .add(reportData);
        final reportId = docRef.id;

        // Send notifications to ALL selected plumbers
        for (final plumberUid in _selectedPlumbers) {
          final plumber = _allPlumbers.firstWhere((p) => p['uid'] == plumberUid,
              orElse: () => {});
          final plumberName = plumber['fullName'] ?? 'Unknown Plumber';

          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': plumberUid,
            'reportId': reportId,
            'type': 'illegal_tapping_assignment',
            'title': '🚨 ILLEGAL TAPPING ASSIGNMENT',
            'message':
                'You have been assigned to investigate an illegal tapping report at ${_locationNameController.text}. This is HIGH PRIORITY - please investigate immediately.',
            'timestamp': Timestamp.now(),
            'read': false,
            'isHighPriority': true,
            'assignedByName': reportedByName,
          });

          print('Notification sent to plumber: $plumberName ($plumberUid)');
        }

        // Show success message and close modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Illegal tapping report submitted successfully! ${_selectedPlumbers.length} plumber${_selectedPlumbers.length == 1 ? '' : 's'} assigned.',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Close the modal
        widget.onClose();
      } catch (e) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        setState(() => _isUploading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select a location and fill all required fields'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          width: 800,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border.all(color: Colors.red.shade200),
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
                          'Report Illegal Water Tapping',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 24),
                        onPressed: widget.onClose,
                        color: Colors.grey.shade600,
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
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // Location Field
                        Text(
                          'Location *',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Location Selection
                        if (_selectedLocation == null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 48,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final location =
                                      await _showMapLocationPicker();
                                  if (location != null) {
                                    setState(() {
                                      _selectedLocation = location;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50,
                                  foregroundColor: Colors.blue.shade800,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Select Location on Map'),
                              ),
                            ),
                          ),

                        if (_selectedLocation != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green.shade600, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Location Selected',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                      Text(
                                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () async {
                                    final location =
                                        await _showMapLocationPicker();
                                    if (location != null) {
                                      setState(() {
                                        _selectedLocation = location;
                                      });
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Location Name
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 70,
                          ),
                          child: TextFormField(
                            controller: _locationNameController,
                            decoration: InputDecoration(
                              labelText: 'Location Name / Address *',
                              hintText: 'Enter exact address or landmark',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              isDense: true,
                            ),
                            style: GoogleFonts.poppins(fontSize: 14),
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
                          'Type of Illegal Activity *',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 60,
                          ),
                          child: DropdownButtonFormField(
                            value: _type,
                            items: const [
                              DropdownMenuItem(
                                value: 'Unauthorized Connection',
                                child: Text('Unauthorized Connection',
                                    style: TextStyle(color: Colors.black)),
                              ),
                              DropdownMenuItem(
                                value: 'Meter Tampering/Bypass',
                                child: Text('Meter Tampering/Bypass',
                                    style: TextStyle(color: Colors.black)),
                              ),
                              DropdownMenuItem(
                                value: 'Pipe Diversion',
                                child: Text('Pipe Diversion',
                                    style: TextStyle(color: Colors.black)),
                              ),
                              DropdownMenuItem(
                                value: 'Other Illegal Activity',
                                child: Text('Other Illegal Activity',
                                    style: TextStyle(color: Colors.black)),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _type = value!);
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              isDense: true,
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Description
                        Text(
                          'Description *',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 120,
                          ),
                          child: TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Detailed description',
                              hintText: 'Describe what you observed...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              isDense: true,
                            ),
                            style: GoogleFonts.poppins(fontSize: 14),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter description';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Assign Plumbers Section
                        Text(
                          'Assign Investigators',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select one or more plumbers to investigate this report:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPlumberMultiSelect(),

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

                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _imageFiles.length < 10 ? _pickImages : null,
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Select from Gallery'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Display selected images
                        _selectedImagesPreview(),

                        const SizedBox(height: 20),

                        // Additional Notes (Optional)
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 100,
                          ),
                          child: TextFormField(
                            controller: _evidenceNotesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Additional Notes (Optional)',
                              hintText: 'Witness info, time, etc.',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              isDense: true,
                            ),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isUploading ? null : _submitReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isUploading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Submit Illegal Tapping Report',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Required fields note
                        Center(
                          child: Text(
                            '* Required fields',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
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
