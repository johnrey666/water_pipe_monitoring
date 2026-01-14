// ignore_for_file: unused_field, unused_local_variable

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../components/admin_layout.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  int _currentPage = 0;
  final int _pageSize = 10;
  List<DocumentSnapshot?> _lastDocuments = [null];
  int _totalPages = 1;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Stream<QuerySnapshot> _getResidentsStream() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Resident');
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('fullName', isGreaterThanOrEqualTo: _searchQuery)
          .where('fullName', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
          .orderBy('fullName')
          .limit(_pageSize);
    } else {
      query = query.orderBy('fullName').limit(_pageSize);
    }
    if (_currentPage > 0 && _lastDocuments[_currentPage - 1] != null) {
      query = query.startAfterDocument(_lastDocuments[_currentPage - 1]!);
    }
    return query.snapshots();
  }

  Future<void> _fetchTotalPages() async {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Resident');
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('fullName', isGreaterThanOrEqualTo: _searchQuery)
          .where('fullName', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }
    try {
      final snapshot = await query.get();
      final totalDocs = snapshot.docs.length;
      setState(() {
        _totalPages = (totalDocs / _pageSize).ceil();
        if (_totalPages == 0) _totalPages = 1;
        _lastDocuments = List.generate(_totalPages, (index) => null);
      });
    } catch (e) {
      print('Error fetching total pages: $e');
    }
  }

  Widget _buildPaginationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _currentPage > 0
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
              : null,
          child: Text(
            'Previous',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _currentPage > 0 ? const Color(0xFF1E88E5) : Colors.grey,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalPages, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _currentPage = i;
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: _currentPage == i
                      ? const Color(0xFF1E88E5)
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
        TextButton(
          onPressed: _currentPage < _totalPages - 1
              ? () {
                  setState(() {
                    _currentPage++;
                    if (_currentPage >= _lastDocuments.length) {
                      _lastDocuments.add(null);
                    }
                  });
                }
              : null,
          child: Text(
            'Next',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _currentPage < _totalPages - 1
                  ? const Color(0xFF1E88E5)
                  : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchTotalPages();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
        _currentPage = 0;
        _lastDocuments = [null];
        _fetchTotalPages();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Bills Management',
      selectedRoute: '/bills',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar and Reported Bills Button in one row
            Row(
              children: [
                // Search Bar - takes most of the space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, right: 8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search residents by name...',
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF718096)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFEDF2F7), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E88E5), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFEDF2F7), width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF718096),
                        ),
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                ),
                // Reported Bills Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showReportedBillsModal(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.report_problem, size: 18),
                    label: Text(
                      'Reported Bills',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getResidentsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading residents: ${snapshot.error}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                      ),
                    );
                  }
                  final residents = snapshot.data?.docs ?? [];
                  if (residents.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No residents found.'
                            : 'No residents found for "$_searchQuery".',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xFF2D3748),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  if (residents.isNotEmpty) {
                    if (_currentPage >= _lastDocuments.length) {
                      _lastDocuments.add(residents.last);
                    } else {
                      _lastDocuments[_currentPage] = residents.last;
                    }
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: residents.length,
                          itemBuilder: (context, index) {
                            final resident = residents[index];
                            final data =
                                resident.data() as Map<String, dynamic>? ?? {};
                            final fullName =
                                data['fullName'] ?? 'Unknown Resident';
                            final address = data['address'] ?? 'No address';
                            final contactNumber =
                                data['contactNumber'] ?? 'No contact';
                            return _ResidentCard(
                              residentId: resident.id,
                              fullName: fullName,
                              address: address,
                              contactNumber: contactNumber,
                            );
                          },
                        ),
                      ),
                      if (_totalPages > 1) _buildPaginationButtons(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show Reported Bills Modal
  void _showReportedBillsModal(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final sideLength =
        (min(screenSize.width, screenSize.height) * 0.85).clamp(400.0, 800.0);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: screenSize.height * 0.05),
        child: SizedBox(
          width: sideLength,
          height: sideLength,
          child: ReportedBillsModal(),
        ),
      ),
    );
  }
}

class ReportedBillsModal extends StatefulWidget {
  @override
  State<ReportedBillsModal> createState() => _ReportedBillsModalState();
}

class _ReportedBillsModalState extends State<ReportedBillsModal> {
  List<Map<String, dynamic>> _reportedBills = [];
  bool _loading = true;
  String? _error;
  Map<String, Map<String, dynamic>> _residentDetails = {};
  Map<String, Map<String, dynamic>> _billDetails = {};
  Map<String, bool> _expandedReports = {};
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  bool _hasMoreReports = true;
  DocumentSnapshot? _lastReportDoc;

  @override
  void initState() {
    super.initState();
    _loadReportedBills();
  }

