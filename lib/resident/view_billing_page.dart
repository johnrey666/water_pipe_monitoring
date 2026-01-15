import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewBillingPage extends StatefulWidget {
  const ViewBillingPage({super.key});

  @override
  State<ViewBillingPage> createState() => _ViewBillingPageState();
}

class _ViewBillingPageState extends State<ViewBillingPage> {
  File? _receiptImage;
  Map<String, dynamic>? _currentBill;
  bool _loading = true;
  String? _error;
  String _residentId = FirebaseAuth.instance.currentUser!.uid;
  bool _paymentSubmitted = false;
  String? _paymentStatus;
  String? selectedPurok;
  bool _showRates = false;
  String? _selectedBillId;
  bool _hasNoBill = false;
  double? _previousReading;
  Map<String, dynamic>? _userData;

  // UPDATED COLORS TO MATCH HOMEPAGE
  final Color primaryColor = const Color(0xFF00BCD4); // Aqua Blue
  final Color accentColor = const Color(0xFF4DD0E1); // Lighter Aqua Blue
  final Color backgroundColor =
      const Color(0xFFE0F7FA); // Light aqua background
  final Color darkAqua = const Color(0xFF00838F); // Dark aqua for text

  // Report feature variables
  TextEditingController _reportReasonController = TextEditingController();
  bool _submittingReport = false;
  String _recordedByName = '';

  @override
  void initState() {
    super.initState();
    _loadLatestBill();
  }

  @override
  void dispose() {
    _reportReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestBill() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final paidBillIds = await FirebaseFirestore.instance
          .collection('payments')
          .where('residentId', isEqualTo: _residentId)
          .where('status', isEqualTo: 'approved')
          .get()
          .then((snapshot) =>
              snapshot.docs.map((doc) => doc['billId'] as String).toSet());

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_residentId)
          .collection('bills')
          .where(FieldPath.documentId,
              whereNotIn: paidBillIds.isEmpty ? null : paidBillIds.toList())
          .orderBy('periodStart', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final bill = snapshot.docs.first.data();
        bill['billId'] = snapshot.docs.first.id;

        setState(() {
          _currentBill = bill;
          _selectedBillId = bill['billId'];
          selectedPurok = bill['purok'] ?? 'PUROK 1';
          _recordedByName = bill['recordedByName'] ?? 'Meter Reader';
          _hasNoBill = false;
          _loading = false;
        });

        await _checkPaymentStatus(_selectedBillId!);
      } else {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_residentId)
            .get();

        if (userSnapshot.exists) {
          _userData = userSnapshot.data()!;
          // Fetch previous reading
          final meterSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(_residentId)
              .collection('meter_readings')
              .doc('latest')
              .get();

          if (meterSnapshot.exists) {
            _previousReading = meterSnapshot
                    .data()!['currentConsumedWaterMeter']
                    ?.toDouble() ??
                0.0;
          } else {
            _previousReading = 0.0;
          }

          setState(() {
            _hasNoBill = true;
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Resident not found. Please check your account.';
            _loading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading bill: $e');
      setState(() {
        _error = 'Error loading bill data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _checkPaymentStatus(String billId) async {
    try {
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('residentId', isEqualTo: _residentId)
          .where('billId', isEqualTo: billId)
          .orderBy('submissionDate', descending: true)
          .limit(1)
          .get();

      if (paymentSnapshot.docs.isNotEmpty) {
        final payment = paymentSnapshot.docs.first.data();
        final status = payment['status'] ?? 'pending';

        setState(() {
          _paymentSubmitted = true;
          _paymentStatus = status;

          if (status == 'rejected') {
            _paymentSubmitted = false;
            _paymentStatus = 'rejected';
          }
        });
      } else {
        setState(() {
          _paymentSubmitted = false;
          _paymentStatus = null;
        });
      }
    } catch (e) {
      print('Error checking payment status: $e');
    }
  }

  Future<void> _pickReceiptImage() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _receiptImage = File(pickedImage.path);
      });
    }
  }

