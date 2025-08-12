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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF5F6FA)],
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
                // Header with Purok Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset('assets/images/icon.png', height: 45),
                            const SizedBox(height: 8),
                            Text(
                              'San Jose Water Services Administration\nSajowasa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                letterSpacing: 1.2,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat.yMMMd().format(DateTime.now()),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.1),
                            blurRadius: 5,
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
                            child: Text(value, style: TextStyle(fontSize: 11)),
                          );
                        }).toList(),
                        underline: SizedBox(),
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down,
                            color: Color(0xFF2C3E50), size: 18),
                        dropdownColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                // Dashed divider
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: List.generate(
                      30,
                      (i) => Expanded(
                        child: Container(
                          height: 1,
                          color:
                              i.isEven ? Colors.grey[300] : Colors.transparent,
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
                      decoration: InputDecoration(
                        hintText: '1234',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
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
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: startDate == null
                                ? 'Start'
                                : DateFormat('MM-dd').format(startDate!),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Color(0xFF2C3E50)),
                            ),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('-',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFF2C3E50))),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: endDate == null
                                ? 'End'
                                : DateFormat('MM-dd').format(endDate!),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: List.generate(
                      30,
                      (i) => Expanded(
                        child: Container(
                          height: 1,
                          color:
                              i.isEven ? Colors.grey[300] : Colors.transparent,
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
                            vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFF2C3E50)),
                        ),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: List.generate(
                      30,
                      (i) => Expanded(
                        child: Container(
                          height: 1,
                          color:
                              i.isEven ? Colors.grey[300] : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),
                _receiptRow(
                    'CURRENT BILL', '₱${currentBill.toStringAsFixed(2)}',
                    valueColor: Colors.black87),
                _receiptRow(
                    'TOTAL BILL AMOUNT', '₱${totalBill.toStringAsFixed(2)}',
                    valueColor: Color(0xFF2C3E50)),
                const SizedBox(height: 20),
                // Rates section
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _rateRow('Residential:',
                              'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                          const SizedBox(width: 10),
                          _rateRow('Commercial:',
                              'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _rateRow('Non Residence:',
                              'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                          const SizedBox(width: 10),
                          _rateRow('Industrial:',
                              'Min 10 m³ = 100.00 PHP\nExceed = 15.00 PHP/m³'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        foregroundColor: Color(0xFF2C3E50),
                        side: BorderSide(color: Color(0xFF2C3E50)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 5,
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
                              backgroundColor: Color(0xFF2C3E50),
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
      ),
    );
  }

  Widget _receiptRow(String label, String? value,
          {Widget? trailing, Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
                fontSize: 14,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                details,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
}
