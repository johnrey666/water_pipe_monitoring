import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeterReaderHomePage extends StatefulWidget {
  const MeterReaderHomePage({super.key});

  @override
  State<MeterReaderHomePage> createState() => _MeterReaderHomePageState();
}

class _MeterReaderHomePageState extends State<MeterReaderHomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allResidents = [];
  List<Map<String, dynamic>> _filteredResidents = [];
  String _meterReaderName = 'Meter Reader';

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchMeterReaderName();
    _loadAllResidents();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchMeterReaderName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();

      if (data != null && data['fullName'] != null && mounted) {
        setState(() {
          _meterReaderName = data['fullName'];
        });
      }
    } catch (e) {
      print('Error fetching meter reader name: $e');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _currentPage = 0;
      if (query.isEmpty) {
        _filteredResidents = List.from(_allResidents);
      } else {
        _filteredResidents = _allResidents.where((resident) {
          final name = resident['fullName']?.toString().toLowerCase() ?? '';
          final address = resident['address']?.toString().toLowerCase() ?? '';
          final contact =
              resident['contactNumber']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) ||
              address.contains(searchLower) ||
              contact.contains(searchLower);
        }).toList();
      }
      _updatePagination();
    });
  }

  void _updatePagination() {
    setState(() {
      _totalPages = (_filteredResidents.length / _itemsPerPage).ceil();
      if (_totalPages == 0) _totalPages = 1;
    });
  }

  List<Map<String, dynamic>> get _currentPageResidents {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredResidents.sublist(
      startIndex,
      endIndex > _filteredResidents.length
          ? _filteredResidents.length
          : endIndex,
    );
  }

  Future<void> _loadAllResidents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Resident')
          .orderBy('fullName')
          .get();
      setState(() {
        _allResidents = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        _filteredResidents = List.from(_allResidents);
        _isLoading = false;
        _updatePagination();
      });
    } catch (e) {
      print('Error loading residents: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadAllResidents();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Meter',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        elevation: 2,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.blue.shade700),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF87CEEB),
                      Color.fromARGB(255, 127, 190, 226),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person,
                          size: 36, color: Color.fromARGB(255, 58, 56, 56)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome!',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _meterReaderName,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            'Meter Reader',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Material(
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.people_outline,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          title: Text(
                            'Residents Billing',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          selected: true,
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _logout,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search residents...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear,
                          size: 18, color: Colors.grey.shade500),
                      onPressed: () => _searchController.clear(),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          // Resident Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredResidents.length} resident${_filteredResidents.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_filteredResidents.isNotEmpty)
                  Text(
                    'Page ${_currentPage + 1}/$_totalPages',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Residents List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredResidents.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _currentPageResidents.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final resident = _currentPageResidents[index];
                            return ResidentCard(
                              resident: resident,
                              onTap: () => _showBillModal(context, resident),
                            );
                          },
                        ),
                      ),
          ),
          // Pagination
          if (_filteredResidents.isNotEmpty && _totalPages > 1)
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No residents found' : 'No results found',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _searchController.clear(),
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            color: _currentPage > 0 ? Colors.blue : Colors.grey.shade400,
            iconSize: 24,
          ),
          const SizedBox(width: 8),
          // Page numbers
          Wrap(
            spacing: 4,
            children: List.generate(_totalPages, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() => _currentPage = index);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.blue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _currentPage == index
                          ? Colors.blue
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            color: _currentPage < _totalPages - 1
                ? Colors.blue
                : Colors.grey.shade400,
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  void _showBillModal(BuildContext context, Map<String, dynamic> resident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => WaterBillForm(
        resident: resident,
        onBillCreated: _refreshData,
      ),
    );
  }
}

class ResidentCard extends StatefulWidget {
  final Map<String, dynamic> resident;
  final VoidCallback onTap;

  const ResidentCard({
    super.key,
    required this.resident,
    required this.onTap,
  });

  @override
  State<ResidentCard> createState() => _ResidentCardState();
}