  Future<void> _loadReportedBills({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        setState(() {
          _loading = true;
          _error = null;
          _currentPage = 0;
          _lastReportDoc = null;
          _reportedBills.clear();
          _residentDetails.clear();
          _billDetails.clear();
        });
      }
      // Load reported bills with status 'pending' with pagination
      Query query = FirebaseFirestore.instance
          .collection('bill_reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .limit(_itemsPerPage);
      if (_lastReportDoc != null) {
        query = query.startAfterDocument(_lastReportDoc!);
      }
      final reportsSnapshot = await query.get();
      if (reportsSnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreReports = false;
          _loading = false;
        });
        return;
      }
      // Update last document for pagination
      _lastReportDoc = reportsSnapshot.docs.last;
      final newReports = reportsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['reportId'] = doc.id;
        return data;
      }).toList();
      // Load resident details and bill details for each new report
      for (var report in newReports) {
        final residentId = report['residentId'] as String?;
        final billId = report['billId'] as String?;
        if (residentId != null && !_residentDetails.containsKey(residentId)) {
          final residentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(residentId)
              .get();
          if (residentDoc.exists) {
            _residentDetails[residentId] =
                residentDoc.data() as Map<String, dynamic>;
          }
        }
        if (billId != null &&
            residentId != null &&
            !_billDetails.containsKey(billId)) {
          final billDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(residentId)
              .collection('bills')
              .doc(billId)
              .get();
          if (billDoc.exists) {
            _billDetails[billId] = billDoc.data() as Map<String, dynamic>;
          }
        }
      }
      setState(() {
        if (loadMore) {
          _reportedBills.addAll(newReports);
        } else {
          _reportedBills = newReports;
        }
        _loading = false;
        _hasMoreReports = newReports.length == _itemsPerPage;
      });
    } catch (e) {
      print('Error loading reported bills: $e');
      setState(() {
        _error = 'Error loading reported bills: $e';
        _loading = false;
      });
    }
  }

  Future<void> _updateBillAndResolveReport(String reportId,
      Map<String, dynamic> report, double newReading, String notes) async {
    try {
      final billId = report['billId'] as String?;
      final residentId = report['residentId'] as String?;

      if (billId == null || residentId == null) {
        throw Exception('Invalid report data');
      }

      // Get the current bill
      final billDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(residentId)
          .collection('bills')
          .doc(billId)
          .get();

      if (!billDoc.exists) {
        throw Exception('Bill not found');
      }

      final billData = billDoc.data()!;
      final previousReading =
          billData['previousConsumedWaterMeter']?.toDouble() ?? 0.0;
      final purok = billData['purok'] ?? 'PUROK 1';

      // Calculate new values
      final cubicMeterUsed =
          newReading > previousReading ? newReading - previousReading : 0.0;

      // Recalculate bill based on purok
      double baseRate = 30.00;
      double ratePerCubicMeter = 5.00;
      switch (purok) {
        case 'COMMERCIAL':
          baseRate = 75.00;
          ratePerCubicMeter = 10.00;
          break;
        case 'NON-RESIDENCE':
          baseRate = 100.00;
          ratePerCubicMeter = 10.00;
          break;
        case 'INDUSTRIAL':
          baseRate = 100.00;
          ratePerCubicMeter = 15.00;
          break;
      }
      final excess = cubicMeterUsed > 10 ? cubicMeterUsed - 10 : 0;
      final newBillAmount = baseRate + (excess * ratePerCubicMeter);

      // Run transaction to update all related documents
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Update the bill
        final billRef = FirebaseFirestore.instance
            .collection('users')
            .doc(residentId)
            .collection('bills')
            .doc(billId);
        transaction.update(billRef, {
          'currentConsumedWaterMeter': newReading,
          'cubicMeterUsed': cubicMeterUsed,
          'currentMonthBill': newBillAmount,
          'updatedAt': Timestamp.now(),
        });

        // Update meter readings
        final meterRef = FirebaseFirestore.instance
            .collection('users')
            .doc(residentId)
            .collection('meter_readings')
            .doc('latest');
        transaction.set(
            meterRef,
            {
              'currentConsumedWaterMeter': newReading,
              'updatedAt': Timestamp.now(),
            },
            SetOptions(merge: true));

        // Mark report as resolved
        final reportRef =
            FirebaseFirestore.instance.collection('bill_reports').doc(reportId);
        transaction.update(reportRef, {
          'status': 'resolved',
          'reviewedBy': 'Admin',
          'reviewedAt': Timestamp.now(),
          'adminNotes': 'Bill updated and resolved. $notes',
        });
      });

      // Send notification to resident
      final periodStart = billData['periodStart'] as Timestamp?;
      final month = periodStart != null
          ? DateFormat('MMM yyyy').format(periodStart.toDate())
          : 'Current Month';

      final notificationData = {
        'userId': residentId,
        'type': 'report_resolved',
        'title': 'Report Resolved',
        'message':
            'Your bill report for $month has been resolved. The bill has been updated.',
        'billId': billId,
        'reportId': reportId,
        'status': 'resolved',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);

      // Refresh the list
      await _loadReportedBills();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill updated and report resolved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating bill and resolving report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUpdateBillDialog(String reportId, Map<String, dynamic> report) {
    final TextEditingController notesController = TextEditingController();
    final TextEditingController newReadingController = TextEditingController();
    final billId = report['billId'] as String?;
    final residentId = report['residentId'] as String?;
    bool _updating = false;

    // Get current bill details
    Map<String, dynamic>? currentBill;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Update Bill & Resolve Report',
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
                    'Resident: ${report['residentName']}',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.report_problem,
                                size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Report Reason:',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report['reportReason'] as String? ??
                              'No reason provided',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Current Bill Info (if available)
                  if (billId != null && residentId != null) ...[
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(residentId)
                          .collection('bills')
                          .doc(billId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            !snapshot.data!.exists) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Bill not found',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          );
                        }

                        final billData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        currentBill = billData;
                        final currentReading =
                            billData['currentConsumedWaterMeter']?.toDouble() ??
                                0.0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Bill Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _infoRow('Previous Reading',
                                  '${billData['previousConsumedWaterMeter']?.toStringAsFixed(2) ?? '0.00'} m³'),
                              _infoRow('Current Reading',
                                  '${currentReading.toStringAsFixed(2)} m³'),
                              _infoRow('Cubic Meter Used',
                                  '${billData['cubicMeterUsed']?.toStringAsFixed(2) ?? '0.00'} m³'),
                              _infoRow('Current Bill',
                                  '₱${billData['currentMonthBill']?.toStringAsFixed(2) ?? '0.00'}'),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  // New Reading Input
                  TextFormField(
                    controller: newReadingController,
                    decoration: InputDecoration(
                      labelText: 'New Current Reading (m³)',
                      hintText: 'Enter updated meter reading',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  // Admin Notes
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Update Notes (Will be sent to resident)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: After updating the bill, the report will be marked as resolved.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _updating
                    ? null
                    : () async {
                        final newReading =
                            double.tryParse(newReadingController.text);
                        if (newReading == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Please enter a valid reading')),
                          );
                          return;
                        }

                        if (notesController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Please provide update notes')),
                          );
                          return;
                        }

                        setState(() => _updating = true);
                        try {
                          await _updateBillAndResolveReport(
                            reportId,
                            report,
                            newReading,
                            notesController.text.trim(),
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        } finally {
                          setState(() => _updating = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _updating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Update & Resolve'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleExpand(String reportId) {
    setState(() {
      _expandedReports[reportId] = !(_expandedReports[reportId] ?? false);
    });
  }

  Widget _buildBillReceipt(Map<String, dynamic> billData) {
    final fullName = billData['fullName'] ?? 'N/A';
    final address = billData['address'] ?? 'N/A';
    final contactNumber = billData['contactNumber'] ?? 'N/A';
    final meterNumber = billData['meterNumber'] ?? 'N/A';
    final purok = billData['purok'] ?? 'PUROK 1';
    final periodStart = billData['periodStart'] as Timestamp?;
    final periodDue = billData['periodDue'] as Timestamp?;
    final issueDate = billData['issueDate'] as Timestamp?;
    final previousReading =
        billData['previousConsumedWaterMeter']?.toDouble() ?? 0.0;
    final currentReading =
        billData['currentConsumedWaterMeter']?.toDouble() ?? 0.0;
    final cubicMeterUsed = billData['cubicMeterUsed']?.toDouble() ?? 0.0;
    final currentMonthBill = billData['currentMonthBill']?.toDouble() ?? 0.0;
    final recordedByName = billData['recordedByName'] ?? 'Meter Reader';
    final formattedPeriodStart = periodStart != null
        ? DateFormat('MM-dd-yyyy').format(periodStart.toDate())
        : 'N/A';
    final formattedPeriodDue = periodDue != null
        ? DateFormat('MM-dd-yyyy').format(periodDue.toDate())
        : 'N/A';
    final formattedIssueDate = issueDate != null
        ? DateFormat('MMM dd, yyyy').format(issueDate.toDate())
        : 'N/A';
    final isOverdue =
        periodDue != null && DateTime.now().isAfter(periodDue.toDate());
    final dueColor = isOverdue ? Colors.red : Colors.black;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Receipt Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.water_drop,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'San Jose Water Services',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Sajowasa',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  purok,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bill Content
          Column(
            children: [
              _receiptRow('Name', fullName),
              _receiptRow('Address', address),
              _receiptRow('Contact', contactNumber),
              _receiptRow('Meter No.', meterNumber),
              _receiptRow('Recorded By', recordedByName),
              _receiptRow('Billing Period Start', formattedPeriodStart),
              _receiptRow('Billing Period Due', formattedPeriodDue),
              _receiptRow('Issue Date', formattedIssueDate),
              const SizedBox(height: 8),
              _dashedDivider(),
              _receiptRow('Previous Reading',
                  '${previousReading.toStringAsFixed(2)} m³'),
              _receiptRow(
                  'Current Reading', '${currentReading.toStringAsFixed(2)} m³'),
              _receiptRow(
                  'Cubic Meter Used', '${cubicMeterUsed.toStringAsFixed(2)} m³',
                  isBold: true),
              const SizedBox(height: 8),
              _dashedDivider(),
              _receiptRow(
                  'Current Bill', '₱${currentMonthBill.toStringAsFixed(2)}',
                  valueColor: Colors.red, isBold: true, fontSize: 13),
              _receiptRow('Due Date', formattedPeriodDue, valueColor: dueColor),
              if (isOverdue)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Overdue: Pay immediately to avoid penalties.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Compact Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.report_problem,
                      color: Colors.orange.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported Bills',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_reportedBills.length} pending reports',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
              child: _loading && _reportedBills.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _reportedBills.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 48, color: Colors.green),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No pending reports',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (ScrollNotification scrollInfo) {
                                if (_hasMoreReports &&
                                    !_loading &&
                                    scrollInfo.metrics.pixels ==
                                        scrollInfo.metrics.maxScrollExtent) {
                                  _loadReportedBills(loadMore: true);
                                  return true;
                                }
                                return false;
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _reportedBills.length +
                                    (_hasMoreReports ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _reportedBills.length) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Center(
                                        child: _loading
                                            ? CircularProgressIndicator()
                                            : Container(),
                                      ),
                                    );
                                  }
                                  final report = _reportedBills[index];
                                  final reportId =
                                      report['reportId'] as String? ?? '';
                                  final residentId =
                                      report['residentId'] as String?;
                                  final billId = report['billId'] as String?;
                                  final residentDetails =
                                      _residentDetails[residentId] ?? {};
                                  final billDetails =
                                      _billDetails[billId ?? ''];
                                  final submittedAt =
                                      report['submittedAt'] as Timestamp?;
                                  final isExpanded =
                                      _expandedReports[reportId] ?? false;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Card(
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor:
                                                      Colors.orange.shade100,
                                                  child: Icon(Icons.person,
                                                      color: Colors.orange,
                                                      size: 18),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        report['residentName']
                                                                as String? ??
                                                            'Unknown',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      Text(
                                                        residentDetails[
                                                                    'address']
                                                                as String? ??
                                                            'No address',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                      if (submittedAt != null)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 2),
                                                          child: Text(
                                                            'Reported: ${DateFormat('MMM d, h:mm a').format(submittedAt.toDate())}',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 10,
                                                              color: Colors.grey
                                                                  .shade600,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.orange.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    'REPORTED',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors
                                                          .orange.shade800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            // Report reason
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.red.shade100),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.report_problem,
                                                          size: 14,
                                                          color: Colors
                                                              .red.shade700),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Report Reason',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors
                                                              .red.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    report['reportReason']
                                                            as String? ??
                                                        'No reason provided',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Expand/Collapse button for bill details
                                            if (billDetails != null) ...[
                                              const SizedBox(height: 12),
                                              GestureDetector(
                                                onTap: () =>
                                                    _toggleExpand(reportId),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: Colors
                                                            .blue.shade200),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .receipt_long,
                                                              size: 16,
                                                              color: Colors.blue
                                                                  .shade700),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                            'View Bill Details',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors.blue
                                                                  .shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Icon(
                                                        isExpanded
                                                            ? Icons.expand_less
                                                            : Icons.expand_more,
                                                        size: 18,
                                                        color: Colors
                                                            .blue.shade700,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Collapsible bill details
                                              if (isExpanded) ...[
                                                const SizedBox(height: 12),
                                                _buildBillReceipt(billDetails),
                                              ],
                                            ],
                                            // Update Bill button only
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _showUpdateBillDialog(
                                                        reportId, report),
                                                icon:
                                                    Icon(Icons.edit, size: 16),
                                                label: Text(
                                                    'Update Bill & Resolve Report'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
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
                            )),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ));
  }

  Widget _receiptRow(String label, String value,
      {Color? valueColor, bool isBold = false, double fontSize = 11}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  fontSize: fontSize,
                  color: valueColor ?? Colors.grey.shade800,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ));
  }

  Widget _dashedDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: List.generate(
            30,
            (i) => Expanded(
              child: Container(
                height: 1,
                color: i.isEven ? Colors.grey.shade300 : Colors.transparent,
              ),
            ),
          ),
        ),
      );
}

