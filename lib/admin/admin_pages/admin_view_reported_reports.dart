// lib/admin/admin_pages/admin_view_reported_reports.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../components/admin_layout.dart';

class ViewReportedReportsPage extends StatefulWidget {
  const ViewReportedReportsPage({super.key});

  @override
  State<ViewReportedReportsPage> createState() =>
      _ViewReportedReportsPageState();
}

class _ViewReportedReportsPageState extends State<ViewReportedReportsPage> {
  int _currentPage = 0;
  final int _pageSize = 10;
  String? _selectedPlumberId;
  List<Map<String, dynamic>> _plumbers = [];
  DocumentSnapshot? _lastDocument;
  int _totalPages = 1;
  bool _isLoading = false;

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
      Query query = FirebaseFirestore.instance.collection('reported_reports');
      if (_selectedPlumberId != null) {
        query = query.where('plumberId', isEqualTo: _selectedPlumberId);
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

  Stream<QuerySnapshot> _getReportedReportsStream() {
    Query query = FirebaseFirestore.instance
        .collection('reported_reports')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_selectedPlumberId != null) {
      query = query.where('plumberId', isEqualTo: _selectedPlumberId);
    }

    if (_currentPage > 0 && _lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    return query.snapshots();
  }

  Future<void> _deleteReportedReport(
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
          'Are you sure you want to delete this reported report? This action cannot be undone.',
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
            .collection('reported_reports')
            .doc(reportId)
            .delete();

        // Log the action
        await FirebaseFirestore.instance.collection('logs').add({
          'action': 'Deleted Reported Report',
          'userId': 'admin',
          'details': 'Deleted reported report #$reportId',
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

  void _showReportDetails(Map<String, dynamic> reportData) {
    final report = reportData['reportData'] as Map<String, dynamic>;
    final plumberName = reportData['plumberName'] ?? 'Unknown Plumber';
    final reason = reportData['reason'] ?? 'No reason provided';
    final createdAt = reportData['createdAt'] is Timestamp
        ? (reportData['createdAt'] as Timestamp).toDate()
        : null;
    final formattedDate = createdAt != null
        ? DateFormat.yMMMd().add_jm().format(createdAt)
        : 'Unknown';

    final fullName = report['fullName']?.toString() ?? '';
    final issueDescription = report['issueDescription']?.toString() ?? '';
    final placeName = report['placeName']?.toString() ?? '';
    final reportDate = report['createdAt'] is Timestamp
        ? (report['createdAt'] as Timestamp).toDate()
        : null;
    final reportFormattedDate = reportDate != null
        ? DateFormat.yMMMd().add_jm().format(reportDate)
        : 'Unknown';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
                      'Reported Report Details',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.black54, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plumber who reported
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.report_problem,
                              color: Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reported by Plumber',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plumberName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Reason for reporting
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.description,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reason for Reporting',
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
                              reason,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Original report details
                      Text(
                        'Original Report Details',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reported by: $fullName',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Date: $reportFormattedDate',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Location: $placeName',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Issue: $issueDescription',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (report['additionalLocationInfo'] != null)
                              const SizedBox(height: 8),
                            if (report['additionalLocationInfo'] != null)
                              Text(
                                'Additional Info: ${report['additionalLocationInfo']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE3F2FD), width: 1),
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

  @override
  void initState() {
    super.initState();
    _fetchPlumbers();
    _fetchTotalPages();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Reported Reports',
      selectedRoute: '/reported_reports',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter by plumber dropdown
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
                    value: _selectedPlumberId,
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
                              _selectedPlumberId = value;
                              _currentPage = 0;
                              _lastDocument = null;
                              _fetchTotalPages();
                            });
                          },
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getReportedReportsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('StreamBuilder error: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error loading reported reports: ${snapshot.error}',
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
                            'No reported reports found.',
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
                                final plumberName =
                                    data['plumberName'] ?? 'Unknown Plumber';
                                final reason =
                                    data['reason'] ?? 'No reason provided';
                                final createdAt = data['createdAt']?.toDate();
                                final formattedDate = createdAt != null
                                    ? DateFormat.yMMMd().format(createdAt)
                                    : 'Unknown date';

                                final originalReport =
                                    data['reportData'] as Map<String, dynamic>;
                                final originalIssue =
                                    originalReport['issueDescription'] ??
                                        'No description';
                                final originalName =
                                    originalReport['fullName'] ?? 'Unknown';

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
                                                    const Icon(
                                                      Icons.report_problem,
                                                      size: 14,
                                                      color: Colors.red,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Reported by: $plumberName',
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
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Original Report: $originalIssue',
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
                                                  'Reason: $reason',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                                Text(
                                                  '$formattedDate • Original by: $originalName',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              IconButton(
                                                onPressed: () =>
                                                    _showReportDetails(data),
                                                icon: const Icon(
                                                  Icons.visibility,
                                                  color: Color(0xFF4FC3F7),
                                                ),
                                                tooltip: 'View Details',
                                              ),
                                              const SizedBox(height: 4),
                                              IconButton(
                                                onPressed: () =>
                                                    _deleteReportedReport(
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
