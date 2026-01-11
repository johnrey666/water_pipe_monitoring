// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

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

  // Purok Filter
  String? _selectedPurok;
  List<String> _purokOptions = [
    'All Puroks',
    'PUROK 1',
    'PUROK 2',
    'PUROK 3',
    'PUROK 4',
    'PUROK 5',
    'COMMERCIAL',
    'NON-RESIDENCE',
    'INDUSTRIAL',
  ];

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _selectedPurok = _purokOptions[0]; // Default to "All Puroks"
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
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allResidents);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((resident) {
        final name = resident['fullName']?.toString().toLowerCase() ?? '';
        final address = resident['address']?.toString().toLowerCase() ?? '';
        final contact =
            resident['contactNumber']?.toString().toLowerCase() ?? '';
        final searchLower = _searchQuery.toLowerCase();

        return name.contains(searchLower) ||
            address.contains(searchLower) ||
            contact.contains(searchLower);
      }).toList();
    }

    // Apply purok filter - FIXED: Check both cases and handle null/empty
    if (_selectedPurok != null && _selectedPurok != 'All Puroks') {
      filtered = filtered.where((resident) {
        final residentPurok = resident['purok']?.toString().trim() ?? '';
        return residentPurok.isNotEmpty && residentPurok == _selectedPurok;
      }).toList();
    }

    setState(() {
      _filteredResidents = filtered;
      _updatePagination();
    });
  }

  void _onPurokChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedPurok = value;
        _currentPage = 0;
        _applyFilters();
      });
    }
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

      if (mounted) {
        setState(() {
          _allResidents = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
              // Ensure purok field exists and is standardized
              'purok': _standardizePurok(data['purok']?.toString() ?? ''),
            };
          }).toList();

          _filteredResidents = List.from(_allResidents);
          _isLoading = false;
          _updatePagination();
        });
      }
    } catch (e) {
      print('Error loading residents: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to standardize purok values
  String _standardizePurok(String purok) {
    if (purok.isEmpty) return 'PUROK 1'; // Default value

    // Convert to uppercase and trim
    purok = purok.trim().toUpperCase();

    // Handle variations
    if (purok.contains('COMMERCIAL')) return 'COMMERCIAL';
    if (purok.contains('NON') && purok.contains('RESIDENCE'))
      return 'NON-RESIDENCE';
    if (purok.contains('INDUSTRIAL')) return 'INDUSTRIAL';

    // Handle purok numbers
    final regex = RegExp(r'PUROK\s*(\d+)');
    final match = regex.firstMatch(purok);
    if (match != null) {
      final number = match.group(1);
      return 'PUROK $number';
    }

    // If it's already one of our options, return it
    if (_purokOptions.contains(purok)) return purok;

    // Default to PUROK 1
    return 'PUROK 1';
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
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
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
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person,
                          size: 30, color: Color.fromARGB(255, 58, 56, 56)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome!',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _meterReaderName,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Meter Reader',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    // Residents Billing
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: Material(
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.people_outline,
                            color: Colors.blue.shade700,
                            size: 22,
                          ),
                          title: Text(
                            'Residents Billing',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: true,
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minLeadingWidth: 32,
                        ),
                      ),
                    ),

                    // Report Illegal Tapping
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: Material(
                        color: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.warning,
                            color: Colors.red.shade700,
                            size: 22,
                          ),
                          title: Text(
                            'Report Illegal Tapping',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                            maxLines: 2,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const IllegalTappingReportPage(),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minLeadingWidth: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ListTile(
                  leading:
                      const Icon(Icons.logout, color: Colors.red, size: 20),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _logout,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minLeadingWidth: 32,
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
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: Colors.grey.shade500, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search residents...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear,
                          size: 16, color: Colors.grey.shade500),
                      onPressed: () => _searchController.clear(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // Purok Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPurok,
                    icon: Icon(Icons.filter_list, color: Colors.blue.shade700),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    isExpanded: true,
                    onChanged: _onPurokChanged,
                    items: _purokOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Resident Count and Filter Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_filteredResidents.length} resident${_filteredResidents.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (_selectedPurok != 'All Puroks')
                      Text(
                        'Filter: $_selectedPurok',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                if (_filteredResidents.isNotEmpty)
                  Text(
                    'Page ${_currentPage + 1}/$_totalPages',
                    style: GoogleFonts.inter(
                      fontSize: 13,
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
                              horizontal: 12, vertical: 8),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty || _selectedPurok != 'All Puroks'
                  ? Icons.people_outline
                  : Icons.search_off,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty && _selectedPurok == 'All Puroks'
                  ? 'No residents found'
                  : _searchQuery.isNotEmpty
                      ? 'No results found for "$_searchQuery"'
                      : 'No residents in $_selectedPurok',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _selectedPurok != 'All Puroks') ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  _onPurokChanged('All Puroks');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
          const SizedBox(width: 4),
          // Page numbers
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(_totalPages, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() => _currentPage = index);
                },
                child: Container(
                  width: 32,
                  height: 32,
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
                      fontSize: 12,
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
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            color: _currentPage < _totalPages - 1
                ? Colors.blue
                : Colors.grey.shade400,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
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
    final purok = widget.resident['purok'] ?? 'No Purok';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.blue[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        purok,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _isChecking
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.blue,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _hasBills
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _hasBills
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                            ),
                          ),
                          child: Text(
                            _hasBills ? 'Has Bills' : 'No Bills',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _hasBills
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          ),
                        ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 28,
                    ),
                    child: ElevatedButton(
                      onPressed: widget.onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _hasBills ? 'Update' : 'Create',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
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

    if (currentReading < _previousReading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: Current reading must be greater than or equal to previous reading (${_previousReading.toStringAsFixed(2)} m³)',
            style: GoogleFonts.inter(fontSize: 12),
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
        'recordedByName': recordedByName,
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
      height: MediaQuery.of(context).size.height * 0.85,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.water_drop, color: Colors.blue[700], size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Water Bill',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.resident['fullName'],
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Purok Dropdown moved here
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPurok,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF4A90E2), size: 20),
                        style: const TextStyle(
                          fontSize: 13,
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
                            child: Text(value,
                                style: const TextStyle(fontSize: 13)),
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
                padding: const EdgeInsets.all(12),
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
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        margin: EdgeInsets.zero,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(12.0),
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
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.water_drop,
                                          color: Colors.blue[700],
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'San Jose Water Services',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Sajowasa',
                                            style: TextStyle(
                                              fontSize: 9,
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
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A90E2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _selectedPurok,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'WATER BILL STATEMENT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A90E2),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _dashedDivider(),
                              _receiptRow(
                                  'Name', widget.resident['fullName'] ?? 'N/A'),
                              _receiptRow('Address',
                                  widget.resident['address'] ?? 'N/A'),
                              _receiptRow('Contact',
                                  widget.resident['contactNumber'] ?? 'N/A'),

                              // Meter Number Input
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

                              // Billing Period Start
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
                                            size: 12,
                                            color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
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

                              // Billing Period Due
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

                              // Current Reading Input
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
                                    const SizedBox(width: 6),
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

                              if (currentReading < _previousReading &&
                                  currentReading > 0)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
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
                                            size: 14),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '⚠️ Warning: Current reading (${currentReading.toStringAsFixed(2)} m³) is lower than previous reading (${_previousReading.toStringAsFixed(2)} m³).',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
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
                                  fontSize: 12),
                              _receiptRow('Due Date',
                                  DateFormat('MM-dd-yyyy').format(_periodDue),
                                  valueColor: dueColor),
                              if (isOverdue)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber,
                                          color: Colors.red, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Bill will be overdue',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showRates = !_showRates),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 10),
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4A90E2),
                                        ),
                                      ),
                                      Icon(
                                        _showRates
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 14,
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _rateRow('Residential',
                                          'Min 10 m³ = 30.00 PHP\nExceed = 5.00 PHP/m³'),
                                      const SizedBox(height: 4),
                                      _rateRow('Commercial',
                                          'Min 10 m³ = 75.00 PHP\nExceed = 10.00 PHP/m³'),
                                      const SizedBox(height: 4),
                                      _rateRow('Non Residence',
                                          'Min 10 m³ = 100.00 PHP\nExceed = 10.00 PHP/m³'),
                                      const SizedBox(height: 4),
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
                              const SizedBox(height: 10),
                              const Text(
                                'Ensure timely payment to maintain uninterrupted water supply.',
                                style: TextStyle(
                                  fontSize: 8,
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
                        const SizedBox(height: 12),
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error,
                                    color: Colors.red[700], size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                        color: Colors.red[700], fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submitReading,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save, size: 18),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'SAVE WATER BILL',
                                      style: TextStyle(
                                        fontSize: 14,
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

// NEW: Illegal Tapping Report Page (replaces the modal dialog)
class IllegalTappingReportPage extends StatefulWidget {
  const IllegalTappingReportPage({super.key});

  @override
  State<IllegalTappingReportPage> createState() =>
      _IllegalTappingReportPageState();
}

class _IllegalTappingReportPageState extends State<IllegalTappingReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  String _locationName = '';
  String _type = 'Unauthorized Connection';
  String _description = '';
  String _evidenceNotes = '';
  LatLng? _selectedLocation;
  List<dynamic> _imageFiles = [];
  bool _isUploading = false;
  String? _errorMessage;

  // FIXED: Use CartoDB tile provider which is more reliable and follows usage policies
  final String _mapTileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  final List<String> _tileSubdomains = ['a', 'b', 'c'];

  @override
  void dispose() {
    super.dispose();
  }

  // Platform-aware image handling
  Future<List<String>> _convertImagesToBase64(List<dynamic> imageFiles) async {
    final List<String> base64Images = [];

    for (final imageFile in imageFiles) {
      try {
        if (kIsWeb) {
          // For web: use html.File
          final html.File webFile = imageFile;
          final reader = html.FileReader();

          final completer = Completer<void>();
          reader.onLoad.listen((event) {
            completer.complete();
          });

          reader.readAsDataUrl(webFile);
          await completer.future;

          final dataUrl = reader.result as String;
          final commaIndex = dataUrl.indexOf(',');
          final base64Data = dataUrl.substring(commaIndex + 1);
          base64Images.add(base64Data);
        } else {
          // For mobile: use File
          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);
          base64Images.add(base64Image);
        }
      } catch (e) {
        print('Error encoding image: $e');
      }
    }

    return base64Images;
  }

  // Web-specific file picker
  Future<List<html.File>?> _pickImagesWeb() async {
    final input = html.FileUploadInputElement();
    input
      ..multiple = true
      ..accept = 'image/*'
      ..click();

    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      return input.files!.toList();
    }
    return null;
  }

  // Web-specific camera access
  Future<html.File?> _takePhotoWeb() async {
    final input = html.FileUploadInputElement();
    input
      ..accept = 'image/*'
      ..click();

    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      return input.files!.first;
    }
    return null;
  }

  // Image preview widget
  Widget _buildImagePreview(
      dynamic imageFile, int index, VoidCallback onRemove) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 100,
        maxHeight: 100,
        minWidth: 100,
        minHeight: 100,
      ),
      child: Container(
        margin: EdgeInsets.only(
          right: index < 9 ? 8 : 0,
        ),
        child: Stack(
          children: [
            FutureBuilder<String?>(
              future: kIsWeb
                  ? () async {
                      try {
                        final html.File webFile = imageFile;
                        return html.Url.createObjectUrlFromBlob(webFile);
                      } catch (e) {
                        return null;
                      }
                    }()
                  : Future.value(null),
              builder: (context, snapshot) {
                if (kIsWeb && snapshot.hasData) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      snapshot.data!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 30,
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      imageFile,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 30,
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.red),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Image selection methods
  Future<void> _pickImages() async {
    try {
      if (kIsWeb) {
        final images = await _pickImagesWeb();
        if (images != null && images.isNotEmpty) {
          final newImages = images.take(10 - _imageFiles.length).toList();
          setState(() {
            _imageFiles.addAll(newImages);
            _errorMessage = null;
          });
        }
      } else {
        final List<XFile>? images = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (images != null && images.isNotEmpty) {
          final newImages = images.take(10 - _imageFiles.length).toList();
          final newFiles = images
              .take(10 - _imageFiles.length)
              .map((xfile) => XFile(xfile.path))
              .toList();
          setState(() {
            _imageFiles.addAll(newFiles);
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking images: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      if (kIsWeb) {
        final photo = await _takePhotoWeb();
        if (photo != null) {
          setState(() {
            if (_imageFiles.length < 10) {
              _imageFiles.add(photo);
            } else {
              _errorMessage = 'Maximum 10 images allowed';
            }
          });
        }
      } else {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            if (_imageFiles.length < 10) {
              _imageFiles.add(image);
            } else {
              _errorMessage = 'Maximum 10 images allowed';
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error taking photo: $e';
      });
    }
  }

  void removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  void _clearAllImages() {
    setState(() {
      _imageFiles.clear();
    });
  }

  Widget _selectedImagesPreview() {
    if (_imageFiles.isEmpty) return const SizedBox.shrink();

    return Container(
        margin: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Selected Images (${_imageFiles.length}/10):',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_imageFiles.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 30,
                    ),
                    child: TextButton.icon(
                      onPressed: _clearAllImages,
                      icon:
                          const Icon(Icons.delete, size: 14, color: Colors.red),
                      label: Text(
                        'Clear All',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 100,
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _imageFiles.length,
                itemBuilder: (context, index) {
                  return _buildImagePreview(
                    _imageFiles[index],
                    index,
                    () => removeImage(index),
                  );
                },
              ),
            ),
          ],
        ));
  }

  // Map location picker dialog
  Future<LatLng?> _showMapLocationPicker(BuildContext context) async {
    LatLng selectedLocation =
        const LatLng(13.294678436001885, 123.75569591912894);
    MapController mapController = MapController();

    return showDialog<LatLng>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '📍 Select Tap Location',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                            color: Colors.grey.shade600,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Map Area
                    Expanded(
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: selectedLocation,
                              initialZoom: 16,
                              minZoom: 13,
                              maxZoom: 19,
                              interactionOptions: const InteractionOptions(
                                flags: ~InteractiveFlag.rotate,
                              ),
                              onTap: (tapPosition, latLng) {
                                setState(() {
                                  selectedLocation = latLng;
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: _mapTileUrl,
                                subdomains: _tileSubdomains,
                                userAgentPackageName: 'com.example.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: selectedLocation,
                                    width: 60,
                                    height: 60,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_pin,
                                        color: Colors.red,
                                        size: 40,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Location Info
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info,
                                          color: Colors.blue.shade600,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Tap anywhere on the map to select location',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.green.shade600,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Location Selected',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                              Text(
                                                'Lat: ${selectedLocation.latitude.toStringAsFixed(6)}\nLng: ${selectedLocation.longitude.toStringAsFixed(6)}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade700,
                                                ),
                                                maxLines: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom Controls
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Row(
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 40,
                                    ),
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        mapController.move(
                                          const LatLng(13.294678436001885,
                                              123.75569591912894),
                                          16,
                                        );
                                      },
                                      icon: Icon(Icons.my_location,
                                          color: Colors.blue.shade700,
                                          size: 16),
                                      label: Text(
                                        'Center Map',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        side: BorderSide(
                                            color: Colors.blue.shade300),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 40,
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(
                                            context, selectedLocation);
                                      },
                                      icon: const Icon(Icons.check, size: 16),
                                      label: Text(
                                        'Confirm',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Zoom Controls
                          Positioned(
                            right: 8,
                            bottom: 60,
                            child: Column(
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  child: FloatingActionButton.small(
                                    heroTag: 'zoom_in',
                                    onPressed: () {
                                      mapController.move(
                                        mapController.camera.center,
                                        mapController.camera.zoom + 1,
                                      );
                                    },
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.blue.shade700,
                                    child: const Icon(Icons.add, size: 18),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  child: FloatingActionButton.small(
                                    heroTag: 'zoom_out',
                                    onPressed: () {
                                      mapController.move(
                                        mapController.camera.center,
                                        mapController.camera.zoom - 1,
                                      );
                                    },
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.blue.shade700,
                                    child: const Icon(Icons.remove, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate() && _selectedLocation != null) {
      _formKey.currentState!.save();
      setState(() => _isUploading = true);

      try {
        // Get meter reader info
        User? user = FirebaseAuth.instance.currentUser;
        String reportedByName = 'Unknown Meter Reader';
        String reportedByEmail = 'unknown@email.com';

        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data();
          reportedByName = userData?['fullName'] ?? 'Unknown';
          reportedByEmail = user.email ?? 'unknown@email.com';
        }

        // Convert images to base64
        final base64Images = await _convertImagesToBase64(_imageFiles);

        final reportData = {
          'fullName': reportedByName,
          'issueDescription': 'ILLEGAL TAPPING: $_description',
          'placeName': _locationName,
          'location': GeoPoint(
            _selectedLocation!.latitude,
            _selectedLocation!.longitude,
          ),
          'status': 'Illegal Tapping',
          'isIllegalTapping': true,
          'illegalTappingType': _type,
          'evidenceNotes': _evidenceNotes,
          'evidenceImages': base64Images,
          'priority': 'high',
          'requiresInvestigation': true,
          'createdAt': FieldValue.serverTimestamp(),
          'reportedByMeterReader': true,
          'reportedBy': reportedByEmail,
          'reportedByName': reportedByName,
          'assignedPlumber': null,
          'hasEvidence': base64Images.isNotEmpty,
          'imageCount': base64Images.length,
        };

        await FirebaseFirestore.instance.collection('reports').add(reportData);

        // Show success message and go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Illegal tapping report submitted successfully!',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        setState(() => _isUploading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                  'Please select a location and fill all required fields'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Report Illegal Tapping',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Report suspected illegal water tapping activities',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.red.shade800,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Location Field
              Text(
                'Location',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),

              // Location Selection
              if (_selectedLocation == null)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final location = await _showMapLocationPicker(context);
                        if (location != null) {
                          setState(() {
                            _selectedLocation = location;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Select Location on Map'),
                    ),
                  ),
                ),

              if (_selectedLocation != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location Selected',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          final location =
                              await _showMapLocationPicker(context);
                          if (location != null) {
                            setState(() {
                              _selectedLocation = location;
                            });
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Location Name
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 70,
                ),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Location Name / Address *',
                    hintText: 'Enter exact address or landmark',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  onSaved: (value) => _locationName = value ?? '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter location name';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Type of Illegal Activity - FIXED: Changed text color to black
              Text(
                'Type of Illegal Activity *',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 60,
                ),
                child: DropdownButtonFormField(
                  value: _type,
                  items: [
                    DropdownMenuItem(
                      value: 'Unauthorized Connection',
                      child: Text('Unauthorized Connection',
                          style: TextStyle(
                              color: Colors.black)), // FIXED: Black text
                    ),
                    DropdownMenuItem(
                      value: 'Meter Tampering/Bypass',
                      child: Text('Meter Tampering/Bypass',
                          style: TextStyle(
                              color: Colors.black)), // FIXED: Black text
                    ),
                    DropdownMenuItem(
                      value: 'Pipe Diversion',
                      child: Text('Pipe Diversion',
                          style: TextStyle(
                              color: Colors.black)), // FIXED: Black text
                    ),
                    DropdownMenuItem(
                      value: 'Other Illegal Activity',
                      child: Text('Other Illegal Activity',
                          style: TextStyle(
                              color: Colors.black)), // FIXED: Black text
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _type = value!);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black, // FIXED: Black text
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Description
              Text(
                'Description *',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 120,
                ),
                child: TextFormField(
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Detailed description',
                    hintText: 'Describe what you observed...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  onSaved: (value) => _description = value ?? '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Evidence Photos
              Text(
                'Evidence Photos',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload clear photos as evidence (Max 10)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: _imageFiles.length < 10 ? _pickImages : null,
                        icon: Icon(Icons.photo_library, size: 18),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: _imageFiles.length < 10 ? _takePhoto : null,
                        icon: Icon(Icons.camera_alt, size: 18),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Display selected images
              _selectedImagesPreview(),

              const SizedBox(height: 20),

              // Additional Notes (Optional)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 100,
                ),
                child: TextFormField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    hintText: 'Witness info, time, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  onSaved: (value) => _evidenceNotes = value ?? '',
                ),
              ),

              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isUploading
                      ? SizedBox(
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
                            const Icon(Icons.send, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Submit Illegal Tapping Report',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Required fields note
              Center(
                child: Text(
                  '* Required fields',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
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
