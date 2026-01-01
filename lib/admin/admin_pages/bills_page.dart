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
                              onBillCreated: _fetchTotalPages,
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

  // NEW: Show Reported Bills Modal
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

// Replace the entire ReportedBillsModal class with this improved version:
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
  // ignore: unused_field
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

  Future<void> _updateReportStatus(
      String reportId, String status, String adminNotes) async {
    try {
      await FirebaseFirestore.instance
          .collection('bill_reports')
          .doc(reportId)
          .update({
        'status': status,
        'reviewedBy': 'Admin',
        'reviewedAt': Timestamp.now(),
        'adminNotes': adminNotes,
      });
      // Send notification to resident WITH ADMIN NOTES
      final report =
          _reportedBills.firstWhere((r) => r['reportId'] == reportId);
      String message;
      if (status == 'resolved') {
        message = 'Your bill report has been resolved.';
        if (adminNotes.isNotEmpty) {
          message += '\n\nAdmin Notes: $adminNotes';
        }
      } else {
        message = 'Your bill report has been marked as reviewed.';
        if (adminNotes.isNotEmpty) {
          message += '\n\nAdmin Notes: $adminNotes';
        }
      }
      final notificationData = {
        'userId': report['residentId'],
        'type': 'report',
        'title': 'Report ${status[0].toUpperCase()}${status.substring(1)}',
        'message': message, // INCLUDES ADMIN NOTES
        'reportId': reportId,
        'billId': report['billId'],
        'status': status,
        'adminNotes': adminNotes, // Store admin notes separately too
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);
      // Refresh the list
      await _loadReportedBills();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report $status successfully!'),
          backgroundColor: status == 'resolved' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      print('Error updating report status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteReport(String reportId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bill_reports')
          .doc(reportId)
          .delete();
      // Remove from local list
      setState(() {
        _reportedBills.removeWhere((report) => report['reportId'] == reportId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showUpdateBillDialog(
      String reportId, Map<String, dynamic> report) async {
    final TextEditingController notesController = TextEditingController();
    final TextEditingController newReadingController = TextEditingController();
    final billId = report['billId'] as String?;
    final residentId = report['residentId'] as String?;
    bool _updating = false;
    // Get current bill details
    Map<String, dynamic>? currentBill;
    if (billId != null && residentId != null) {
      final billDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(residentId)
          .collection('bills')
          .doc(billId)
          .get();
      if (billDoc.exists) {
        currentBill = billDoc.data()!;
      }
    }
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Update Resident Bill',
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
                  Text(
                    'Report Reason: ${report['reportReason']}',
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  // Current Bill Info
                  if (currentBill != null) ...[
                    Container(
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
                              '${currentBill['previousConsumedWaterMeter']?.toStringAsFixed(2) ?? '0.00'} m³'),
                          _infoRow('Current Reading',
                              '${currentBill['currentConsumedWaterMeter']?.toStringAsFixed(2) ?? '0.00'} m³'),
                          _infoRow('Cubic Meter Used',
                              '${currentBill['cubicMeterUsed']?.toStringAsFixed(2) ?? '0.00'} m³'),
                          _infoRow('Current Bill',
                              '₱${currentBill['currentMonthBill']?.toStringAsFixed(2) ?? '0.00'}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // New Reading Input
                  TextFormField(
                    controller: newReadingController,
                    decoration: InputDecoration(
                      labelText: 'New Current Reading (m³)',
                      hintText: currentBill?['currentConsumedWaterMeter']
                              ?.toString() ??
                          '0.00',
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
                        final currentReading =
                            currentBill?['currentConsumedWaterMeter']
                                    ?.toDouble() ??
                                0.0;
                        if (newReading == null ||
                            newReading == currentReading) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Please enter a new valid reading different from current')),
                          );
                          return;
                        }
                        setState(() => _updating = true);
                        try {
                          // Update the bill in Firestore
                          await FirebaseFirestore.instance
                              .runTransaction((transaction) async {
                            // Get the current bill
                            final billRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(residentId!)
                                .collection('bills')
                                .doc(billId!);
                            final billDoc = await transaction.get(billRef);
                            if (billDoc.exists) {
                              final billData = billDoc.data()!;
                              final previousReading =
                                  billData['previousConsumedWaterMeter']
                                          ?.toDouble() ??
                                      0.0;
                              final cubicMeterUsed =
                                  newReading > previousReading
                                      ? newReading - previousReading
                                      : 0.0;
                              // Recalculate bill based on purok
                              final purok = billData['purok'] ?? 'PUROK 1';
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
                              final excess =
                                  cubicMeterUsed > 10 ? cubicMeterUsed - 10 : 0;
                              final newBillAmount =
                                  baseRate + (excess * ratePerCubicMeter);
                              // Update bill
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
                              final reportRef = FirebaseFirestore.instance
                                  .collection('bill_reports')
                                  .doc(reportId);
                              transaction.update(reportRef, {
                                'status': 'resolved',
                                'reviewedBy': 'Admin',
                                'reviewedAt': Timestamp.now(),
                                'adminNotes':
                                    'Bill updated. ${notesController.text}',
                              });
                            }
                          });
                          // Send notification to resident about updated bill
                          final periodStart =
                              currentBill?['periodStart'] as Timestamp?;
                          final month = periodStart != null
                              ? DateFormat('MMM yyyy')
                                  .format(periodStart.toDate())
                              : 'Current Month';
                          final notificationData = {
                            'userId': residentId,
                            'type': 'bill_updated',
                            'title': 'Bill Updated',
                            'message':
                                'Your bill for $month has been updated by the admin.',
                            'billId': billId,
                            'month': month,
                            'status': 'updated',
                            'read': false,
                            'timestamp': FieldValue.serverTimestamp(),
                          };
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .add(notificationData);
                          Navigator.pop(context);
                          await _loadReportedBills();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Bill updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          print('Error updating bill: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating bill: $e'),
                              backgroundColor: Colors.red,
                            ),
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
                    : Text('Update Bill & Resolve'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showActionDialog(String reportId, Map<String, dynamic> report) {
    final TextEditingController notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Manage Report',
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
              Text(
                'Report Reason:',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                report['reportReason'] as String? ?? 'No reason provided',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Admin Notes (Will be sent to resident)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
            onPressed: () => _showUpdateBillDialog(reportId, report),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Update Bill'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReport(reportId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete Report'),
          ),
        ],
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
                                final billDetails = _billDetails[billId ?? ''];
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
                                                      CrossAxisAlignment.start,
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
                                                      residentDetails['address']
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
                                                            color: Colors
                                                                .grey.shade600,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'REPORTED',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.orange.shade800,
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
                                                        color:
                                                            Colors.red.shade700,
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
                                                    color: Colors.grey.shade800,
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
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color:
                                                          Colors.blue.shade200),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.receipt_long,
                                                            size: 16,
                                                            color: Colors
                                                                .blue.shade700),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          'View Bill Details',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .blue.shade700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Icon(
                                                      isExpanded
                                                          ? Icons.expand_less
                                                          : Icons.expand_more,
                                                      size: 18,
                                                      color:
                                                          Colors.blue.shade700,
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
                                          // Action buttons
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showActionDialog(
                                                          reportId, report),
                                                  icon: Icon(Icons.more_vert,
                                                      size: 16),
                                                  label: Text('Actions'),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.blue,
                                                    side: BorderSide(
                                                        color: Colors.blue),
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _showUpdateBillDialog(
                                                          reportId, report),
                                                  icon: Icon(Icons.edit,
                                                      size: 16),
                                                  label: Text('Update Bill'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blue,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
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
                              },
                            ),
                          ),
          ),
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
      ),
    );
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
  final VoidCallback onBillCreated;

  const _ResidentCard({
    required this.residentId,
    required this.fullName,
    required this.address,
    required this.contactNumber,
    required this.onBillCreated,
  });

  @override
  State<_ResidentCard> createState() => _ResidentCardState();
}

class _ResidentCardState extends State<_ResidentCard> {
  bool _showPayments = false;
  bool _hasBills = false;
  bool _isCheckingBills = true;

  @override
  void initState() {
    super.initState();
    _checkForExistingBills();
  }

  Future<void> _checkForExistingBills() async {
    try {
      final billSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.residentId)
          .collection('bills')
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _hasBills = billSnapshot.docs.isNotEmpty;
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

  @override
  Widget build(BuildContext context) {
    return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.1),
        color: Colors.white,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              title: Text(
                widget.fullName,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF2D3748),
                ),
              ),
              subtitle: Text(
                '${widget.address}\n${widget.contactNumber}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF718096),
                  height: 1.4,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _showPayments ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF1E88E5),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _showPayments = !_showPayments),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        elevation: 2,
                      ),
                      onPressed: _isCheckingBills
                          ? null
                          : () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black54,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  insetPadding: const EdgeInsets.all(10),
                                  child: _BillReceiptForm(
                                    residentId: widget.residentId,
                                    fullName: widget.fullName,
                                    address: widget.address,
                                    contactNumber: widget.contactNumber,
                                  ),
                                ),
                              ).then((value) {
                                widget.onBillCreated();
                                _checkForExistingBills();
                              });
                            },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasBills && !_isCheckingBills) ...[
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(_isCheckingBills
                              ? 'Loading...'
                              : (_hasBills ? 'Update Bill' : 'Create Bill')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _PaymentSection(
                  residentId: widget.residentId, fullName: widget.fullName),
              crossFadeState: _showPayments
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 500),
              sizeCurve: Curves.easeInOutCubic,
            ),
          ],
        ));
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
              duration: const Duration(seconds: 2),
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
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
            duration: const Duration(seconds: 2),
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
            color: const Color(0xFF2D3748),
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
                color: const Color(0xFF718096),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFEDF2F7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E88E5)),
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
                color: const Color(0xFF1E88E5),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
              ),
            )
          else if (_paymentData.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'No payment history for this resident.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF718096)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFEDF2F7), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill ID: $billId',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2D3748),
                              ),
                            ),
                            Text(
                              'Amount: ₱${amount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF718096),
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
                                color: const Color(0xFF718096),
                              ),
                            ),
                            if (rejectionReason != null &&
                                rejectionReason.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
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
                                padding: const EdgeInsets.only(top: 2),
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
                                padding: const EdgeInsets.only(top: 2),
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
                              duration: const Duration(milliseconds: 200),
                              child: TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: const EdgeInsets.all(20),
                                      child: Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl:
                                                'data:image/jpeg;base64,$receiptImage',
                                            placeholder: (context, url) =>
                                                const Center(
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        Color(0xFF1E88E5)),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
                                              Icons.error,
                                              color: Colors.red,
                                              size: 30,
                                            ),
                                            width: double.infinity,
                                            height: 250,
                                            fit: BoxFit.contain,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                color: Colors.white, size: 24),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            padding: const EdgeInsets.all(8),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF1E88E5)),
                                ),
                                child: const Text('View Receipt'),
                              ),
                            ),
                          if (status == 'pending') ...[
                            const SizedBox(width: 8),
                            AnimatedScale(
                              scale: 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81D4FA),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  minimumSize: const Size(60, 36),
                                  textStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                onPressed: () => _updatePaymentStatus(context,
                                    paymentId, 'approved', billId, null),
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedScale(
                              scale: 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  minimumSize: const Size(60, 36),
                                  textStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                onPressed: () => _showRejectDialog(
                                    context, paymentId, billId),
                                child: const Text('Reject'),
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

class _BillReceiptForm extends StatefulWidget {
  final String fullName, address, contactNumber, residentId;

  const _BillReceiptForm({
    required this.fullName,
    required this.address,
    required this.contactNumber,
    required this.residentId,
  });

  @override
  State<_BillReceiptForm> createState() => _BillReceiptFormState();
}

class _BillReceiptFormState extends State<_BillReceiptForm> {
  final _formKey = GlobalKey<FormState>();
  double current = 0.0;
  double previous = 0.0;
  bool _loading = true;
  DateTime? periodStart;
  DateTime? periodDue;
  String selectedPurok = 'PUROK 1';
  String meterNumber = '';
  String? _error;

  double get cubicMeterUsed => current >= previous ? current - previous : 0.0;

  double get currentBill => calculateCurrentBill();

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
      print('Error saving consumption history: $e');
      if (mounted) {
        setState(() {
          _error = 'Error saving consumption history: $e';
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: periodStart ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        periodStart = picked;
        periodDue = picked.add(const Duration(days: 30));
      });
    }
  }

  double calculateCurrentBill() {
    double baseRate = getMinimumRate();
    double excess = cubicMeterUsed > 10 ? cubicMeterUsed - 10 : 0;
    return baseRate + (excess * getRatePerCubicMeter());
  }

  double getMinimumRate() {
    switch (selectedPurok) {
      case 'PUROK 1':
      case 'PUROK 2':
      case 'PUROK 3':
      case 'PUROK 4':
      case 'PUROK 5':
        return 30.00;
      case 'COMMERCIAL':
        return 75.00;
      case 'NON-RESIDENCE':
        return 100.00;
      case 'INDUSTRIAL':
        return 100.00;
      default:
        return 0.00;
    }
  }

  double getRatePerCubicMeter() {
    switch (selectedPurok) {
      case 'PUROK 1':
      case 'PUROK 2':
      case 'PUROK 3':
      case 'PUROK 4':
      case 'PUROK 5':
        return 5.00;
      case 'COMMERCIAL':
        return 10.00;
      case 'NON-RESIDENCE':
        return 10.00;
      case 'INDUSTRIAL':
        return 15.00;
      default:
        return 0.00;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPreviousReading();
  }

  Future<void> _loadPreviousReading() async {
    try {
      print('Loading data for resident: ${widget.residentId}');
      setState(() {
        _loading = true;
        _error = null;
      });
      // Fetch meter reading
      final meterSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.residentId)
          .collection('meter_readings')
          .doc('latest')
          .get();
      print('Meter reading document exists: ${meterSnapshot.exists}');
      if (meterSnapshot.exists && mounted) {
        final data = meterSnapshot.data()!;
        setState(() {
          previous = data['currentConsumedWaterMeter']?.toDouble() ?? 0.0;
          print('Previous reading set to: $previous');
        });
      } else {
        setState(() {
          previous = 0.0;
          print('No previous reading found, defaulting to 0.0');
        });
      }
      // Fetch meter number from user document
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.residentId)
          .get();
      if (userSnapshot.exists &&
          userSnapshot.data()!.containsKey('meterNumber') &&
          mounted) {
        setState(() {
          meterNumber = userSnapshot.data()!['meterNumber'] ?? '';
          print('Meter number from user document: $meterNumber');
        });
      } else {
        print('No meter number in user document, checking latest bill');
        // Fallback to latest bill
        final billSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.residentId)
            .collection('bills')
            .orderBy('periodStart', descending: true)
            .limit(1)
            .get();
        if (billSnapshot.docs.isNotEmpty && mounted) {
          setState(() {
            meterNumber = billSnapshot.docs.first.data()['meterNumber'] ?? '';
            print('Meter number from latest bill: $meterNumber');
          });
        } else {
          print('No meter number found in bills');
          setState(() {
            meterNumber = '';
          });
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading previous reading or meter number: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error loading data: $e';
        });
      }
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
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('transaction_history')
          .add(transactionData);
      print('Transaction history recorded for bill creation: $transactionData');
    } catch (e) {
      print('Error recording transaction history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset('assets/images/icon.png', height: 36),
                          const SizedBox(height: 4),
                          Text(
                            'San Jose Water Services\nSajowasa',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.5,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat.yMMMd().format(DateTime.now()),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF718096),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 120,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEDF2F7)),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButton<String>(
                        value: selectedPurok,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedPurok = newValue;
                            });
                          }
                        },
                        items: <String>[
                          'PUROK 1',
                          'PUROK 2',
                          'PUROK 3',
                          'PUROK 4',
                          'PUROK 5',
                          'COMMERCIAL',
                          'NON-RESIDENCE',
                          'INDUSTRIAL'
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: const Color(0xFF2D3748)),
                            ),
                          );
                        }).toList(),
                        underline: const SizedBox(),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF1E88E5), size: 20),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        elevation: 6,
                      ),
                    ),
                  ],
                ),
                _dashedDivider(),
                _receiptRow('NAME', widget.fullName),
                _receiptRow(
                  'METER NUMBER',
                  null,
                  trailing: SizedBox(
                    width: 120,
                    child: _loading
                        ? Text(
                            '...',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF718096),
                            ),
                          )
                        : TextFormField(
                            initialValue: meterNumber,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF2D3748),
                            ),
                            decoration: InputDecoration(
                              hintText: meterNumber.isEmpty
                                  ? 'Enter meter number'
                                  : meterNumber,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFFEDF2F7)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF1E88E5)),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Enter meter number'
                                : null,
                            onChanged: (v) => setState(() => meterNumber = v),
                          ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                _receiptRow(
                  'BILLING PERIOD START',
                  null,
                  trailing: SizedBox(
                    width: 120,
                    child: TextFormField(
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF2D3748),
                      ),
                      decoration: InputDecoration(
                        hintText: periodStart == null
                            ? 'Select Date'
                            : DateFormat('MM-dd-yyyy').format(periodStart!),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFEDF2F7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF1E88E5)),
                        ),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (v) =>
                          periodStart == null ? 'Select a date' : null,
                    ),
                  ),
                ),
                _receiptRow(
                  'BILLING PERIOD DUE DATE',
                  periodDue != null
                      ? DateFormat('MM-dd-yyyy').format(periodDue!)
                      : 'Select Billing Period Start',
                  trailing: const SizedBox(),
                ),
                _dashedDivider(),
                _receiptRow(
                  'PREVIOUS READING',
                  _loading ? 'Loading...' : '${previous.toStringAsFixed(2)} m³',
                ),
                _receiptRow(
                  'CURRENT READING',
                  null,
                  trailing: SizedBox(
                    width: 100,
                    child: TextFormField(
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF2D3748),
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        suffixText: 'm³',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFEDF2F7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF1E88E5)),
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter';
                        final d = double.tryParse(v);
                        if (d == null || d < previous) return 'Invalid';
                        return null;
                      },
                      onChanged: (v) {
                        setState(() => current = double.tryParse(v) ?? 0.0);
                      },
                    ),
                  ),
                ),
                _receiptRow(
                  'CUBIC METER USED',
                  '${cubicMeterUsed.toStringAsFixed(2)} m³',
                  isBold: true,
                ),
                _dashedDivider(),
                _receiptRow(
                  'CURRENT BILL',
                  '₱${currentBill.toStringAsFixed(2)}',
                  valueColor: const Color(0xFF718096),
                  isBold: true,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFFEDF2F7), width: 1),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _rateRow('Residential:',
                              'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                          const SizedBox(width: 8),
                          _rateRow('Commercial:',
                              'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _rateRow('Non Residence:',
                              'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                          const SizedBox(width: 8),
                          _rateRow('Industrial:',
                              'Min 10 m³ = 100.00 PHP\nExceed = 15.00 PHP/m³'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          textStyle: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          foregroundColor: const Color(0xFF1E88E5),
                          side: const BorderSide(color: Color(0xFF1E88E5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _loading
                              ? Colors.grey.shade400
                              : const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          textStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        onPressed: _loading
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    setState(() {
                                      _loading = true;
                                      _error = null;
                                    });
                                    final periodStartDate = periodStart!;
                                    final month = DateFormat('MMM yyyy')
                                        .format(periodStartDate);
                                    final billData = {
                                      'residentId': widget.residentId,
                                      'fullName': widget.fullName,
                                      'address': widget.address,
                                      'contactNumber': widget.contactNumber,
                                      'meterNumber': meterNumber,
                                      'periodStart':
                                          Timestamp.fromDate(periodStartDate),
                                      'periodDue': periodDue != null
                                          ? Timestamp.fromDate(periodDue!)
                                          : FieldValue.serverTimestamp(),
                                      'currentConsumedWaterMeter': current,
                                      'previousConsumedWaterMeter': previous,
                                      'cubicMeterUsed': cubicMeterUsed,
                                      'currentMonthBill': currentBill,
                                      'issueDate': FieldValue.serverTimestamp(),
                                      'purok': selectedPurok,
                                    };
                                    print('Creating bill with data: $billData');
                                    // Save bill to Firestore
                                    final billRef = await FirebaseFirestore
                                        .instance
                                        .collection('users')
                                        .doc(widget.residentId)
                                        .collection('bills')
                                        .add(billData);
                                    // Record transaction history for bill creation
                                    await _recordTransactionHistory(
                                      residentId: widget.residentId,
                                      type: 'Bill',
                                      status: 'created',
                                      amount: currentBill,
                                      description: 'Bill created for $month',
                                      billId: billRef.id,
                                      month: month,
                                    );
                                    // Save meter number to user document
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.residentId)
                                        .set({
                                      'meterNumber': meterNumber,
                                    }, SetOptions(merge: true));
                                    print(
                                        'Saved meter number ${meterNumber} to user document');
                                    // Add to consumption history
                                    await _addConsumptionHistory(
                                      userId: widget.residentId,
                                      periodStart: periodStartDate,
                                      cubicMeterUsed: cubicMeterUsed,
                                    );
                                    // Update meter readings with current as latest
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.residentId)
                                        .collection('meter_readings')
                                        .doc('latest')
                                        .set({
                                      'currentConsumedWaterMeter': current,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                    print(
                                        'Updated meter readings with current: $current');
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Bill created successfully!',
                                              style: GoogleFonts.inter(
                                                  fontSize: 13)),
                                          backgroundColor:
                                              const Color(0xFF1E88E5),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    print('Error creating bill: $e');
                                    if (mounted) {
                                      setState(() {
                                        _error = 'Error creating bill: $e';
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Error creating bill: $e',
                                              style: GoogleFonts.inter(
                                                  fontSize: 13)),
                                          backgroundColor: Colors.redAccent,
                                          duration: const Duration(seconds: 3),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _loading = false;
                                      });
                                    }
                                  }
                                }
                              },
                        child: Text(
                          _loading ? 'Creating...' : 'Create Bill',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.white,
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
  }

  Widget _dashedDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: List.generate(
            30,
            (i) => Expanded(
              child: Container(
                height: 1,
                color: i.isEven ? const Color(0xFFEDF2F7) : Colors.transparent,
              ),
            ),
          ),
        ),
      );

  Widget _receiptRow(String label, String? value,
          {Widget? trailing, Color? valueColor, bool isBold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: GoogleFonts.inter(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                  color: valueColor ?? const Color(0xFF718096),
                ),
              ),
            if (trailing != null) trailing,
          ],
        ),
      );

  Widget _rateRow(String category, String details) => Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                details,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF718096),
                ),
              ),
            ),
          ],
        ),
      );
}
