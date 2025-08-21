import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ViewBillingPage extends StatefulWidget {
  const ViewBillingPage({super.key});

  @override
  State<ViewBillingPage> createState() => _ViewBillingPageState();
}

class _ViewBillingPageState extends State<ViewBillingPage> {
  File? _receiptImage;
  List<Map<String, dynamic>> _bills = [];
  int _currentBillIndex = 0;
  bool _loading = true;
  String? _error;
  String _residentId = FirebaseAuth.instance.currentUser!.uid;
  bool _paymentSubmitted = false;
  String? _paymentStatus;
  String? selectedPurok;
  bool _showRates = false;
  String? _selectedBillId;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('residentId', isEqualTo: _residentId)
          .orderBy('issueDate', descending: true)
          .get();

      print('Found ${snapshot.docs.length} bills for resident: $_residentId');

      if (snapshot.docs.isNotEmpty) {
        final bills = snapshot.docs.map((doc) {
          final data = doc.data();
          data['billId'] = doc.id;
          return data;
        }).toList();

        setState(() {
          _bills = bills;
          _currentBillIndex = 0;
          _selectedBillId = bills[0]['billId'];
          selectedPurok = bills[0]['purok'] ?? 'PUROK 1';
          _loading = false;
        });

        await _checkPaymentStatus(_selectedBillId!);
      } else {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_residentId)
            .get();

