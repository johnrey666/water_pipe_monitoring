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
  final int _pageSize = 4;
  List<DocumentSnapshot?> _lastDocuments = [null];
  int _totalPages = 1;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _fetchTotalPages() async {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Resident');
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('fullName', isGreaterThanOrEqualTo: _searchQuery)
          .where('fullName', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }
    final snapshot = await query.get();
    final totalDocs = snapshot.docs.length;
    setState(() {
      _totalPages = (totalDocs / _pageSize).ceil();
      while (_lastDocuments.length < _totalPages) {
        _lastDocuments.add(null);
      }
    });
  }

  Stream<QuerySnapshot> _getResidentsStream() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Resident')
        .orderBy('fullName')
        .limit(_pageSize);

    if (_searchQuery.isNotEmpty) {
      query = query
          .where('fullName', isGreaterThanOrEqualTo: _searchQuery)
          .where('fullName', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }

    if (_currentPage > 0 && _lastDocuments[_currentPage - 1] != null) {
      query = query.startAfterDocument(_lastDocuments[_currentPage - 1]!);
    }

    return query.snapshots();
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
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
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
                    borderSide:
                        const BorderSide(color: Color(0xFFEDF2F7), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFFEDF2F7), width: 1),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF718096),
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 14),
                onChanged: (value) {},
              ),
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
                      _buildPaginationButtons(),
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
                    onPressed: () {
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
                      });
                    },
                    child: const Text('Create Bill'),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _PaymentSection(residentId: widget.residentId),
            crossFadeState: _showPayments
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 500),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatefulWidget {
  final String residentId;
  const _PaymentSection({required this.residentId});

  @override
  State<_PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<_PaymentSection> {
  String _selectedMonth = DateFormat('MMM yyyy').format(DateTime.now());

  Future<void> _updatePaymentStatus(BuildContext context, String paymentId,
      String status, String? billId) async {
    print(
        'Updating payment status: paymentId=$paymentId, status=$status, billId=$billId');
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          title: Text(
            'Confirm ${status == 'approved' ? 'Approval' : 'Rejection'}',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF2D3748),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to ${status == 'approved' ? 'approve' : 'reject'} this payment?',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF718096),
            ),
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
                backgroundColor:
                    status == 'approved' ? Colors.green : Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
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
                  String month = _selectedMonth;
                  if (billId != null) {
                    final billDoc = await FirebaseFirestore.instance
                        .collection('bills')
                        .doc(billId)
                        .get();
                    if (billDoc.exists) {
                      final periodStart =
                          (billDoc.data()!['periodStart'] as Timestamp?)
                              ?.toDate();
                      month = periodStart != null
                          ? DateFormat('MMM yyyy').format(periodStart)
                          : 'Unknown';
                      print('Bill found, month: $month');
                    } else {
                      print('Bill not found for billId: $billId');
                    }
                  } else {
                    print('No billId provided, using default month: $month');
                  }

                  final notificationData = {
                    'residentId': widget.residentId,
                    'billId': billId ?? 'Unknown',
                    'status': status,
                    'month': month,
                    'processedDate': FieldValue.serverTimestamp(),
                    'processedBy': 'Admin',
                    'amount': paymentData['billAmount']?.toDouble() ?? 0.0,
                    'read': false, // Added read field
                    'createdAt': FieldValue
                        .serverTimestamp(), // Added createdAt for consistency
                  };
                  print('Saving notification: $notificationData');
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .add(notificationData);
                  print('Notification saved successfully');

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
                    if (billId != null) {
                      await FirebaseFirestore.instance
                          .collection('bills')
                          .doc(billId)
                          .delete();
                      print('Bill deleted: $billId');
                    }
                    setState(() {
                      _selectedMonth =
                          DateFormat('MMM yyyy').format(DateTime.now());
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Payment approved and bill deleted successfully!',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  } else if (status == 'rejected') {
                    await FirebaseFirestore.instance
                        .collection('payments')
                        .doc(paymentId)
                        .delete();
                    print('Payment deleted: $paymentId');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Payment rejected and removed successfully!',
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
                } catch (e) {
                  print('Error updating payment status: $e');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error ${status == 'approved' ? 'approving payment and deleting bill' : 'rejecting payment'}: $e',
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
              },
              child: Text(
                status == 'approved' ? 'Approve' : 'Reject',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error initiating update: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating update: $e',
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildMonthFilter() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('bills')
          .where('residentId', isEqualTo: widget.residentId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final bills = snapshot.data?.docs ?? [];
        final uniqueMonths = bills
            .map((doc) => DateFormat('MMM yyyy')
                .format((doc['periodStart'] as Timestamp).toDate()))
            .toSet()
            .toList()
          ..sort((a, b) {
            final aDate = DateFormat('MMM yyyy').parse(a);
            final bDate = DateFormat('MMM yyyy').parse(b);
            return bDate.compareTo(aDate);
          });

        final dropdownItems = [
          ...uniqueMonths.map((month) => DropdownMenuItem<String>(
                value: month,
                child: Text(
                  month,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF2D3748),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )),
          DropdownMenuItem<String>(
            value: 'Total Bill',
            child: Text(
              'Total Bill',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF2D3748),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ];

        if (uniqueMonths.isEmpty && _selectedMonth != 'Total Bill') {
          dropdownItems.add(DropdownMenuItem<String>(
            value: _selectedMonth,
            child: Text(
              _selectedMonth,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF2D3748),
                fontWeight: FontWeight.w600,
              ),
            ),
          ));
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEDF2F7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButton<String>(
                value: _selectedMonth,
                items: dropdownItems,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMonth = value;
                    });
                  }
                },
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down,
                    color: Color(0xFF1E88E5), size: 16),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 4,
              ),
            ),
          ],
        );
      },
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
          _buildMonthFilter(),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('residentId', isEqualTo: widget.residentId)
                .snapshots(),
            builder: (context, paymentSnapshot) {
              if (paymentSnapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Error loading payments.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.redAccent),
                  ),
                );
              }
              if (paymentSnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                  ),
                );
              }
              final payments = paymentSnapshot.data?.docs ?? [];
              if (payments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'No payments found for this resident.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF718096)),
                  ),
                );
              }

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchPaymentsWithBillDates(payments),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                      ),
                    );
                  }
                  final filteredPayments = snapshot.data ?? [];
                  if (filteredPayments.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No payments for $_selectedMonth.',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF718096)),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredPayments.length,
                    itemBuilder: (context, index) {
                      final payment = filteredPayments[index];
                      final paymentId = payment['paymentId'];
                      final billId = payment['billId'] ?? 'Unknown';
                      final amount =
                          (payment['billAmount'] as num?)?.toDouble() ?? 0.0;
                      final status = payment['status'] ?? 'pending';
                      final billingDate = payment['billingDate'];
                      final receiptImage = payment['receiptImage'] as String?;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFEDF2F7), width: 1),
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
                                            insetPadding:
                                                const EdgeInsets.all(20),
                                            child: Stack(
                                              alignment: Alignment.topRight,
                                              children: [
                                                CachedNetworkImage(
                                                  imageUrl:
                                                      'data:image/jpeg;base64,$receiptImage',
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Color(
                                                                  0xFF1E88E5)),
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
                                                      color: Colors.white,
                                                      size: 24),
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  padding:
                                                      const EdgeInsets.all(8),
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
                                        backgroundColor:
                                            const Color(0xFF81D4FA),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        minimumSize: const Size(60, 36),
                                        textStyle: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: () => _updatePaymentStatus(
                                          context,
                                          paymentId,
                                          'approved',
                                          billId),
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
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        minimumSize: const Size(60, 36),
                                        textStyle: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: () => _updatePaymentStatus(
                                          context,
                                          paymentId,
                                          'rejected',
                                          billId),
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
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPaymentsWithBillDates(
      List<QueryDocumentSnapshot> payments) async {
    final filteredPayments = <Map<String, dynamic>>[];
    final paidBillIds = (await FirebaseFirestore.instance
            .collection('payments')
            .where('residentId', isEqualTo: widget.residentId)
            .where('status', isEqualTo: 'approved')
            .get())
        .docs
        .map((doc) => doc['billId'] as String)
        .toSet();

    final unpaidBillsSnapshot = await FirebaseFirestore.instance
        .collection('bills')
        .where('residentId', isEqualTo: widget.residentId)
        .get();
    final unpaidBillIds = unpaidBillsSnapshot.docs
        .where((doc) => !paidBillIds.contains(doc.id))
        .map((doc) => doc.id)
        .toSet();

    for (var paymentDoc in payments) {
      final payment = paymentDoc.data() as Map<String, dynamic>;
      final billId = payment['billId'] as String?;
      if (_selectedMonth == 'Total Bill') {
        if (billId != null && unpaidBillIds.contains(billId)) {
          final billSnapshot = await FirebaseFirestore.instance
              .collection('bills')
              .doc(billId)
              .get();
          if (billSnapshot.exists) {
            final billData = billSnapshot.data()!;
            final periodStart =
                (billData['periodStart'] as Timestamp?)?.toDate();
            final billingDate = periodStart != null
                ? DateFormat('MMM yyyy').format(periodStart)
                : 'N/A';
            filteredPayments.add({
              ...payment,
              'paymentId': paymentDoc.id,
              'billingDate': billingDate,
            });
          }
        }
      } else {
        if (billId != null) {
          final billSnapshot = await FirebaseFirestore.instance
              .collection('bills')
              .doc(billId)
              .get();
          if (billSnapshot.exists) {
            final billData = billSnapshot.data()!;
            final periodStart =
                (billData['periodStart'] as Timestamp?)?.toDate();
            final billingDate = periodStart != null
                ? DateFormat('MMM yyyy').format(periodStart)
                : 'N/A';
            if (billingDate == _selectedMonth) {
              filteredPayments.add({
                ...payment,
                'paymentId': paymentDoc.id,
                'billingDate': billingDate,
              });
            }
          }
        }
      }
    }

    if (_selectedMonth == 'Total Bill') {
      final totalBillPayment = await _fetchTotalBillPayment(unpaidBillIds);
      if (totalBillPayment != null) {
        filteredPayments.add(totalBillPayment);
      }
    }

    return filteredPayments;
  }

  Future<Map<String, dynamic>?> _fetchTotalBillPayment(
      Set<String> unpaidBillIds) async {
    if (unpaidBillIds.isEmpty) return null;

    final billsSnapshot = await FirebaseFirestore.instance
        .collection('bills')
        .where('residentId', isEqualTo: widget.residentId)
        .where(FieldPath.documentId, whereIn: unpaidBillIds.toList())
        .get();

    final totalAmount = billsSnapshot.docs.fold<double>(
        0.0, (sum, doc) => sum + (doc['currentMonthBill']?.toDouble() ?? 0.0));

    final billingDates = billsSnapshot.docs
        .map((doc) {
          final periodStart = (doc['periodStart'] as Timestamp?)?.toDate();
          return periodStart != null
              ? DateFormat('MMM yyyy').format(periodStart)
              : 'N/A';
        })
        .toSet()
        .join(', ');

    final paymentDocs = await FirebaseFirestore.instance
        .collection('payments')
        .where('residentId', isEqualTo: widget.residentId)
        .where('billId', whereIn: unpaidBillIds.toList())
        .get();

    if (paymentDocs.docs.isNotEmpty) {
      final payment = paymentDocs.docs.first.data();
      return {
        ...payment,
        'paymentId': paymentDocs.docs.first.id,
        'billId': 'Total Bill',
        'billAmount': totalAmount,
        'billingDate': billingDates,
      };
    }

    return null;
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
  String meterNumber = '';
  DateTime? startDate;
  DateTime? endDate;
  String selectedPurok = 'PUROK 1';
  double totalUnpaid = 0.0;

  double get total => previous + current;
  double get currentBill => calculateCurrentBill();
  double get totalBill => totalUnpaid + currentBill;

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          isStartDate ? startDate ?? DateTime.now() : endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  double calculateCurrentBill() {
    double baseRate = getMinimumRate();
    double excess = current - 10 > 0 ? current - 10 : 0;
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
    _loadPreviousBill();
  }

  Future<void> _loadPreviousBill() async {
    try {
      print('Loading previous bills for resident: ${widget.residentId}');
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('residentId', isEqualTo: widget.residentId)
          .get();
      final paidBillIds = await FirebaseFirestore.instance
          .collection('payments')
          .where('residentId', isEqualTo: widget.residentId)
          .where('status', isEqualTo: 'approved')
          .get()
          .then((paymentSnapshot) => paymentSnapshot.docs
              .map((doc) => doc['billId'] as String)
              .toSet());

      print('Found ${snapshot.docs.length} previous bills');

      if (mounted) {
        setState(() {
          previous = snapshot.docs.fold<double>(
              0.0,
              (sum, doc) =>
                  sum + (doc['currentConsumedWaterMeter']?.toDouble() ?? 0.0));
          totalUnpaid = snapshot.docs
              .where((doc) => !paidBillIds.contains(doc.id))
              .fold<double>(
                  0.0,
                  (sum, doc) =>
                      sum + (doc['currentMonthBill']?.toDouble() ?? 0.0));
          print('Setting previous to: $previous, totalUnpaid to: $totalUnpaid');
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading previous bill: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                      width: 100,
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
                    width: 80,
                    child: TextFormField(
                      style: GoogleFonts.inter(
                        color: const Color(0xFF2D3748),
                      ),
                      decoration: InputDecoration(
                        hintText: '1234',
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
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter';
                        return null;
                      },
                      onChanged: (v) {
                        setState(() => meterNumber = v);
                      },
                    ),
                  ),
                ),
                _receiptRow(
                  'PERIOD',
                  null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF2D3748),
                          ),
                          decoration: InputDecoration(
                            hintText: startDate == null
                                ? 'Start'
                                : DateFormat('MM-dd').format(startDate!),
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
                          onTap: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '-',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF1E88E5)),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF2D3748),
                          ),
                          decoration: InputDecoration(
                            hintText: endDate == null
                                ? 'End'
                                : DateFormat('MM-dd').format(endDate!),
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
                          onTap: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
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
                    width: 80,
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
                        if (d == null || d < 0) return 'Invalid';
                        return null;
                      },
                      onChanged: (v) {
                        setState(() => current = double.tryParse(v) ?? 0.0);
                      },
                    ),
                  ),
                ),
                _receiptRow(
                  'TOTAL CUBIC METER USED',
                  '${total.toStringAsFixed(2)} m³',
                  isBold: true,
                ),
                _dashedDivider(),
                _receiptRow(
                  'CURRENT BILL',
                  '₱${currentBill.toStringAsFixed(2)}',
                  valueColor: const Color(0xFF718096),
                  isBold: true,
                ),
                _receiptRow(
                  'TOTAL BILL AMOUNT',
                  '₱${totalBill.toStringAsFixed(2)}',
                  valueColor: const Color(0xFF2D3748),
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
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          textStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final billData = {
                              'residentId': widget.residentId,
                              'fullName': widget.fullName,
                              'address': widget.address,
                              'contactNumber': widget.contactNumber,
                              'meterNumber': meterNumber,
                              'periodStart': startDate,
                              'periodEnd': endDate,
                              'currentConsumedWaterMeter': current,
                              'previousConsumedWaterMeter': previous,
                              'totalConsumed': total,
                              'currentMonthBill': currentBill,
                              'totalBill': totalBill,
                              'issueDate': FieldValue.serverTimestamp(),
                              'purok': selectedPurok,
                            };

                            print('Creating bill with data: $billData');

                            await FirebaseFirestore.instance
                                .collection('bills')
                                .add(billData);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Bill created successfully!',
                                    style: GoogleFonts.inter(fontSize: 13)),
                                backgroundColor: const Color(0xFF1E88E5),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            );
                          }
                        },
                        child: const Text('Create Bill'),
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