class _ResidentCardState extends State<ResidentCard> {
  bool _hasBills = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkForBills();
  }

  Future<void> _checkForBills() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.resident['id'])
          .collection('bills')
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _hasBills = snapshot.docs.isNotEmpty;
          _isChecking = false;
        });
      }
    } catch (e) {
      print('Error checking bills: $e');
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.resident['fullName'] ?? 'Unknown Resident';
    final address = widget.resident['address'] ?? 'No address';
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status
              _isChecking
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _hasBills
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hasBills
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                        ),
                      ),
                      child: Text(
                        _hasBills ? 'Has Bills' : 'No Bills',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _hasBills
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),
              const SizedBox(width: 12),
              // Action Button
              ElevatedButton(
                onPressed: widget.onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _hasBills ? 'Update' : 'Create',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaterBillForm extends StatefulWidget {
  final Map<String, dynamic> resident;
  final VoidCallback onBillCreated;

  const WaterBillForm({
    super.key,
    required this.resident,
    required this.onBillCreated,
  });

  @override
  State<WaterBillForm> createState() => _WaterBillFormState();
}

class _WaterBillFormState extends State<WaterBillForm> {
  final _formKey = GlobalKey<FormState>();
  final _currentReadingController = TextEditingController();
  final _meterNumberController = TextEditingController();

  double _previousReading = 0.0;
  bool _loading = true;
  bool _submitting = false;
  bool _showRates = false;
  String? _error;

  String _selectedPurok = 'PUROK 1';
  DateTime _periodStart = DateTime.now();
  DateTime _periodDue = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _selectedPurok = widget.resident['purok'] ?? 'PUROK 1';
    _loadPreviousData();
  }

  @override
  void dispose() {
    _currentReadingController.dispose();
    _meterNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousData() async {
    try {
      // Load previous reading
      final meterSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.resident['id'])
          .collection('meter_readings')
          .doc('latest')
          .get();
      if (meterSnapshot.exists) {
        final data = meterSnapshot.data()!;
        setState(() {
          _previousReading =
              data['currentConsumedWaterMeter']?.toDouble() ?? 0.0;
        });
      }
      // Load meter number
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.resident['id'])
          .get();
      if (userSnapshot.exists) {
        final data = userSnapshot.data()!;
        _meterNumberController.text = data['meterNumber'] ?? '';
      }
    } catch (e) {
      print('Error loading previous data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _cubicMeterUsed {
    final current = double.tryParse(_currentReadingController.text) ?? 0.0;
    return current >= _previousReading ? current - _previousReading : 0.0;
  }

  double _calculateBill() {
    final double baseRate;
    final double ratePerCubicMeter;
    switch (_selectedPurok) {
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
      default:
        baseRate = 30.00;
        ratePerCubicMeter = 5.00;
    }
    final excess = _cubicMeterUsed > 10 ? _cubicMeterUsed - 10 : 0;
    return baseRate + (excess * ratePerCubicMeter);
  }

  Future<void> _submitReading() async {
    if (!_formKey.currentState!.validate()) return;
    final currentReading = double.tryParse(_currentReadingController.text);
    if (currentReading == null) return;

    // ADDED: Additional validation for current reading
    if (currentReading < _previousReading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: Current reading must be greater than or equal to previous reading (${_previousReading.toStringAsFixed(2)} m³)',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      setState(() {
        _submitting = true;
        _error = null;
      });

      // Get meter reader's name
      User? user = FirebaseAuth.instance.currentUser;
      String recordedByName = 'Unknown';
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        recordedByName = userData?['fullName'] ?? 'Unknown';
      }

      final billData = {
        'residentId': widget.resident['id'],
        'fullName': widget.resident['fullName'],
        'address': widget.resident['address'],
        'contactNumber': widget.resident['contactNumber'],
        'meterNumber': _meterNumberController.text.trim(),
        'periodStart': Timestamp.fromDate(_periodStart),
        'periodDue': Timestamp.fromDate(_periodDue),
        'currentConsumedWaterMeter': currentReading,
        'previousConsumedWaterMeter': _previousReading,
        'cubicMeterUsed': _cubicMeterUsed,
        'currentMonthBill': _calculateBill(),
        'issueDate': Timestamp.now(),
        'purok': _selectedPurok,
        'recordedBy': FirebaseAuth.instance.currentUser?.email,
        'recordedByName': recordedByName, // ADDED: Meter reader's name
        'recordedAt': Timestamp.now(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Add bill
        final billRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.resident['id'])
            .collection('bills')
            .doc();
        transaction.set(billRef, billData);

        // Update meter number
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.resident['id']);
        transaction.set(
            userRef,
            {
              'meterNumber': _meterNumberController.text.trim(),
            },
            SetOptions(merge: true));

        // Update latest reading
        final meterRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.resident['id'])
            .collection('meter_readings')
            .doc('latest');
        transaction.set(meterRef, {
          'currentConsumedWaterMeter': currentReading,
          'updatedAt': Timestamp.now(),
        });
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onBillCreated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Water bill created successfully',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error submitting reading: $e');
      setState(() {
        _error = 'Failed to submit reading';
        _submitting = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _periodStart : _periodDue,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _periodStart = picked;
          _periodDue = picked.add(const Duration(days: 30));
        } else {
          _periodDue = picked;
        }
      });
    }
  }

  Widget _dashedDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: List.generate(
            30,
            (i) => Expanded(
              child: Container(
                height: 1,
                color: i.isEven ? Colors.grey.shade200 : Colors.transparent,
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
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Colors.black,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  fontSize: fontSize,
                  color: valueColor ?? Colors.grey.shade700,
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

  // UPDATED: New minimal underline-style field
  Widget _minimalInputField(String label, Widget child) {
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            child,
            const Divider(
              height: 1,
              thickness: 1,
              color: Colors.black,
            ),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    final currentReading =
        double.tryParse(_currentReadingController.text) ?? 0.0;
    final isOverdue = DateTime.now().isAfter(_periodDue);
    final dueColor = isOverdue ? Colors.red : Colors.black;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Drag handle
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with Purok Dropdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.water_drop, color: Colors.blue[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Water Bill',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              widget.resident['fullName'],
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Purok Dropdown moved here
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPurok,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF4A90E2)),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                        isExpanded: true,
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() => _selectedPurok = value);
                          }
                        },
                        items: [
                          'PUROK 1',
                          'PUROK 2',
                          'PUROK 3',
                          'PUROK 4',
                          'PUROK 5',
                          'COMMERCIAL',
                          'NON-RESIDENCE',
                          'INDUSTRIAL',
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_loading)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      )
                    else ...[
                      // Water Bill Template
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 500),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.water_drop,
                                          color: Colors.blue[700],
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A90E2),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black12.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _selectedPurok,
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
                              const Text(
                                'WATER BILL STATEMENT',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A90E2),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _dashedDivider(),
                              _receiptRow(
                                  'Name', widget.resident['fullName'] ?? 'N/A'),
                              _receiptRow('Address',
                                  widget.resident['address'] ?? 'N/A'),
                              _receiptRow('Contact',
                                  widget.resident['contactNumber'] ?? 'N/A'),

                              // UPDATED: Minimal Meter Number Input
                              _minimalInputField(
                                'Meter No.',
                                TextFormField(
                                  controller: _meterNumberController,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter meter number',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    errorStyle: TextStyle(
                                      fontSize: 9,
                                      fontFamily: 'monospace',
                                      color: Colors.red,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              // UPDATED: Minimal Billing Period Start
                              _minimalInputField(
                                'Billing Period Start',
                                InkWell(
                                  onTap: () => _selectDate(context, true),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 14,
                                            color: Colors.grey.shade600),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat('MM-dd-yyyy')
                                              .format(_periodStart),
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Billing Period Due (minimal style)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Billing Period Due',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () => _selectDate(context, false),
                                      child: Text(
                                        DateFormat('MM-dd-yyyy')
                                            .format(_periodDue),
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: dueColor,
                                        ),
                                      ),
                                    ),
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),

                              _receiptRow('Issue Date',
                                  DateFormat.yMMMd().format(DateTime.now())),
                              _dashedDivider(),
                              _receiptRow('Previous Reading',
                                  '${_previousReading.toStringAsFixed(2)} m³'),

                              // UPDATED: Minimal Current Reading Input
                              _minimalInputField(
                                'Current Reading',
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _currentReadingController,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '0.00',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4),
                                          errorStyle: TextStyle(
                                            fontSize: 9,
                                            fontFamily: 'monospace',
                                            color: Colors.red,
                                          ),
                                        ),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        onChanged: (value) {
                                          setState(() {});
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Required';
                                          }
                                          final reading =
                                              double.tryParse(value);
                                          if (reading == null) {
                                            return 'Invalid number';
                                          }
                                          if (reading < _previousReading) {
                                            return 'Must be ≥ previous';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'm³',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ADDED: Warning message when current reading is lower than previous
                              if (currentReading < _previousReading &&
                                  currentReading > 0)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.warning_amber,
                                            color: Colors.orange.shade700,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '⚠️ Warning: Current reading (${currentReading.toStringAsFixed(2)} m³) is lower than previous reading (${_previousReading.toStringAsFixed(2)} m³). '
                                            'The system requires the current meter reading to exceed the previous reading for proper computation.',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.orange.shade900,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              _receiptRow(
                                  'Cubic Meter Used',
                                  currentReading < _previousReading
                                      ? '0.00 m³ (Invalid: Current < Previous)'
                                      : '${_cubicMeterUsed.toStringAsFixed(2)} m³',
                                  isBold: true,
                                  valueColor: currentReading < _previousReading
                                      ? Colors.red
                                      : null),
                              _dashedDivider(),
                              _receiptRow('Current Bill',
                                  '₱${_calculateBill().toStringAsFixed(2)}',
                                  valueColor: Colors.red,
                                  isBold: true,
                                  fontSize: 13),
                              _receiptRow('Due Date',
                                  DateFormat('MM-dd-yyyy').format(_periodDue),
                                  valueColor: dueColor),
                              if (isOverdue)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber,
                                          color: Colors.red, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Bill will be overdue',
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
                                onTap: () =>
                                    setState(() => _showRates = !_showRates),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                        _showRates
                                            ? Icons.expand_less
                                            : Icons.expand_more,
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
                                    border: Border.all(
                                        color: Colors.grey.shade200, width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12.withOpacity(0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[700]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submitReading,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save, size: 20),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'SAVE WATER BILL',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
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
            ),
          ],
        ),
      ),
    );
  }
}
