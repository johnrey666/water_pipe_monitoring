import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../components/admin_layout.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  int _currentPage = 0;
  final int _pageSize = 10;
  String _selectedFilter = 'All';
  Map<String, List<DocumentSnapshot?>> _lastDocuments = {
    'All': [null],
    'Accounts': [null],
    'Bills': [null],
    'Reports': [null],
  };
  Map<String, int> _totalPages = {
    'All': 1,
    'Accounts': 1,
    'Bills': 1,
    'Reports': 1,
  };
  bool _isLoading = false;

  Color _getLogColor(String action) {
    final normalizedAction = action.trim();
    switch (normalizedAction) {
      case 'New User Created':
        return const Color(0xFF2F8E2F); // Green for Accounts
      case 'Payment Accepted':
        return const Color(0xFF4FC3F7); // Blue for Bills
      case 'Report Fixed':
        return const Color(0xFFC18B00); // Orange for Reports
      default:
        return Colors.grey;
    }
  }

  IconData _getLogIcon(String action) {
    final normalizedAction = action.trim();
    switch (normalizedAction) {
      case 'New User Created':
        return Icons.person_add;
      case 'Payment Accepted':
        return Icons.payment;
      case 'Report Fixed':
        return Icons.report_problem;
      default:
        return Icons.info;
    }
  }

  Future<void> _fetchTotalPages(String filter) async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance.collection('logs');
      if (filter != 'All') {
        final actions = _getFilterActions(filter);
        if (actions.isNotEmpty) {
          if (actions.length == 1) {
            query = query.where('action', isEqualTo: actions.first);
          } else {
            query = query.where('action', whereIn: actions);
          }
        }
      }
      final snapshot = await query.get();
      final totalDocs = snapshot.docs.length;
      setState(() {
        _totalPages[filter] = (totalDocs / _pageSize).ceil().clamp(1, 999);
        while (_lastDocuments[filter]!.length < _totalPages[filter]!) {
          _lastDocuments[filter]!.add(null);
        }
      });
    } catch (e) {
      print('LogsPage: Error fetching total pages for $filter: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> _getFilterActions(String filter) {
    switch (filter) {
      case 'Accounts':
        return ['New User Created'];
      case 'Bills':
        return ['Payment Accepted'];
      case 'Reports':
        return ['Report Fixed'];
      default:
        return [];
    }
  }

  Stream<QuerySnapshot> _getLogsStream() {
    Query query = FirebaseFirestore.instance
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (_selectedFilter != 'All') {
      final actions = _getFilterActions(_selectedFilter);
      if (actions.isNotEmpty) {
        if (actions.length == 1) {
          query = query.where('action', isEqualTo: actions.first);
        } else {
          query = query.where('action', whereIn: actions);
        }
      }
    }

    if (_currentPage > 0 &&
        _lastDocuments[_selectedFilter]![_currentPage - 1] != null) {
      query = query.startAfterDocument(
          _lastDocuments[_selectedFilter]![_currentPage - 1]!);
    }

    return query.snapshots();
  }

  Widget _buildPaginationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _currentPage > 0 && !_isLoading
              ? () => setState(() => _currentPage--)
              : null,
          child: Text(
            'Previous',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _currentPage > 0 ? const Color(0xFF4FC3F7) : Colors.grey,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalPages[_selectedFilter]!, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                onPressed:
                    _isLoading ? null : () => setState(() => _currentPage = i),
                style: TextButton.styleFrom(
                  backgroundColor: _currentPage == i
                      ? const Color(0xFF4FC3F7)
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
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
        TextButton(
          onPressed:
              _currentPage < _totalPages[_selectedFilter]! - 1 && !_isLoading
                  ? () {
                      setState(() {
                        _currentPage++;
                        if (_currentPage >=
                            _lastDocuments[_selectedFilter]!.length) {
                          _lastDocuments[_selectedFilter]!.add(null);
                        }
                      });
                    }
                  : null,
          child: Text(
            'Next',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _currentPage < _totalPages[_selectedFilter]! - 1
                  ? const Color(0xFF4FC3F7)
                  : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () {
              setState(() {
                _selectedFilter = filter;
                _currentPage = 0;
                _fetchTotalPages(filter);
              });
            },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFF4FC3F7) : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.grey.shade800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(filter),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchTotalPages('All');
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Activity Logs',
      selectedRoute: '/logs',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Activity Logs',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterButton('All'),
                    _buildFilterButton('Accounts'),
                    _buildFilterButton('Bills'),
                    _buildFilterButton('Reports'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getLogsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading logs: ${snapshot.error}',
                            style: GoogleFonts.poppins(color: Colors.redAccent),
                          ),
                        );
                      }
                      final logs = snapshot.data?.docs ?? [];
                      if (logs.isEmpty) {
                        return Center(
                          child: Text(
                            _selectedFilter == 'All'
                                ? 'No logs available'
                                : 'No $_selectedFilter logs available',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }

                      if (logs.isNotEmpty) {
                        if (_currentPage >=
                            _lastDocuments[_selectedFilter]!.length) {
                          _lastDocuments[_selectedFilter]!.add(logs.last);
                        } else {
                          _lastDocuments[_selectedFilter]![_currentPage] =
                              logs.last;
                        }
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: logs.length,
                              itemBuilder: (context, index) {
                                final log = logs[index];
                                final timestamp =
                                    (log['timestamp'] as Timestamp?)?.toDate();
                                final formattedTime = timestamp != null
                                    ? DateFormat('MMM dd, yyyy - HH:mm:ss')
                                        .format(timestamp)
                                    : 'Unknown';
                                final details = log['details']?.toString() ??
                                    'Unknown action';
                                final action = log['action']?.toString() ?? '';

                                return Card(
                                  elevation: 2,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 60,
                                          color: _getLogColor(action),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          _getLogIcon(action),
                                          size: 24,
                                          color: _getLogColor(action),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                details,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 16,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Date Created: $formattedTime',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
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
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