class _ResidentCard extends StatefulWidget {
  final String residentId, fullName, address, contactNumber;

  const _ResidentCard({
    required this.residentId,
    required this.fullName,
    required this.address,
    required this.contactNumber,
  });

  @override
  State<_ResidentCard> createState() => _ResidentCardState();
}

class _ResidentCardState extends State<_ResidentCard> {
  bool _showPayments = false;
  bool _hasBills = false;
  bool _isCheckingBills = true;
  bool _hasUnpaidBills = false;
  Map<String, dynamic>? _unpaidBillData;
  bool _loadingBill = false;

  @override
  void initState() {
    super.initState();
    _checkForExistingBills();
  }

  Future<void> _checkForExistingBills() async {
    try {
      // Check if resident has any bills
      final billSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.residentId)
          .collection('bills')
          .limit(1)
          .get();

      _hasBills = billSnapshot.docs.isNotEmpty;

      // Check if resident has unpaid bills (bills without approved payments)
      if (_hasBills) {
        final paidBillIds = await FirebaseFirestore.instance
            .collection('payments')
            .where('residentId', isEqualTo: widget.residentId)
            .where('status', isEqualTo: 'approved')
            .get()
            .then((snapshot) =>
                snapshot.docs.map((doc) => doc['billId'] as String).toSet());

        final unpaidBillSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.residentId)
            .collection('bills')
            .where(FieldPath.documentId,
                whereNotIn: paidBillIds.isEmpty ? null : paidBillIds.toList())
            .orderBy('periodStart', descending: true)
            .limit(1)
            .get();

        _hasUnpaidBills = unpaidBillSnapshot.docs.isNotEmpty;
        
        // Get the unpaid bill data for the view bill modal
        if (_hasUnpaidBills) {
          _unpaidBillData = {
            ...unpaidBillSnapshot.docs.first.data(),
            'billId': unpaidBillSnapshot.docs.first.id,
          };
        }
      }

