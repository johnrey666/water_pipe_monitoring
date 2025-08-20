import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../components/admin_layout.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Bills',
      selectedRoute: '/bills',
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'Resident')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading residents: ${snapshot.error}',
                  style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C3E50)),
                ),
              );
            }
            final residents = snapshot.data?.docs ?? [];
            if (residents.isEmpty) {
              return const Center(
                child: Text(
                  'No residents found.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: residents.length,
              itemBuilder: (context, index) {
                final resident = residents[index];
                final data = resident.data() as Map<String, dynamic>? ?? {};
                final fullName = data['fullName'] ?? 'Unknown Resident';
                final address = data['address'] ?? 'No address';
                final contactNumber = data['contactNumber'] ?? 'No contact';
                return _ResidentCard(
                  residentId: resident.id,
                  fullName: fullName,
                  address: address,
                  contactNumber: contactNumber,
                );
              },
            );
          },
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2C3E50).withOpacity(0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            title: Text(
              widget.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF2C3E50),
              ),
            ),
            subtitle: Text(
              '${widget.address}\n${widget.contactNumber}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _showPayments ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF2C3E50),
                    size: 22,
                  ),
                  onPressed: () =>
                      setState(() => _showPayments = !_showPayments),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
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
                    );
                  },
                  child: const Text('Create Bill'),
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
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  final String residentId;
  const _PaymentSection({required this.residentId});

  Future<void> _updatePaymentStatus(
      BuildContext context, String paymentId, String status) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Confirm ${status == 'approved' ? 'Approval' : 'Rejection'}',
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50)),
          ),
          content: Text(
            'Are you sure you want to ${status == 'approved' ? 'approve' : 'reject'} this payment?',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 12, color: Color(0xFF2C3E50))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    status == 'approved' ? Colors.green : Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('payments')
                    .doc(paymentId)
                    .update({
                  'status': status,
                  'processedDate': FieldValue.serverTimestamp(),
                  'processedBy':
                      'Admin', // Replace with actual admin ID if available
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Payment ${status == 'approved' ? 'approved' : 'rejected'} successfully!'),
                    backgroundColor:
                        status == 'approved' ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                status == 'approved' ? 'Approve' : 'Reject',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating payment: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .where('residentId', isEqualTo: residentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(6.0),
              child: Text(
                'Error loading payments.',
                style: TextStyle(fontSize: 10, color: Colors.redAccent),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(6.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C3E50)),
              ),
            );
          }
          final payments = snapshot.data?.docs ?? [];
          if (payments.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(6.0),
              child: Text(
                'No payments found for this resident.',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final paymentDoc = payments[index];
              final payment = paymentDoc.data() as Map<String, dynamic>;
              final paymentId = paymentDoc.id;
              final billId = payment['billId'] ?? 'Unknown';
              final amount = (payment['billAmount'] as num?)?.toDouble() ?? 0.0;
              final status = payment['status'] ?? 'pending';
              final submissionDate =
                  (payment['submissionDate'] as Timestamp?)?.toDate();
              final receiptImage = payment['receiptImage'] as String?;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bill ID: $billId',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          Text(
                            'Amount: ₱${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            'Status: ${_getStatusText(status)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (submissionDate != null)
                            Text(
                              'Submitted: ${DateFormat.yMMMd().format(submissionDate)}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (receiptImage != null)
                          TextButton(
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
                                                AlwaysStoppedAnimation<Color>(
                                                    Color(0xFF2C3E50)),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.error,
                                                color: Colors.red, size: 30),
                                        width: double.infinity,
                                        height: 250,
                                        fit: BoxFit.contain,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.white, size: 24),
                                        onPressed: () => Navigator.pop(context),
                                        padding: const EdgeInsets.all(8),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 10),
                            ),
                            child: const Text('View Receipt'),
                          ),
                        if (status == 'pending') ...[
                          const SizedBox(width: 6),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[300],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              minimumSize: const Size(60, 30),
                              textStyle: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _updatePaymentStatus(
                                context, paymentId, 'approved'),
                            child: const Text('Accept'),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              minimumSize: const Size(60, 30),
                              textStyle: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _updatePaymentStatus(
                                context, paymentId, 'rejected'),
                            child: const Text('Reject'),
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
  String meterNumber = '';
  DateTime? startDate;
  DateTime? endDate;
  String selectedPurok = 'PUROK 1';

  double get total => previous + current;
  double get totalBill => calculateTotalBill();
  double get currentBill => (current / 10) * getRatePerCubicMeter();

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
        if (isStartDate)
          startDate = picked;
        else
          endDate = picked;
      });
    }
  }

  double calculateTotalBill() {
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
        return 30.00; // Residential
      case 'COMMERCIAL':
        return 75.00; // Commercial
      case 'NON-RESIDENCE':
        return 100.00; // Non-residence
      case 'INDUSTRIAL':
        return 100.00; // Industrial
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
        return 5.00; // Residential
      case 'COMMERCIAL':
        return 10.00; // Commercial
      case 'NON-RESIDENCE':
        return 10.00; // Non-residence
      case 'INDUSTRIAL':
        return 15.00; // Industrial
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
      print('Loading previous bill for resident: ${widget.residentId}');
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('residentId', isEqualTo: widget.residentId)
          .get();

      print('Found ${snapshot.docs.length} previous bills');

      if (mounted) {
        setState(() {
          if (snapshot.docs.isNotEmpty) {
            final sortedDocs = snapshot.docs.toList()
              ..sort((a, b) {
                final aDate = a.data()['issueDate'] as Timestamp?;
                final bDate = b.data()['issueDate'] as Timestamp?;
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return bDate.compareTo(aDate);
              });

            final billData = sortedDocs.first.data() as Map<String, dynamic>;
            print('Latest bill data: $billData');
            previous = billData['currentConsumedWaterMeter']?.toDouble() ?? 0.0;
            print('Setting previous to: $previous');
          } else {
            print('No previous bills found, setting previous to 0');
            previous = 0.0;
          }
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF8FAFF)],
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
                          const Text(
                            'San Jose Water Services\nSajowasa',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat.yMMMd().format(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.05),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
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
                            child: Text(value,
                                style: const TextStyle(fontSize: 9)),
                          );
                        }).toList(),
                        underline: const SizedBox(),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF2C3E50), size: 14),
                        dropdownColor: Colors.white,
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
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
                      decoration: InputDecoration(
                        hintText: '1234',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFF2C3E50)),
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
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11),
                          decoration: InputDecoration(
                            hintText: startDate == null
                                ? 'Start'
                                : DateFormat('MM-dd').format(startDate!),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Color(0xFF2C3E50)),
                            ),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('-',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF2C3E50))),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11),
                          decoration: InputDecoration(
                            hintText: endDate == null
                                ? 'End'
                                : DateFormat('MM-dd').format(endDate!),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Color(0xFF2C3E50)),
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
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        suffixText: 'm³',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFF2C3E50)),
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
                    'TOTAL CUBIC METER USED', '${total.toStringAsFixed(2)} m³',
                    isBold: true),
                _dashedDivider(),
                _receiptRow(
                    'CURRENT BILL', '₱${currentBill.toStringAsFixed(2)}',
                    valueColor: Colors.grey),
                _receiptRow(
                    'TOTAL BILL AMOUNT', '₱${totalBill.toStringAsFixed(2)}',
                    valueColor: const Color(0xFF2C3E50), isBold: true),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey[50],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _rateRow('Residential:',
                              'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                          const SizedBox(width: 6),
                          _rateRow('Commercial:',
                              'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _rateRow('Non Residence:',
                              'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                          const SizedBox(width: 6),
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
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                        foregroundColor: const Color(0xFF2C3E50),
                        side: const BorderSide(color: Color(0xFF2C3E50)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
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
                            'totalBill': totalBill,
                            'currentMonthBill': currentBill,
                            'issueDate': FieldValue.serverTimestamp(),
                            'purok': selectedPurok,
                          };

                          print('Creating bill with data: $billData');

                          await FirebaseFirestore.instance
                              .collection('bills')
                              .add(billData);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bill created successfully!'),
                              backgroundColor: Color(0xFF2C3E50),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: const Text('Create Bill'),
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

  Widget _receiptRow(String label, String? value,
          {Widget? trailing, Color? valueColor, bool isBold = false}) =>
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
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  fontSize: 11,
                  color: valueColor ?? Colors.grey[700],
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(width: 3),
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
        ),
      );
}
