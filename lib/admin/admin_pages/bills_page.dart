import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../components/admin_layout.dart';

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Bills',
      selectedRoute: '/bills',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final residents = snapshot.data?.docs ?? [];
            if (residents.isEmpty) {
              return const Center(
                child: Text(
                  'No residents found.',
                  style: TextStyle(
                    fontSize: 18,
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
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: const CircleAvatar(
                      child: Icon(Icons.person, color: Colors.white),
                      backgroundColor: Colors.blue,
                    ),
                    title: Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      '$address\n$contactNumber',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A2C6F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                      onPressed: () {
                        _showBillForm(context, resident.id, fullName, address,
                            contactNumber);
                      },
                      child: const Text(
                        'Create Bill',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showBillForm(BuildContext context, String residentId, String fullName,
      String address, String contactNumber) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(0),
        child: _BillReceiptForm(
          residentId: residentId,
          fullName: fullName,
          address: address,
          contactNumber: contactNumber,
        ),
      ),
    );
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
      case 'NON-RESIDENCE':
        return 100.00; // Non-residence
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
      case 'NON-RESIDENCE':
        return 10.00; // Non-residence
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
                return bDate.compareTo(aDate); // Descending order
              });

            final billData = sortedDocs.first.data() as Map<String, dynamic>;
            print('Latest bill data: $billData');
            previous = billData['currentConsumedWaterMeter'] ?? 0.0;
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
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 400),
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Purok Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset('images/icon.png',
                            height: 32), // Replace icon with image
                        const SizedBox(height: 4),
                        Text('NOTICE OF BILLING',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.2,
                              color: Color(0xFF4A2C6F),
                            )),
                        const SizedBox(height: 2),
                        Text(DateFormat.yMMMd().format(DateTime.now()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontFamily: 'monospace',
                            )),
                      ],
                    ),
                  ),
                  // Purok Selection (Top right, smaller)
                  Container(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Purok:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        CheckboxListTile(
                          title:
                              const Text('P1', style: TextStyle(fontSize: 10)),
                          value: selectedPurok == 'PUROK 1',
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() => selectedPurok = 'PUROK 1');
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        CheckboxListTile(
                          title:
                              const Text('P2', style: TextStyle(fontSize: 10)),
                          value: selectedPurok == 'PUROK 2',
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() => selectedPurok = 'PUROK 2');
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        CheckboxListTile(
                          title:
                              const Text('P3', style: TextStyle(fontSize: 10)),
                          value: selectedPurok == 'PUROK 3',
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() => selectedPurok = 'PUROK 3');
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        CheckboxListTile(
                          title:
                              const Text('P4', style: TextStyle(fontSize: 10)),
                          value: selectedPurok == 'PUROK 4',
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() => selectedPurok = 'PUROK 4');
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        CheckboxListTile(
                          title:
                              const Text('P5', style: TextStyle(fontSize: 10)),
                          value: selectedPurok == 'PUROK 5',
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() => selectedPurok = 'PUROK 5');
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        CheckboxListTile(
                          title:
                              const Text('NR', style: TextStyle(fontSize: 10)),
                          value: selectedPurok == 'NON-RESIDENCE',
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() => selectedPurok = 'NON-RESIDENCE');
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Dashed divider (tear effect)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: List.generate(
                    30,
                    (i) => Expanded(
                      child: Container(
                        height: 1,
                        color: i.isEven ? Colors.grey[300] : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              // Resident Info
              _receiptRow('NAME', widget.fullName),
              _receiptRow(
                'METER NUMBER',
                null,
                trailing: SizedBox(
                  width: 80,
                  child: TextFormField(
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: '1234',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
                        style: const TextStyle(fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: startDate == null
                              ? 'Start Date'
                              : DateFormat('yyyy-MM-dd').format(startDate!),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 8),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const Text(' - '),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        style: const TextStyle(fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: endDate == null
                              ? 'End Date'
                              : DateFormat('yyyy-MM-dd').format(endDate!),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 8),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
              ),
              // Bill values
              _receiptRow(
                  'PREVIOUS READING',
                  _loading
                      ? 'Loading...'
                      : '${previous.toStringAsFixed(2)} m³'),
              _receiptRow(
                'CURRENT READING',
                null,
                trailing: SizedBox(
                  width: 80,
                  child: TextFormField(
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      suffixText: 'm³',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
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
                  'TOTAL CUBIC METER USED', '${total.toStringAsFixed(2)} m³'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: List.generate(
                    30,
                    (i) => Expanded(
                      child: Container(
                        height: 1,
                        color: i.isEven ? Colors.grey[300] : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              _receiptRow('CURRENT BILL', '₱${currentBill.toStringAsFixed(2)}',
                  valueColor: Colors.black87),
              _receiptRow(
                  'TOTAL BILL AMOUNT', '₱${totalBill.toStringAsFixed(2)}',
                  valueColor: Color(0xFF4A2C6F)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A2C6F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Create Bill'),
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
                        };

                        print('Creating bill with data: $billData');

                        await FirebaseFirestore.instance
                            .collection('bills')
                            .add(billData);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bill created successfully!'),
                            backgroundColor: Color(0xFF4A2C6F),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String? value,
          {Widget? trailing, Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: valueColor ?? Colors.black54,
                ),
              ),
            if (trailing != null) trailing,
          ],
        ),
      );
}
