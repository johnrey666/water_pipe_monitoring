// transaction_history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';

class TransactionHistoryPage extends StatefulWidget {
  final String? residentId;

  const TransactionHistoryPage({super.key, required this.residentId});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  // UPDATED COLORS TO MATCH HOMEPAGE
  final Color primaryColor = const Color(0xFF00BCD4); // Aqua Blue
  final Color accentColor = const Color(0xFF4DD0E1); // Lighter Aqua Blue
  final Color backgroundColor =
      const Color(0xFFE0F7FA); // Light aqua background
  final Color darkAqua = const Color(0xFF00838F); // Dark aqua for text

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _filterType = 'All';
  final List<String> _filterTypes = ['All', 'Accepted', 'Rejected', 'Unpaid'];
  // ignore: unused_field
  String? _selectedReceiptImage;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (widget.residentId == null || widget.residentId!.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final List<Map<String, dynamic>> allTransactions = [];

      // 1. Load from transaction_history collection
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('transaction_history')
            .where('residentId', isEqualTo: widget.residentId)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final type = data['type']?.toString() ?? 'Unknown';
          final status = data['status']?.toString() ?? 'unknown';
          final amount = (data['amount'] is num)
              ? (data['amount'] as num).toDouble()
              : 0.0;
          final description = data['description']?.toString() ?? '';
          final timestamp = data['timestamp'] as Timestamp?;
          final billId = data['billId']?.toString();
          final month = data['month']?.toString();
          final processedBy = data['processedBy']?.toString();
          final rejectionReason = data['rejectionReason']?.toString();
          final receiptImage = data['receiptImage']?.toString();

          // Determine icon and color based on status
          IconData icon;
          Color iconColor;
          String displayType = type;

          if (type.toLowerCase().contains('payment')) {
            icon = Icons.payment;
            displayType = 'Payment';
            if (status.toLowerCase() == 'approved') {
              iconColor = primaryColor; // Aqua blue for approved
            } else if (status.toLowerCase() == 'rejected') {
              iconColor = Colors.red;
            } else {
              iconColor = Colors.orange;
            }
          } else if (type.toLowerCase().contains('bill')) {
            icon = Icons.receipt;
            displayType = 'Bill';
            if (status.toLowerCase() == 'paid') {
              iconColor = primaryColor; // Aqua blue for paid
            } else {
              iconColor = darkAqua; // Dark aqua for unpaid
            }
          } else {
            icon = Icons.receipt;
            iconColor = darkAqua;
          }

          allTransactions.add({
            'id': doc.id,
            'type': displayType,
            'amount': amount,
            'date': timestamp?.toDate() ?? DateTime.now(),
            'description': description.isNotEmpty
                ? description
                : '$displayType transaction',
            'status': status,
            'icon': icon,
            'iconColor': iconColor,
            'billId': billId,
            'month': month,
            'processedBy': processedBy ?? 'System',
            'rejectionReason': rejectionReason,
            'receiptImage': receiptImage,
          });
        }
      } catch (e) {
        print('Error loading transaction_history: $e');
      }

      // 2. Load from payments collection
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('payments')
            .where('residentId', isEqualTo: widget.residentId)
            .orderBy('submissionDate', descending: true)
            .limit(50)
            .get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final status = data['status']?.toString() ?? 'pending';
          final amount = (data['billAmount'] is num)
              ? (data['billAmount'] as num).toDouble()
              : 0.0;
          final billId = data['billId']?.toString();
          final submissionDate = data['submissionDate'] as Timestamp?;
          final rejectionReason = data['rejectionReason']?.toString();
          final receiptImage = data['receiptImage']?.toString();

          // Get month from bill
          String month = 'Unknown';
          if (billId != null && billId.isNotEmpty) {
            try {
              final billDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.residentId)
                  .collection('bills')
                  .doc(billId)
                  .get();

              if (billDoc.exists) {
                final billData = billDoc.data()!;
                final periodStart = billData['periodStart'] as Timestamp?;
                month = periodStart != null
                    ? DateFormat('MMM yyyy').format(periodStart.toDate())
                    : 'Unknown';
              }
            } catch (e) {
              print('Error fetching bill month: $e');
            }
          }

          allTransactions.add({
            'id': doc.id,
            'type': 'Payment',
            'amount': amount,
            'date': submissionDate?.toDate() ?? DateTime.now(),
            'description':
                _getPaymentDescription(status, month, rejectionReason),
            'status': status,
            'icon': Icons.payment,
            'iconColor': status == 'approved'
                ? primaryColor // Aqua blue
                : status == 'rejected'
                    ? Colors.red
                    : Colors.orange,
            'billId': billId,
            'month': month,
            'processedBy': 'System',
            'rejectionReason': rejectionReason,
            'receiptImage': receiptImage,
          });
        }
      } catch (e) {
        print('Error loading payments: $e');
      }

      // 3. Load from bills collection
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.residentId)
            .collection('bills')
            .orderBy('periodStart', descending: true)
            .limit(30)
            .get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final periodStart = data['periodStart'] as Timestamp?;
          final amount = (data['currentMonthBill'] is num)
              ? (data['currentMonthBill'] as num).toDouble()
              : 0.0;
          final cubicMeterUsed = (data['cubicMeterUsed'] is num)
              ? (data['cubicMeterUsed'] as num).toDouble()
              : 0.0;

          // Check if bill has been paid
          bool isPaid = false;
          try {
            final paymentSnapshot = await FirebaseFirestore.instance
                .collection('payments')
                .where('billId', isEqualTo: doc.id)
                .where('status', isEqualTo: 'approved')
                .limit(1)
                .get();

            isPaid = paymentSnapshot.docs.isNotEmpty;
          } catch (e) {
            print('Error checking payment status: $e');
          }

          final status = isPaid ? 'paid' : 'unpaid';
          final month = periodStart != null
              ? DateFormat('MMM yyyy').format(periodStart.toDate())
              : 'Unknown';

          allTransactions.add({
            'id': doc.id,
            'type': 'Bill',
            'amount': amount,
            'date': periodStart?.toDate() ?? DateTime.now(),
            'description':
                'Water bill for $month - ${cubicMeterUsed.toStringAsFixed(2)} m³',
            'status': status,
            'icon': Icons.receipt,
            'iconColor': status == 'paid'
                ? primaryColor
                : Colors.red, // Aqua blue for paid
            'billId': doc.id,
            'month': month,
            'processedBy': 'System',
            'rejectionReason': null,
            'receiptImage': null,
          });
        }
      } catch (e) {
        print('Error loading bills: $e');
      }

      // Remove duplicates and sort by date
      final uniqueTransactions = <String, Map<String, dynamic>>{};
      for (var transaction in allTransactions) {
        final key =
            '${transaction['type']}_${transaction['amount']}_${transaction['date']}';
        if (!uniqueTransactions.containsKey(key) ||
            (uniqueTransactions[key]!['date'] as DateTime)
                .isBefore(transaction['date'] as DateTime)) {
          uniqueTransactions[key] = transaction;
        }
      }

      final sortedTransactions = uniqueTransactions.values.toList()
        ..sort(
            (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _transactions = sortedTransactions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading transactions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getPaymentDescription(
      String status, String month, String? rejectionReason) {
    switch (status) {
      case 'approved':
        return 'Payment accepted for $month\nAmount has been processed successfully';
      case 'rejected':
        if (rejectionReason != null && rejectionReason.isNotEmpty) {
          return 'Payment rejected for $month\nReason: $rejectionReason';
        }
        return 'Payment rejected for $month\nPlease contact administrator for details';
      case 'pending':
        return 'Payment submitted for $month\nAwaiting administrator review';
      default:
        return 'Payment for $month';
    }
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    List<Map<String, dynamic>> filtered = _transactions;

    if (_filterType == 'Accepted') {
      filtered = filtered.where((t) {
        final status = t['status'].toString().toLowerCase();
        return status == 'approved' || status == 'paid';
      }).toList();
    } else if (_filterType == 'Rejected') {
      filtered = filtered
          .where((t) => t['status'].toString().toLowerCase() == 'rejected')
          .toList();
    } else if (_filterType == 'Unpaid') {
      filtered = filtered
          .where((t) => t['status'].toString().toLowerCase() == 'unpaid')
          .toList();
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'paid':
        return primaryColor; // Aqua blue for approved/paid
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'unpaid':
        return Colors.red;
      default:
        return darkAqua;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'ACCEPTED';
      case 'paid':
        return 'PAID';
      case 'pending':
        return 'PENDING';
      case 'rejected':
        return 'REJECTED';
      case 'unpaid':
        return 'UNPAID';
      default:
        return status.toUpperCase();
    }
  }

  void _showReceiptDialog(String? receiptImage) {
    if (receiptImage == null || receiptImage.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color(0xFFE0F7FA),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Receipt',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: darkAqua,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: accentColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                height: 400,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFB2EBF2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64.decode(receiptImage),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: primaryColor),
                            const SizedBox(height: 16),
                            Text(
                              'Unable to load receipt',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final date = transaction['date'] as DateTime;
    final amount = transaction['amount'] as double;
    final status = transaction['status'].toString();
    final description = transaction['description'].toString();
    final month = transaction['month']?.toString();
    final icon = transaction['icon'] as IconData;
    final iconColor = transaction['iconColor'] as Color;
    final rejectionReason = transaction['rejectionReason']?.toString();
    final receiptImage = transaction['receiptImage']?.toString();
    final hasReceipt = receiptImage != null && receiptImage.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Color(0xFFE0F7FA),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF5FDFF),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        transaction['type'].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: darkAqua,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rejectionReason,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (month != null) ...[
              const SizedBox(height: 8),
              Text(
                month,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: accentColor,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
                Row(
                  children: [
                    if (hasReceipt)
                      InkWell(
                        onTap: () => _showReceiptDialog(receiptImage),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt,
                                  size: 12, color: primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                'Receipt',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _getFilteredTransactions();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Filter chips section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Color(0xFFE0F7FA),
                width: 1,
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filterTypes.map((type) {
                final isSelected = _filterType == type;
                return ChoiceChip(
                  label: Text(
                    type,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _filterType = type;
                      });
                    }
                  },
                  selectedColor: primaryColor,
                  backgroundColor: Color(0xFFE0F7FA),
                  labelStyle: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : darkAqua,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ),

          // Transaction count and refresh
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredTransactions.length} transactions',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: darkAqua,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                InkWell(
                  onTap: _loadTransactions,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.refresh,
                      size: 20,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Transactions list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading transactions...',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Color(0xFF80DEEA),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: darkAqua,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _filterType != 'All'
                                  ? 'Try changing your filter'
                                  : 'You have no transactions yet',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _loadTransactions,
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                              ),
                              child: Text(
                                'Refresh',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        color: primaryColor,
                        backgroundColor: Colors.white,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(
                                filteredTransactions[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