        if (userSnapshot.exists) {
          setState(() {
            _error = 'No bills found for this resident yet.';
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
      print('Error loading bills: $e');
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
          .get();

      if (paymentSnapshot.docs.isNotEmpty) {
        final payment = paymentSnapshot.docs.first.data();
        setState(() {
          _paymentSubmitted = true;
          _paymentStatus = payment['status'] ?? 'pending';
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
        const SnackBar(
          content: Text('Please select a receipt image first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedBillId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a bill to pay'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
        ),
      );

      final bytes = await _receiptImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final bill = _bills.firstWhere((b) => b['billId'] == _selectedBillId);
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
        const SnackBar(
          content:
              Text('Payment submitted successfully! Awaiting admin approval.'),
          backgroundColor: Color(0xFF4A90E2),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF7FF),
      body: _loading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _bills.isEmpty
                  ? _buildNoBillsState()
                  : RefreshIndicator(
                      onRefresh: _loadBills,
                      color: const Color(0xFF4A90E2),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: _buildBillingContent(),
                      ),
                    ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
      ),
    );
  }

  Widget _buildErrorState() {
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
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Error Loading Bills',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loadBills,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
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
                  Icons.receipt_long,
                  size: 40,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                const Text(
                  'No Bills Found',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You don\'t have any bills yet. Check back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loadBills,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
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

  Widget _buildBillingContent() {
    final bill = _bills[_currentBillIndex];
    final currentConsumed =
        bill['currentConsumedWaterMeter']?.toDouble() ?? 0.0;
    final previousConsumed =
        bill['previousConsumedWaterMeter']?.toDouble() ?? 0.0;
    final totalConsumed = bill['totalConsumed']?.toDouble() ?? 0.0;
    final currentMonthBill = bill['currentMonthBill']?.toDouble() ?? 0.0;
    final periodStart = bill['periodStart'] as Timestamp?;
    final periodEnd = bill['periodEnd'] as Timestamp?;
    final issueDate = bill['issueDate'] as Timestamp?;
    final formattedPeriod = periodStart != null && periodEnd != null
        ? '${DateFormat('MM-dd').format(periodStart.toDate())} - ${DateFormat('MM-dd').format(periodEnd.toDate())}'
        : 'N/A';
    final formattedIssueDate = issueDate != null
        ? DateFormat.yMMMd().format(issueDate.toDate())
        : 'N/A';
    final dueDate = issueDate != null
        ? issueDate.toDate().add(const Duration(days: 7))
        : DateTime.now();
    final formattedDueDate = DateFormat.yMMMd().format(dueDate);
    final isOverdue = DateTime.now().isAfter(dueDate);
    final dueColor = isOverdue ? Colors.red : Colors.black;

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
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFEDF7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
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
                          Image.asset('assets/images/icon.png', height: 36),
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'San Jose Water Services',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A90E2),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          selectedPurok ?? 'PUROK 1',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'WATER BILL STATEMENT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_left,
                                color: _currentBillIndex == 0
                                    ? Colors.grey
                                    : Color(0xFF4A90E2)),
                            onPressed: _currentBillIndex == 0
                                ? null
                                : () async {
                                    setState(() {
                                      _currentBillIndex--;
                                      _selectedBillId =
                                          _bills[_currentBillIndex]['billId'];
                                    });
                                    await _checkPaymentStatus(_selectedBillId!);
                                  },
                          ),
                          Text(
                            '${_currentBillIndex + 1} of ${_bills.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.arrow_right,
                                color: _currentBillIndex == _bills.length - 1
                                    ? Colors.grey
                                    : Color(0xFF4A90E2)),
                            onPressed: _currentBillIndex == _bills.length - 1
                                ? null
                                : () async {
                                    setState(() {
                                      _currentBillIndex++;
                                      _selectedBillId =
                                          _bills[_currentBillIndex]['billId'];
                                    });
                                    await _checkPaymentStatus(_selectedBillId!);
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _dashedDivider(),
                  _receiptRow('Name', bill['fullName'] ?? 'N/A'),
                  _receiptRow('Address', bill['address'] ?? 'N/A'),
                  _receiptRow('Contact', bill['contactNumber'] ?? 'N/A'),
                  _receiptRow('Meter No.', bill['meterNumber'] ?? 'N/A'),
                  _receiptRow('Period', formattedPeriod),
                  _receiptRow('Issue Date', formattedIssueDate),
                  _dashedDivider(),
                  _receiptRow('Previous Reading',
                      '${previousConsumed.toStringAsFixed(2)} m³'),
                  _receiptRow('Current Reading',
                      '${currentConsumed.toStringAsFixed(2)} m³'),
                  _receiptRow('Total Consumed',
                      '${totalConsumed.toStringAsFixed(2)} m³',
                      isBold: true),
                  _dashedDivider(),
                  _receiptRow(
                      'Current Bill', '₱${currentMonthBill.toStringAsFixed(2)}',
                      valueColor: Colors.red, isBold: true, fontSize: 13),
                  FutureBuilder<Set<String>>(
                    future: FirebaseFirestore.instance
                        .collection('payments')
                        .where('residentId', isEqualTo: _residentId)
                        .where('status', isEqualTo: 'approved')
                        .get()
                        .then((snapshot) => snapshot.docs
                            .map((doc) => doc['billId'] as String)
                            .toSet()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _receiptRow('Total Amount Due', 'Loading...',
                            valueColor: const Color(0xFF4A90E2), isBold: true);
                      }
                      if (snapshot.hasError) {
                        return _receiptRow('Total Amount Due', 'Error',
                            valueColor: const Color(0xFF4A90E2), isBold: true);
                      }
                      final paidBillIds = snapshot.data ?? <String>{};
                      final totalAmountDue = _bills
                          .where(
                              (bill) => !paidBillIds.contains(bill['billId']))
                          .fold<double>(
                              0.0,
                              (sum, bill) =>
                                  sum +
                                  (bill['currentMonthBill']?.toDouble() ??
                                      0.0));
                      return _receiptRow('Total Amount Due',
                          '₱${totalAmountDue.toStringAsFixed(2)}',
                          valueColor: const Color(0xFF4A90E2), isBold: true);
                    },
                  ),
                  _receiptRow('Due Date', formattedDueDate,
                      valueColor: dueColor),
                  if (isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: Colors.red, size: 14),
                          const SizedBox(width: 4),
                          const Text(
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
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _showRates = !_showRates),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Rate Information',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A90E2),
                            ),
                          ),
                          Icon(
                            _showRates ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: const Color(0xFF4A90E2),
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
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.05),
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
                  const Text(
                    'Ensure timely payment to maintain uninterrupted water supply.',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey,
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
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAYMENT OPTIONS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('payments')
                        .where('residentId', isEqualTo: _residentId)
                        .get(),
                    builder: (context, snapshot) {
                      final paidBillIds = snapshot.hasData
                          ? snapshot.data!.docs
                              .where((doc) => doc['status'] == 'approved')
                              .map((doc) => doc['billId'] as String)
                              .toSet()
                          : <String>{};

                      final unpaidBills = _bills
                          .asMap()
                          .entries
                          .where((entry) =>
                              !paidBillIds.contains(entry.value['billId']))
                          .map((entry) {
                        final bill = entry.value;
                        final periodStart =
                            (bill['periodStart'] as Timestamp?)?.toDate();
                        final formattedPeriod = periodStart != null
                            ? DateFormat('MMM yyyy').format(periodStart)
                            : 'N/A';
                        return {
                          'billId': bill['billId'],
                          'period': formattedPeriod,
                        };
                      }).toList()
                        ..sort((a, b) {
                          final aDate = _bills.firstWhere((b) =>
                                  b['billId'] == a['billId'])['periodStart']
                              as Timestamp?;
                          final bDate = _bills.firstWhere((b) =>
                                  b['billId'] == b['billId'])['periodStart']
                              as Timestamp?;
                          return bDate?.compareTo(aDate ?? Timestamp.now()) ??
                              0;
                        });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unpaidBills.isNotEmpty)
                            DropdownButton<String>(
                              value: _selectedBillId,
                              items: unpaidBills.map((bill) {
                                return DropdownMenuItem<String>(
                                  value: bill['billId'],
                                  child: Text(
                                    bill['period'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                if (value != null) {
                                  setState(() {
                                    _selectedBillId = value;
                                    _currentBillIndex = _bills.indexWhere(
                                        (b) => b['billId'] == value);
                                  });
                                  await _checkPaymentStatus(value);
                                }
                              },
                              isExpanded: true,
                              hint: const Text('Select a bill to pay'),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              elevation: 4,
                            ),
                          if (unpaidBills.isEmpty)
                            const Text(
                              'No unpaid bills available',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (_paymentSubmitted) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_paymentStatus!)
                                    .withOpacity(0.1),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getStatusText(_paymentStatus!),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(
                                                _paymentStatus!),
                                          ),
                                        ),
                                        Text(
                                          _getStatusDescription(
                                              _paymentStatus!),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (!_paymentSubmitted && unpaidBills.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.phone_android,
                                        color: Colors.green, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'GCash Payment',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '09853886411',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.content_copy,
                                        color: Color(0xFF4A90E2), size: 16),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('GCash number copied!'),
                                          duration: Duration(seconds: 2),
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
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: const Text('Select Receipt',
                                    style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A90E2),
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
                                onPressed: () =>
                                    setState(() => _receiptImage = null),
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 14),
                                label: const Text(
                                  'Remove',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 10),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedScale(
                                scale: 1.0,
                                duration: const Duration(milliseconds: 250),
                                child: ElevatedButton.icon(
                                  onPressed: _uploadReceipt,
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Submit Payment',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
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
                      );
                    },
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
                color: i.isEven ? Colors.grey[200] : Colors.transparent,
              ),
            ),
          ),
        ),
      );

  Widget _receiptRow(String label, String value,
          {Color? valueColor, bool isBold = false, double fontSize = 11}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Colors.black,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: fontSize,
                color: valueColor ?? Colors.grey[700],
              ),
            ),
          ],
        ),
      );

  Widget _rateRow(String category, String details) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              details,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      );

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