  Future<void> _uploadReceipt() async {
    if (_receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a receipt image first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedBillId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No bill selected for payment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );

      final bytes = await _receiptImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final bill = _currentBill!;
      final paymentData = {
        'residentId': _residentId,
        'billId': _selectedBillId,
        'residentName': bill['fullName'],
        'residentAddress': bill['address'],
        'billAmount': bill['currentMonthBill']?.toDouble() ?? 0.0,
        'receiptImage': base64Image,
        'paymentMethod': 'GCash',
        'gcashNumber': '09853886411',
        'submissionDate': FieldValue.serverTimestamp(),
        'status': 'pending',
        'adminNotes': '',
        'processedBy': '',
        'processedDate': null,
      };
      await FirebaseFirestore.instance.collection('payments').add(paymentData);

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Payment submitted successfully! Awaiting admin approval.'),
          backgroundColor: primaryColor,
        ),
      );

      setState(() {
        _receiptImage = null;
        _paymentSubmitted = true;
        _paymentStatus = 'pending';
      });

      await _checkPaymentStatus(_selectedBillId!);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReportBillDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Report Bill Issue',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: darkAqua,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please describe the issue with your bill:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reportReasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Example: Incorrect reading, wrong calculation, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFB2EBF2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor),
                ),
                filled: true,
                fillColor: Color(0xFFE0F7FA),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe the issue';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _submittingReport
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Submit Report',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    final String reason = _reportReasonController.text.trim();

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please describe the issue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedBillId == null || _currentBill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No bill selected to report'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _submittingReport = true);

      final reportData = {
        'billId': _selectedBillId,
        'residentId': _residentId,
        'residentName': _currentBill!['fullName'],
        'residentAddress': _currentBill!['address'],
        'billAmount': _currentBill!['currentMonthBill']?.toDouble() ?? 0.0,
        'reportReason': reason,
        'submittedAt': Timestamp.now(),
        'status': 'pending',
        'reviewedBy': '',
        'reviewedAt': null,
        'adminNotes': '',
        'recordedByName': _recordedByName,
        'periodStart': _currentBill!['periodStart'],
        'periodDue': _currentBill!['periodDue'],
      };

      await FirebaseFirestore.instance
          .collection('bill_reports')
          .add(reportData);

      setState(() => _submittingReport = false);
      if (mounted) Navigator.of(context).pop();

      if (mounted) _reportReasonController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report submitted successfully! Admin will review it.'),
          backgroundColor: Color(0xFF00BCD4),
        ),
      );
    } catch (e) {
      print('Error submitting report: $e');
      setState(() => _submittingReport = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _loading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _hasNoBill
                  ? RefreshIndicator(
                      onRefresh: _loadLatestBill,
                      color: primaryColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: _buildNoBillTemplate(),
                      ),
                    )
                  : _currentBill == null
                      ? _buildNoBillsState()
                      : RefreshIndicator(
                          onRefresh: _loadLatestBill,
                          color: primaryColor,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: _buildBillingContent(),
                          ),
                        ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _error == 'No existing bill. Your account is up to date!'
                    ? Icons.check_circle
                    : Icons.error_outline,
                size: 40,
                color: _error == 'No existing bill. Your account is up to date!'
                    ? Color(0xFF00BCD4)
                    : Colors.red[400],
              ),
              const SizedBox(height: 8),
              Text(
                _error == 'No existing bill. Your account is up to date!'
                    ? 'No Existing Bill'
                    : 'Error Loading Bill',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: darkAqua,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadLatestBill,
                icon: Icon(Icons.refresh, size: 16, color: Colors.white),
                label: Text('Refresh',
                    style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildNoBillsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 40,
                  color: primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'No Existing Bill',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkAqua,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your account is up to date! No unpaid bills found.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loadLatestBill,
                  icon: Icon(Icons.refresh, size: 16, color: Colors.white),
                  label: Text('Refresh',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoBillTemplate() {
    final previousReadingValue = _previousReading ?? 0.0;
    final dummyBill = {
      'fullName': _userData?['fullName'] ?? 'N/A',
      'address': _userData?['address'] ?? 'N/A',
      'contactNumber': _userData?['contactNumber'] ?? 'N/A',
      'meterNumber': _userData?['meterNumber'] ?? 'N/A',
      'purok': _userData?['purok'] ?? 'PUROK 1',
      'previousConsumedWaterMeter': previousReadingValue,
      'currentConsumedWaterMeter': 0.0,
      'cubicMeterUsed': 0.0,
      'currentMonthBill': 0.0,
      'periodStart': null,
      'periodDue': null,
      'issueDate': null,
    };
    selectedPurok = dummyBill['purok'];

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'You Currently Don\'t Have a BILL!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Card(
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Color(0xFFE0F7FA),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Color(0xFFB2EBF2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              'assets/images/icon.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.water_drop,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'San Jose Water Services',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: darkAqua,
                                ),
                              ),
                              Text(
                                'Sajowasa',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: accentColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          selectedPurok ?? 'PUROK 1',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'WATER BILL STATEMENT',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _dashedDivider(),
                  _receiptRow('Name', dummyBill['fullName']),
                  _receiptRow('Address', dummyBill['address']),
                  _receiptRow('Contact', dummyBill['contactNumber']),
                  _receiptRow('Meter No.', dummyBill['meterNumber']),
                  _receiptRow('Billing Period Start', 'N/A'),
                  _receiptRow('Billing Period Due', 'N/A'),
                  _receiptRow('Issue Date', 'N/A'),
                  _dashedDivider(),
                  _receiptRow('Previous Reading',
                      '${previousReadingValue.toStringAsFixed(2)} m³'),
                  _receiptRow('Current Reading', '0.00 m³'),
                  _receiptRow('Cubic Meter Used', '0.00 m³', isBold: true),
                  _dashedDivider(),
                  _receiptRow('Current Bill', '₱0.00',
                      valueColor: accentColor, isBold: true, fontSize: 13),
                  _receiptRow('Due Date', 'N/A', valueColor: accentColor),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _showRates = !_showRates),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFFB2EBF2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rate Information',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: darkAqua,
                            ),
                          ),
                          Icon(
                            _showRates ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: darkAqua,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFE0F7FA), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _rateRow('Residential',
                              'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                          const SizedBox(height: 6),
                          _rateRow('Commercial',
                              'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                          const SizedBox(height: 6),
                          _rateRow('Non Residence',
                              'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                          const SizedBox(height: 6),
                          _rateRow('Industrial',
                              'Min 10 m³ = 100.00 PHP\nExceed = 15.00 PHP/m³'),
                        ],
                      ),
                    ),
                    crossFadeState: _showRates
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 400),
                    sizeCurve: Curves.easeInOut,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ensure timely payment to maintain uninterrupted water supply.',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: accentColor,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.5,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: Color(0xFFE0F7FA),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAYMENT OPTIONS',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.phone_android,
                                color: primaryColor, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GCash Payment',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: accentColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '09853886411',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: darkAqua,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.content_copy,
                                color: primaryColor, size: 16),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('GCash number copied!'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: primaryColor,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No bill to pay at the moment. Check back later!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: accentColor,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingContent() {
    final bill = _currentBill!;
    final currentConsumed =
        bill['currentConsumedWaterMeter']?.toDouble() ?? 0.0;
    final previousConsumed =
        bill['previousConsumedWaterMeter']?.toDouble() ?? 0.0;
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
        ? DateFormat.yMMMd().format(issueDate.toDate())
        : 'N/A';
    final isOverdue =
        periodDue != null && DateTime.now().isAfter(periodDue.toDate());
    final dueColor = isOverdue ? Colors.red : darkAqua;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          Card(
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFE0F7FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Color(0xFFE0F7FA),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              'assets/images/icon.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.water_drop,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'San Jose Water Services',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: darkAqua,
                                ),
                              ),
                              Text(
                                'Sajowasa',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: accentColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          selectedPurok ?? 'PUROK 1',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'WATER BILL STATEMENT',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _dashedDivider(),
                  _receiptRow('Name', bill['fullName'] ?? 'N/A'),
                  _receiptRow('Address', bill['address'] ?? 'N/A'),
                  _receiptRow('Contact', bill['contactNumber'] ?? 'N/A'),
                  _receiptRow('Meter No.', bill['meterNumber'] ?? 'N/A'),
                  _receiptRow('Recorded By', _recordedByName),
                  _receiptRow('Billing Period Start', formattedPeriodStart),
                  _receiptRow('Billing Period Due', formattedPeriodDue),
                  _receiptRow('Issue Date', formattedIssueDate),
                  _dashedDivider(),
                  _receiptRow('Previous Reading',
                      '${previousConsumed.toStringAsFixed(2)} m³'),
                  _receiptRow('Current Reading',
                      '${currentConsumed.toStringAsFixed(2)} m³'),
                  _receiptRow('Cubic Meter Used',
                      '${cubicMeterUsed.toStringAsFixed(2)} m³',
                      isBold: true),
                  _dashedDivider(),
                  _receiptRow(
                      'Current Bill', '₱${currentMonthBill.toStringAsFixed(2)}',
                      valueColor: Colors.red, isBold: true, fontSize: 13),
                  _receiptRow('Due Date', formattedPeriodDue,
                      valueColor: dueColor),
                  if (isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.red, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Overdue: Pay immediately to avoid penalties.',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _showRates = !_showRates),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFFB2EBF2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rate Information',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: darkAqua,
                            ),
                          ),
                          Icon(
                            _showRates ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: darkAqua,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFE0F7FA), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _rateRow('Residential',
                              'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                          const SizedBox(height: 6),
                          _rateRow('Commercial',
                              'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                          const SizedBox(height: 6),
                          _rateRow('Non Residence',
                              'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                          const SizedBox(height: 6),
                          _rateRow('Industrial',
                              'Min 10 m³ = 100.00 PHP\nExceed = 15.00 PHP/m³'),
                        ],
                      ),
                    ),
                    crossFadeState: _showRates
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 400),
                    sizeCurve: Curves.easeInOut,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ensure timely payment to maintain uninterrupted water supply.',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: accentColor,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Color(0xFFE0F7FA),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYMENT OPTIONS',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_paymentStatus != null &&
                      _paymentStatus != 'rejected') ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            _getStatusColor(_paymentStatus!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _getStatusColor(_paymentStatus!)
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(_paymentStatus!),
                            color: _getStatusColor(_paymentStatus!),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getStatusText(_paymentStatus!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(_paymentStatus!),
                                  ),
                                ),
                                Text(
                                  _getStatusDescription(_paymentStatus!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_paymentStatus == 'rejected') ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Payment Rejected',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please check the notification for details and resubmit your payment.',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Please upload a new receipt below.'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: primaryColor,
                                ),
                              );
                            },
                            icon: Icon(Icons.info_outline,
                                size: 14, color: Colors.red),
                            label: Text(
                              'View notification for details',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!_paymentSubmitted || _paymentStatus == 'rejected') ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.phone_android,
                                color: primaryColor, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GCash Payment',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: accentColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '09853886411',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: darkAqua,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.content_copy,
                                color: primaryColor, size: 16),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('GCash number copied!'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: primaryColor,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedScale(
                      scale: _receiptImage == null ? 1.0 : 0.98,
                      duration: const Duration(milliseconds: 250),
                      child: ElevatedButton.icon(
                        onPressed: _pickReceiptImage,
                        icon: Icon(Icons.upload_file,
                            size: 16, color: Colors.white),
                        label: Text('Select Receipt',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          elevation: 2,
                        ),
                      ),
                    ),
                    if (_receiptImage != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _receiptImage!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _receiptImage = null),
                        icon: Icon(Icons.delete, color: Colors.red, size: 14),
                        label: Text(
                          'Remove',
                          style: GoogleFonts.poppins(
                              color: Colors.red, fontSize: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedScale(
                        scale: 1.0,
                        duration: const Duration(milliseconds: 250),
                        child: ElevatedButton.icon(
                          onPressed: _uploadReceipt,
                          icon: Icon(Icons.send, size: 16, color: Colors.white),
                          label: Text('Submit Payment',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Color(0xFFE0F7FA),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REPORT ISSUE',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Found an issue with your bill?',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showReportBillDialog,
                    icon: Icon(Icons.report_problem,
                        size: 16, color: Colors.orange.shade700),
                    label: Text('Report Bill Issue',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.orange.shade700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Report for issues like: incorrect readings, wrong calculations, etc.',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: accentColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
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
                color: i.isEven ? Color(0xFFE0F7FA) : Colors.transparent,
              ),
            ),
          ),
        ),
      );

  Widget _receiptRow(String label, String value,
      {Color? valueColor, bool isBold = false, double fontSize = 11}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: darkAqua,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  fontSize: fontSize,
                  color: valueColor ?? accentColor,
                ),
                textAlign: TextAlign.right,
                overflow: label == 'Address' ? TextOverflow.ellipsis : null,
                maxLines: label == 'Address' ? 2 : null,
              ),
            ),
          ],
        ));
  }

  Widget _rateRow(String category, String details) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 10,
              color: darkAqua,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              details,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: accentColor,
              ),
            ),
          ),
        ],
      );

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return primaryColor;
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
        return 'Payment Approved';
      case 'rejected':
        return 'Payment Rejected';
      default:
        return 'Payment Pending';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'approved':
        return 'Your payment has been confirmed.';
      case 'rejected':
        return 'Please contact admin for details.';
      default:
        return 'Awaiting admin review.';
    }
  }
}