      if (mounted) {
        setState(() {
          _isCheckingBills = false;
        });
      }
    } catch (e) {
      print('Error checking bills: $e');
      if (mounted) {
        setState(() {
          _isCheckingBills = false;
        });
      }
    }
  }

  void _showViewBillModal() {
    if (_unpaidBillData == null) return;

    final bill = _unpaidBillData!;
    final currentConsumed = bill['currentConsumedWaterMeter']?.toDouble() ?? 0.0;
    final previousConsumed = bill['previousConsumedWaterMeter']?.toDouble() ?? 0.0;
    final cubicMeterUsed = bill['cubicMeterUsed']?.toDouble() ?? 0.0;
    final currentMonthBill = bill['currentMonthBill']?.toDouble() ?? 0.0;
    final periodStart = bill['periodStart'] as Timestamp?;
    final periodDue = bill['periodDue'] as Timestamp?;
    final issueDate = bill['issueDate'] as Timestamp?;
    final formattedPeriodStart = periodStart != null
        ? DateFormat('MM-dd-yyyy').format(periodStart.toDate())
        : 'N/A';
    final formattedPeriodDue = periodDue != null
        ? DateFormat('MM-dd-yyyy').format(periodDue.toDate())
        : 'N/A';
    final formattedIssueDate = issueDate != null
        ? DateFormat('MMM dd, yyyy').format(issueDate.toDate())
        : 'N/A';
    final isOverdue = periodDue != null && DateTime.now().isAfter(periodDue.toDate());
    final dueColor = isOverdue ? Colors.red : Colors.black;
    final recordedByName = bill['recordedByName'] ?? 'Meter Reader';
    final purok = bill['purok'] ?? 'PUROK 1';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'View Bill',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A90E2),
                              ),
                            ),
                            Text(
                              widget.fullName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF4A90E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        purok,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Bill Details Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WATER BILL STATEMENT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 12),
                        _dashedDivider(),
                        _receiptRow('Name', widget.fullName),
                        _receiptRow('Address', widget.address),
                        _receiptRow('Contact', widget.contactNumber),
                        _receiptRow('Meter No.', bill['meterNumber'] ?? 'N/A'),
                        _receiptRow('Recorded By', recordedByName),
                        _receiptRow('Billing Period Start', formattedPeriodStart),
                        _receiptRow('Billing Period Due', formattedPeriodDue),
                        _receiptRow('Issue Date', formattedIssueDate),
                        _dashedDivider(),
                        _receiptRow('Previous Reading', '${previousConsumed.toStringAsFixed(2)} m³'),
                        _receiptRow('Current Reading', '${currentConsumed.toStringAsFixed(2)} m³'),
                        _receiptRow('Cubic Meter Used', '${cubicMeterUsed.toStringAsFixed(2)} m³', isBold: true),
                        _dashedDivider(),
                        _receiptRow('Current Bill', '₱${currentMonthBill.toStringAsFixed(2)}',
                            valueColor: Colors.red, isBold: true, fontSize: 14),
                        _receiptRow('Due Date', formattedPeriodDue, valueColor: dueColor),
                        
                        if (isOverdue)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.red, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Overdue: Pay immediately to avoid penalties.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(color: Color(0xFF4A90E2)),
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
  }

  Widget _receiptRow(String label, String value,
      {Color? valueColor, bool isBold = false, double fontSize = 12}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: fontSize,
                color: valueColor ?? Colors.grey.shade800,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() => Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: List.generate(
            30,
            (i) => Expanded(
              child: Container(
                height: 1,
                color: i.isEven ? Colors.grey.shade300 : Colors.transparent,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.1),
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            title: Text(
              widget.fullName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF2D3748),
              ),
            ),
            subtitle: Text(
              '${widget.address}\n${widget.contactNumber}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Color(0xFF718096),
                height: 1.4,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bill Status Indicator with View Bill button
                if (_hasUnpaidBills && !_isCheckingBills)
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    child: ElevatedButton.icon(
                      onPressed: _showViewBillModal,
                      icon: Icon(Icons.visibility, size: 14),
                      label: Text('View Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                
                // Status indicator container
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isCheckingBills
                        ? Colors.grey.shade200
                        : (_hasUnpaidBills
                            ? Colors.orange.shade100
                            : Colors.green.shade100),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isCheckingBills
                          ? Colors.grey.shade300
                          : (_hasUnpaidBills
                              ? Colors.orange.shade300
                              : Colors.green.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isCheckingBills) ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Checking...',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ] else if (_hasUnpaidBills) ...[
                        Icon(
                          Icons.pending_actions,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Unpaid',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ] else if (_hasBills) ...[
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Paid',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.credit_card_off,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'No Bill',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    _showPayments ? Icons.expand_less : Icons.expand_more,
                    color: Color(0xFF1E88E5),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _showPayments = !_showPayments),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: SizedBox.shrink(),
            secondChild: _PaymentSection(
                residentId: widget.residentId, fullName: widget.fullName),
            crossFadeState: _showPayments
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 500),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatefulWidget {
  final String residentId;
  final String fullName;

  const _PaymentSection({required this.residentId, required this.fullName});

  @override
  State<_PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<_PaymentSection> {
  List<Map<String, dynamic>> _paymentData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPaymentsAndBills();
  }

  Future<void> _addConsumptionHistory({
    required String userId,
    required DateTime periodStart,
    required double cubicMeterUsed,
  }) async {
    try {
      final year = periodStart.year;
      final month = periodStart.month;
      final docId = '$year-${month.toString().padLeft(2, '0')}';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('consumption_history')
          .doc(docId)
          .set({
        'periodStart': Timestamp.fromDate(periodStart),
        'cubicMeterUsed': cubicMeterUsed,
        'year': year,
        'month': month,
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));
      print(
          'Added consumption history for $userId: $docId, $cubicMeterUsed m³');
    } catch (e) {
      print('Error adding consumption history: $e');
    }
  }

  Future<void> _recordTransactionHistory({
    required String residentId,
    required String type,
    required String status,
    required double amount,
    required String description,
    required String? billId,
    required String? month,
  }) async {
    try {
      final transactionData = {
        'residentId': residentId,
        'type': type,
        'status': status,
        'amount': amount,
        'description': description,
        'billId': billId,
        'month': month,
        'timestamp': FieldValue.serverTimestamp(),
        'processedBy': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('transaction_history')
          .add(transactionData);
      print('Transaction history recorded: $transactionData');
    } catch (e) {
      print('Error recording transaction history: $e');
    }
  }

  Future<void> _fetchPaymentsAndBills() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      // Fetch ALL payments (not just pending)
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('residentId', isEqualTo: widget.residentId)
          .orderBy('submissionDate', descending: true)
          .get();
      final payments = paymentSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['paymentId'] = doc.id;
        return data;
      }).toList();
      final billData = <String, String>{};
      final billIds = payments
          .map((payment) => payment['billId'] as String?)
          .where((billId) => billId != null)
          .toSet();
      if (billIds.isNotEmpty) {
        final billFutures = billIds.map((billId) => FirebaseFirestore.instance
            .collection('users')
            .doc(widget.residentId)
            .collection('bills')
            .doc(billId!)
            .get());
        final billDocs = await Future.wait(billFutures);
        for (var i = 0; i < billIds.length; i++) {
          final billDoc = billDocs[i];
          final billId = billIds.elementAt(i);
          if (billDoc.exists) {
            final periodStart =
                (billDoc.data()!['periodStart'] as Timestamp?)?.toDate();
            billData[billId!] = periodStart != null
                ? DateFormat('MMM yyyy').format(periodStart)
                : 'N/A';
          } else {
            billData[billId!] = 'N/A';
          }
        }
      }
      final combinedData = payments.map((payment) {
        return {
          ...payment,
          'billingDate': billData[payment['billId'] as String] ?? 'N/A',
        };
      }).toList();
      if (mounted) {
        setState(() {
          _paymentData = combinedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching payments and bills: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading payments: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePaymentStatus(BuildContext context, String paymentId,
      String status, String? billId, String? rejectionReason) async {
    print(
        'Updating payment status: paymentId=$paymentId, status=$status, billId=$billId');
    try {
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .get();
      if (!paymentDoc.exists) {
        print('Payment document not found: $paymentId');
        throw Exception('Payment not found');
      }
      final paymentData = paymentDoc.data()!;
      print('Payment data: $paymentData');
      String month = 'Unknown';
      double currentReading = 0.0;
      double cubicMeterUsed = 0.0;
      DateTime? periodStart;
      double amount = paymentData['billAmount']?.toDouble() ?? 0.0;
      if (billId != null) {
        final billDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.residentId)
            .collection('bills')
            .doc(billId)
            .get();
        if (billDoc.exists) {
          final billData = billDoc.data()!;
          periodStart = (billData['periodStart'] as Timestamp?)?.toDate();
          month = periodStart != null
              ? DateFormat('MMM yyyy').format(periodStart)
              : 'Unknown';
          currentReading =
              billData['currentConsumedWaterMeter']?.toDouble() ?? 0.0;
          cubicMeterUsed = billData['cubicMeterUsed']?.toDouble() ?? 0.0;
          print(
              'Bill found, month: $month, currentReading: $currentReading, cubicMeterUsed: $cubicMeterUsed');
        } else {
          print('Bill not found for billId: $billId');
        }
      } else {
        print('No billId provided');
      }
      // Create notification for resident with rejection reason
      String message;
      if (status == 'approved') {
        message =
            'Your payment of ₱${amount.toStringAsFixed(2)} for $month has been approved.';
      } else {
        message =
            'Your payment of ₱${amount.toStringAsFixed(2)} for $month has been rejected.';
        if (rejectionReason != null && rejectionReason.isNotEmpty) {
          message += '\n\nReason: $rejectionReason';
        }
      }
      final notificationData = {
        'userId': widget.residentId,
        'type': 'payment',
        'title': status == 'approved' ? 'Payment Approved' : 'Payment Rejected',
        'message': message,
        'billId': billId ?? 'Unknown',
        'status': status,
        'month': month,
        'amount': amount,
        'rejectionReason': rejectionReason,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      print('Saving notification: $notificationData');
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);
      print('Notification saved successfully');
      // Record transaction history
      await _recordTransactionHistory(
        residentId: widget.residentId,
        type: 'Payment',
        status: status,
        amount: amount,
        description: status == 'approved'
            ? 'Payment approved for $month'
            : 'Payment rejected for $month${rejectionReason != null ? ' - $rejectionReason' : ''}',
        billId: billId,
        month: month,
      );
      if (status == 'approved') {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(paymentId)
            .update({
          'status': 'approved',
          'processedDate': FieldValue.serverTimestamp(),
          'processedBy': 'Admin',
        });
        print('Payment updated to approved');
        // Add to logs
        await FirebaseFirestore.instance.collection('logs').add({
          'action': 'Payment Accepted',
          'userId': widget.residentId,
          'details':
              'Payment for $month by ${widget.fullName} accepted. Amount: ₱${amount.toStringAsFixed(2)}',
          'timestamp': FieldValue.serverTimestamp(),
        });
        // Add consumption history if bill exists
        if (billId != null && periodStart != null) {
          await _addConsumptionHistory(
            userId: widget.residentId,
            periodStart: periodStart,
            cubicMeterUsed: cubicMeterUsed,
          );
        }
        // Update meter readings
        if (billId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.residentId)
              .collection('meter_readings')
              .doc('latest')
              .set({
            'currentConsumedWaterMeter': currentReading,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('Stored current reading: $currentReading');
        }
        // Delete unpaid bills after payment approval
        final unpaidBillsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.residentId)
            .collection('bills')
            .get();
        for (var billDoc in unpaidBillsSnapshot.docs) {
          await billDoc.reference.delete();
          print('Bill deleted: ${billDoc.id}');
        }
        // Update the local state immediately
        if (mounted) {
          setState(() {
            // Find and update the payment in the list
            final index =
                _paymentData.indexWhere((p) => p['paymentId'] == paymentId);
            if (index != -1) {
              _paymentData[index]['status'] = 'approved';
              _paymentData[index]['processedDate'] = Timestamp.now();
            }
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment approved and all bills cleared!',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else if (status == 'rejected') {
        // For rejection, keep payment but mark as rejected
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(paymentId)
            .update({
          'status': 'rejected',
          'rejectionReason': rejectionReason,
          'processedDate': FieldValue.serverTimestamp(),
          'processedBy': 'Admin',
        });
        print('Payment marked as rejected');
        // Update the local state immediately
        if (mounted) {
          setState(() {
            // Find and update the payment in the list
            final index =
                _paymentData.indexWhere((p) => p['paymentId'] == paymentId);
            if (index != -1) {
              _paymentData[index]['status'] = 'rejected';
              _paymentData[index]['rejectionReason'] = rejectionReason;
              _paymentData[index]['processedDate'] = Timestamp.now();
            }
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment rejected successfully!',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
      // Refresh data from server to ensure consistency
      await _fetchPaymentsAndBills();
    } catch (e) {
      print('Error updating payment status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error ${status == 'approved' ? 'approving payment and clearing bills' : 'rejecting payment'}: $e',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showRejectDialog(
      BuildContext context, String paymentId, String? billId) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          'Reject Payment',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Color(0xFF2D3748),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejecting this payment:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Color(0xFF718096),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFEDF2F7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF1E88E5)),
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
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Color(0xFF1E88E5),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please provide a reason for rejection'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              Navigator.pop(context);
              await _updatePaymentStatus(
                  context, paymentId, 'rejected', billId, reason);
            },
            child: Text(
              'Reject',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: Color(0xFFEDF2F7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
              ),
            )
          else if (_error != null)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
              ),
            )
          else if (_paymentData.isEmpty)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'No payment history for this resident.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Color(0xFF718096)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _paymentData.length,
              itemBuilder: (context, index) {
                final payment = _paymentData[index];
                final paymentId = payment['paymentId'] as String;
                final billId = payment['billId'] as String? ?? 'Unknown';
                final amount =
                    (payment['billAmount'] as num?)?.toDouble() ?? 0.0;
                final status = payment['status'] ?? 'pending';
                final receiptImage = payment['receiptImage'] as String?;
                final billingDate = payment['billingDate'] as String;
                final submissionDate = payment['submissionDate'] as Timestamp?;
                final processedDate = payment['processedDate'] as Timestamp?;
                final rejectionReason = payment['rejectionReason'] as String?;
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Color(0xFFEDF2F7), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill ID: $billId',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            Text(
                              'Amount: ₱${amount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Color(0xFF718096),
                              ),
                            ),
                            Text(
                              'Status: ${_getStatusText(status)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Billing Date: $billingDate',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Color(0xFF718096),
                              ),
                            ),
                            if (rejectionReason != null &&
                                rejectionReason.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Reason: $rejectionReason',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.red.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            if (submissionDate != null)
                              Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'Submitted: ${DateFormat('MMM dd, yyyy').format(submissionDate.toDate())}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            if (processedDate != null && status != 'pending')
                              Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'Processed: ${DateFormat('MMM dd, yyyy').format(processedDate.toDate())}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: status == 'approved'
                                        ? Colors.green.shade600
                                        : Colors.red.shade600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (receiptImage != null)
                            AnimatedScale(
                              scale: 1.0,
                              duration: Duration(milliseconds: 200),
                              child: TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: EdgeInsets.all(20),
                                      child: Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl:
                                                'data:image/jpeg;base64,$receiptImage',
                                            placeholder: (context, url) =>
                                                Center(
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        Color(0xFF1E88E5)),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Icon(
                                              Icons.error,
                                              color: Colors.red,
                                              size: 30,
                                            ),
                                            width: double.infinity,
                                            height: 250,
                                            fit: BoxFit.contain,
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.close,
                                                color: Colors.white, size: 24),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            padding: EdgeInsets.all(8),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Color(0xFF1E88E5)),
                                ),
                                child: Text('View Receipt'),
                              ),
                            ),
                          if (status == 'pending') ...[
                            SizedBox(width: 8),
                            AnimatedScale(
                              scale: 1.0,
                              duration: Duration(milliseconds: 200),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF81D4FA),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  minimumSize: Size(60, 36),
                                  textStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                onPressed: () => _updatePaymentStatus(context,
                                    paymentId, 'approved', billId, null),
                                child: Text('Accept'),
                              ),
                            ),
                            SizedBox(width: 8),
                            AnimatedScale(
                              scale: 1.0,
                              duration: Duration(milliseconds: 200),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  minimumSize: Size(60, 36),
                                  textStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                onPressed: () => _showRejectDialog(
                                    context, paymentId, billId),
                                child: Text('Reject'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_full;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}