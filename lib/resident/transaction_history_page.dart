// transaction_history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class TransactionHistoryPage extends StatefulWidget {
  final String? residentId;

  const TransactionHistoryPage({super.key, required this.residentId});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _filterType = 'All';
  final List<String> _filterTypes = ['All', 'Payment', 'Bill'];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isRefreshing = false;
  Timer? _debounceTimer;

  // Statistics
  double _totalSpent = 0.0;
  int _totalTransactions = 0;
  int _approvedCount = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    print('DEBUG: initState called with residentId: ${widget.residentId}');
    _loadTransactions();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTransactions({bool isRefresh = false}) async {
    if (widget.residentId == null || widget.residentId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No resident ID provided';
      });
      return;
    }

    try {
      if (!isRefresh) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _isRefreshing = true;
        });
      }

      final List<Map<String, dynamic>> allTransactions = [];

      // 1. Load from transaction_history collection
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('transaction_history')
            .where('residentId', isEqualTo: widget.residentId)
            .orderBy('timestamp', descending: true)
            .limit(100)
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

          // Determine icon and color
          IconData icon;
          Color iconColor;
          String displayType = type;

          if (type.toLowerCase().contains('payment')) {
            icon = Icons.payment_rounded;
            displayType = 'Payment';
            if (status.toLowerCase() == 'approved') {
              iconColor = const Color(0xFF10B981); // Green
            } else if (status.toLowerCase() == 'rejected') {
              iconColor = const Color(0xFFEF4444); // Red
            } else if (status.toLowerCase() == 'pending') {
              iconColor = const Color(0xFFF59E0B); // Amber
            } else {
              iconColor = const Color(0xFF6B7280); // Gray
            }
          } else if (type.toLowerCase().contains('bill')) {
            icon = Icons.receipt_long_rounded;
            displayType = 'Bill';
            if (status.toLowerCase() == 'paid' ||
                status.toLowerCase() == 'created') {
              iconColor = const Color(0xFF3B82F6); // Blue
            } else {
              iconColor = const Color(0xFFF59E0B); // Amber
            }
          } else {
            icon = Icons.receipt_rounded;
            iconColor = const Color(0xFF6B7280);
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
            'timestamp': timestamp,
          });
        }
      } catch (e) {
        print('DEBUG: Error loading transaction_history: $e');
      }

      // 2. Load from payments collection
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('payments')
            .where('residentId', isEqualTo: widget.residentId)
            .orderBy('submissionDate', descending: true)
            .limit(100)
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
              print('DEBUG: Error fetching bill month: $e');
            }
          }

          allTransactions.add({
            'id': doc.id,
            'type': 'Payment',
            'amount': amount,
            'date': submissionDate?.toDate() ?? DateTime.now(),
            'description': status == 'approved'
                ? 'Payment approved for $month'
                : status == 'rejected'
                    ? 'Payment rejected for $month${rejectionReason != null ? ' - $rejectionReason' : ''}'
                    : 'Payment submitted for $month',
            'status': status,
            'icon': Icons.payment_rounded,
            'iconColor': status == 'approved'
                ? const Color(0xFF10B981)
                : status == 'rejected'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF59E0B),
            'billId': billId,
            'month': month,
            'processedBy': 'System',
            'timestamp': submissionDate,
          });
        }
      } catch (e) {
        print('DEBUG: Error loading payments: $e');
      }

      // 3. Load from bills collection
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.residentId)
            .collection('bills')
            .orderBy('periodStart', descending: true)
            .limit(50)
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
            print('DEBUG: Error checking payment status: $e');
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
            'icon': Icons.receipt_long_rounded,
            'iconColor': status == 'paid'
                ? const Color(0xFF10B981)
                : const Color(0xFF3B82F6),
            'billId': doc.id,
            'month': month,
            'processedBy': 'System',
            'timestamp': periodStart,
          });
        }
      } catch (e) {
        print('DEBUG: Error loading bills: $e');
      }

      // Remove duplicates (keep the most recent one)
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

      // Calculate statistics
      _calculateStatistics(sortedTransactions);

      setState(() {
        _transactions = sortedTransactions;
        _isLoading = false;
        _isRefreshing = false;
      });

      print('DEBUG: Loaded ${sortedTransactions.length} transactions');
    } catch (e) {
      print('DEBUG: Critical error in _loadTransactions: $e');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Error loading transactions. Please try again.';
      });
    }
  }

  void _calculateStatistics(List<Map<String, dynamic>> transactions) {
    double total = 0.0;
    int approved = 0;
    int pending = 0;

    for (var transaction in transactions) {
      final amount = transaction['amount'] as double;
      final status = transaction['status'].toString().toLowerCase();
      final type = transaction['type'].toString();

      if (type == 'Payment' && (status == 'approved' || status == 'paid')) {
        total += amount;
      } else if (type == 'Bill' && status == 'paid') {
        total += amount;
      }

      if (status == 'approved' || status == 'paid') {
        approved++;
      } else if (status == 'pending' || status == 'unpaid') {
        pending++;
      }
    }

    _totalSpent = total;
    _totalTransactions = transactions.length;
    _approvedCount = approved;
    _pendingCount = pending;
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    List<Map<String, dynamic>> filtered = _transactions;

    if (_filterType != 'All') {
      filtered = filtered.where((t) => t['type'] == _filterType).toList();
    }

    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((t) {
        final date = t['date'] as DateTime;
        return date.isAfter(_startDate!) &&
            date.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _clearFilters() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _filterType = 'All';
          _startDate = null;
          _endDate = null;
        });
      }
    });
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final date = transaction['date'] as DateTime;
    final amount = transaction['amount'] as double;
    final status = transaction['status'].toString();
    final description = transaction['description'].toString();
    final month = transaction['month']?.toString();
    final icon = transaction['icon'] as IconData;
    final iconColor = transaction['iconColor'] as Color;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Add tap action if needed
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: iconColor),
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
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
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
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (month != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    month,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getAmountColor(
                            transaction['type'].toString(), status),
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
          ),
        ),
      ),
    );
  }

  Color _getAmountColor(String type, String status) {
    if (type == 'Payment') {
      if (status == 'approved') {
        return const Color(0xFF10B981); // Green
      } else if (status == 'rejected') {
        return const Color(0xFFEF4444); // Red
      } else {
        return const Color(0xFFF59E0B); // Amber
      }
    } else {
      if (status == 'paid') {
        return const Color(0xFF10B981); // Green
      } else {
        return const Color(0xFF3B82F6); // Blue
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'paid':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'created':
        return const Color(0xFF3B82F6);
      case 'unpaid':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'APPROVED';
      case 'paid':
        return 'PAID';
      case 'pending':
        return 'PENDING';
      case 'rejected':
        return 'REJECTED';
      case 'created':
        return 'BILL CREATED';
      case 'unpaid':
        return 'UNPAID';
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Transaction Overview',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Total Spent',
                '₱${_totalSpent.toStringAsFixed(2)}',
                Icons.attach_money_rounded,
              ),
              _buildStatItem(
                'Transactions',
                '$_totalTransactions',
                Icons.receipt_long_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Approved',
                '$_approvedCount',
                Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
              ),
              _buildStatItem(
                'Pending',
                '$_pendingCount',
                Icons.pending_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      {Color color = Colors.white}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Transactions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          // Type Filter
          Row(
            children: [
              const Icon(Icons.filter_alt_rounded,
                  size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                'Type:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: _filterTypes.map((type) {
                    final isSelected = _filterType == type;
                    return ChoiceChip(
                      label: Text(type,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          )),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _filterType = type;
                          });
                        }
                      },
                      selectedColor: const Color(0xFF3B82F6),
                      backgroundColor: const Color(0xFFF3F4F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date Filter
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                'Date Range:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 16, color: const Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _startDate != null
                                      ? DateFormat('MMM dd, yyyy')
                                          .format(_startDate!)
                                      : 'Start Date',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: _startDate != null
                                        ? const Color(0xFF111827)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('to',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF6B7280))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 16, color: const Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _endDate != null
                                      ? DateFormat('MMM dd, yyyy')
                                          .format(_endDate!)
                                      : 'End Date',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: _endDate != null
                                        ? const Color(0xFF111827)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Clear Filters Button
          if (_filterType != 'All' || _startDate != null || _endDate != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Clear All Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundColor: const Color(0xFF6B7280),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _getFilteredTransactions();
    final hasFilters =
        _filterType != 'All' || _startDate != null || _endDate != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and refresh
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction History',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track all your payments and bills',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _loadTransactions(isRefresh: true),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isRefreshing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3B82F6)),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded,
                              color: Color(0xFF3B82F6), size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadTransactions(isRefresh: true),
                color: const Color(0xFF3B82F6),
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Statistics Card
                    SliverToBoxAdapter(
                      child: _buildStatisticsCard(),
                    ),
                    // Filter Section
                    SliverToBoxAdapter(
                      child: _buildFilterSection(),
                    ),
                    // Results Count
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filteredTransactions.length} ${filteredTransactions.length == 1 ? 'transaction' : 'transactions'} found',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            if (hasFilters)
                              Text(
                                'Filtered',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Transactions List or Loading/Error/Empty States
                    if (_isLoading)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3B82F6)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading transactions...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_errorMessage.isNotEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 64,
                                  color:
                                      const Color(0xFFEF4444).withOpacity(0.7),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Unable to load transactions',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Text(
                                    _errorMessage,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => _loadTransactions(),
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 18),
                                  label: const Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (filteredTransactions.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 64,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  hasFilters
                                      ? 'No transactions match your filters'
                                      : 'No transactions yet',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  hasFilters
                                      ? 'Try adjusting your filters to see more results'
                                      : 'Your transaction history will appear here',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: const Color(0xFF6B7280),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                if (hasFilters)
                                  ElevatedButton.icon(
                                    onPressed: _clearFilters,
                                    icon: const Icon(Icons.clear_all_rounded,
                                        size: 18),
                                    label: const Text('Clear Filters'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                    ),
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _loadTransactions(isRefresh: true),
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 18),
                                    label: const Text('Refresh'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildTransactionCard(
                                filteredTransactions[index]);
                          },
                          childCount: filteredTransactions.length,
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
