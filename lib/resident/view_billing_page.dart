import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewBillingPage extends StatefulWidget {
  const ViewBillingPage({super.key});

  @override
  State<ViewBillingPage> createState() => _ViewBillingPageState();
}

class _ViewBillingPageState extends State<ViewBillingPage> {
  File? _receiptImage;
  Map<String, dynamic>? _latestBill;
  bool _loading = true;
  String? _error;
  String _residentId = 'ZEEuYzKxgqVzjliWPsN6K490O1H3'; // You'll need to get this from auth
  bool _paymentSubmitted = false;
  String? _paymentStatus;

  @override
  void initState() {
    super.initState();
    _loadLatestBill();
  }

  Future<void> _loadLatestBill() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // First, let's try to get all bills for this resident to debug
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('residentId', isEqualTo: _residentId)
          .get();

      print('Found ${snapshot.docs.length} bills for resident: $_residentId');
      
      if (snapshot.docs.isNotEmpty) {
        // Sort by issueDate to get the latest
        final sortedDocs = snapshot.docs.toList()
          ..sort((a, b) {
            final aDate = a.data()['issueDate'] as Timestamp?;
            final bDate = b.data()['issueDate'] as Timestamp?;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate); // Descending order
          });

        final latestBill = sortedDocs.first.data();
        latestBill['billId'] = sortedDocs.first.id; // Add billId to the data
        print('Latest bill data: $latestBill');
        
        // Check if payment has been submitted for this bill
        await _checkPaymentStatus(latestBill['billId']);
        
        setState(() {
          _latestBill = latestBill;
          _loading = false;
        });
      } else {
        // If no bills found, let's check if the resident exists
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

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A2C6F)),
          ),
        ),
      );

      // Convert image to base64
      final bytes = await _receiptImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Get bill details
      final bill = _latestBill!;
      final billId = bill['billId'] ?? 'unknown'; // You might need to store billId when creating bills
      
      // Create payment record
      final paymentData = {
        'residentId': _residentId,
        'billId': billId,
        'residentName': bill['fullName'],
        'residentAddress': bill['address'],
        'billAmount': bill['totalBill'],
        'receiptImage': base64Image,
        'paymentMethod': 'GCash',
        'gcashNumber': '09853886411',
        'submissionDate': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, approved, rejected
        'adminNotes': '',
        'processedBy': '',
        'processedDate': null,
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('payments')
          .add(paymentData);

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment submitted successfully! Awaiting admin approval.'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear the image
      setState(() {
        _receiptImage = null;
      });

    } catch (e) {
      // Close loading dialog
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
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      body: _loading 
        ? _buildLoadingState()
        : _error != null 
          ? _buildErrorState() 
          : _latestBill == null 
            ? _buildNoBillsState()
            : _buildBillingContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
          padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A2C6F)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading your bill...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Oops!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadLatestBill,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A2C6F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoBillsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
          child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A2C6F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: const Color(0xFF4A2C6F),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Bills Yet',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You don\'t have any bills at the moment.\nCheck back later!',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadLatestBill,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A2C6F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillingContent() {
    final bill = _latestBill!;
    final currentConsumed = bill['currentConsumedWaterMeter'] ?? 0.0;
    final previousConsumed = bill['previousConsumedWaterMeter'] ?? 0.0;
    final totalConsumed = bill['totalConsumed'] ?? 0.0;
    final currentBill = bill['currentMonthBill'] ?? 0.0;
    final totalBill = bill['totalBill'] ?? 0.0;
    final issueDate = bill['issueDate'] as Timestamp?;
    final formattedDate = issueDate != null 
        ? DateFormat('dd MMM yyyy').format(issueDate.toDate())
        : 'N/A';
    final lastPaymentDate = issueDate != null 
        ? DateFormat('dd MMM yyyy').format(issueDate.toDate().add(const Duration(days: 6)))
        : 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Receipt Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Company Logo/Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A2C6F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.water_drop,
                    size: 32,
                    color: Color(0xFF87CEEB),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "VIEW BILLING",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Official Receipt",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Receipt Number and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Receipt #",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          "WB-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Date",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Customer Information
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CUSTOMER INFORMATION",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                _buildReceiptRow("Name", bill['fullName'] ?? 'N/A'),
                _buildReceiptRow("Address", bill['address'] ?? 'N/A'),
                _buildReceiptRow("Contact", bill['contactNumber'] ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Billing Details
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "BILLING DETAILS",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                _buildReceiptRow("Bill Period", "Current Month"),
                _buildReceiptRow("Issue Date", formattedDate),
                _buildReceiptRow("Due Date", lastPaymentDate),
                const Divider(height: 20, thickness: 1, color: Color(0xFFE0E0E0)),
                
                // Consumption Details
                Text(
                  "CONSUMPTION DETAILS",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                _buildReceiptRow("Previous Reading", "${previousConsumed.toStringAsFixed(1)} m³"),
                _buildReceiptRow("Current Reading", "${currentConsumed.toStringAsFixed(1)} m³"),
                _buildReceiptRow("Total Consumption", "${totalConsumed.toStringAsFixed(1)} m³"),
                const Divider(height: 20, thickness: 1, color: Color(0xFFE0E0E0)),
                
                // Rate Information
                Text(
                  "RATE INFORMATION",
                    style: GoogleFonts.poppins(
                    fontSize: 14,
                      fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                _buildReceiptRow("Rate per 10m³", "₱30.00"),
                _buildReceiptRow("Minimum Charge", "₱30.00"),
                _buildReceiptRow("Current Bill", "₱${currentBill.toStringAsFixed(2)}"),
                const Divider(height: 20, thickness: 1, color: Color(0xFFE0E0E0)),
                
                // Total Amount
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A2C6F).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4A2C6F).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "TOTAL AMOUNT DUE:",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        "₱${totalBill.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color.fromARGB(255, 223, 77, 77),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Payment Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "PAYMENT METHOD",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Payment Status
                if (_paymentSubmitted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_paymentStatus!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor(_paymentStatus!).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(_paymentStatus!),
                          color: _getStatusColor(_paymentStatus!),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStatusText(_paymentStatus!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(_paymentStatus!),
                                ),
                              ),
                              Text(
                                _getStatusDescription(_paymentStatus!),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // GCash Number
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.phone, color: Colors.green, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "GCash Number",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "09853886411",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          // TODO: Copy to clipboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('GCash number copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Upload Receipt (only show if payment not submitted)
                if (!_paymentSubmitted) ...[
                ElevatedButton.icon(
                  onPressed: _pickReceiptImage,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload Payment Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.grey[800],
                    elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  
                  if (_receiptImage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        _receiptImage!,
                              height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _receiptImage = null);
                            },
                            icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                            label: const Text('Remove Receipt', style: TextStyle(color: Colors.red)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Send Payment Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _receiptImage != null ? _uploadReceipt : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _receiptImage != null 
                            ? const Color(0xFF4A2C6F) 
                            : Colors.grey[300],
                        foregroundColor: _receiptImage != null 
                            ? Colors.white 
                            : Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: _receiptImage != null ? 2 : 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _receiptImage != null ? Icons.send : Icons.upload,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _receiptImage != null ? 'Submit Payment' : 'Upload Receipt First',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              label,
              style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
              value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
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
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.pending_actions_outlined;
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
        return 'Your payment has been approved by the administrator.';
      case 'rejected':
        return 'Your payment has been rejected by the administrator.';
      default:
        return 'Your payment is awaiting administrator approval.';
    }
  }
}

