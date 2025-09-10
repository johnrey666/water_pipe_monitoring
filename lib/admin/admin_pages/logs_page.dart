import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../components/admin_layout.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  int _currentPage = 0;
  final int _pageSize = 5;
  String _selectedType = 'All';
  Map<String, List<DocumentSnapshot?>> _lastDocuments = {
    'All': [null],
    'Accounts': [null],
    'Reports': [null],
    'Bills': [null],
  };
  Map<String, int> _totalPages = {
    'All': 1,
    'Accounts': 1,
    'Reports': 1,
    'Bills': 1,
  };
  bool _isLoading = false;

  Color _getTypeColor(String type) {
    switch (type) {
      case 'accounts':
        return const Color(0xFF2F8E2F); // Green for Accounts
      case 'reports':
        return const Color(0xFFD94B3B); // Red for Reports
      case 'bills':
        return const Color(0xFFC18B00); // Yellow for Bills
      default:
        return Colors.grey;
    }
  }

  Future<void> _fetchTotalPages(String type) async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance.collectionGroup('log');
      if (type != 'All') {
        query = query.where('log_type', isEqualTo: type.toLowerCase());
      }
      final snapshot = await query.get();
      final totalDocs = snapshot.docs.length;
      print('Fetched $totalDocs logs for type: $type');
      setState(() {
        _totalPages[type] = (totalDocs / _pageSize).ceil();
        _lastDocuments[type] = List.filled(_totalPages[type]!, null);
      });
    } catch (e) {
      print('Error fetching total pages for $type: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Stream<QuerySnapshot> _getLogsStream() {
    Query query = FirebaseFirestore.instance
        .collectionGroup('log')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_selectedType != 'All') {
      query = query.where('log_type', isEqualTo: _selectedType.toLowerCase());
    }

    if (_currentPage > 0 &&
        _lastDocuments[_selectedType]![_currentPage - 1] != null) {
      query = query.startAfterDocument(
          _lastDocuments[_selectedType]![_currentPage - 1]!);
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
          children: List.generate(_totalPages[_selectedType]!, (i) {
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
          onPressed: _currentPage < _totalPages[_selectedType]! - 1 &&
                  !_isLoading
              ? () {
                  setState(() {
                    _currentPage++;
                    if (_currentPage >= _lastDocuments[_selectedType]!.length) {
                      _lastDocuments[_selectedType]!.add(null);
                    }
                  });
                }
              : null,
          child: Text(
            'Next',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _currentPage < _totalPages[_selectedType]! - 1
                  ? const Color(0xFF4FC3F7)
                  : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String type) {
    final isSelected = _selectedType == type;
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () {
              setState(() {
                _selectedType = type;
                _currentPage = 0;
                _lastDocuments[type] = [
                  null
                ]; // Reset pagination for new filter
                _fetchTotalPages(type);
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
      child: Text(type),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterButton('All'),
                    _buildFilterButton('Accounts'),
                    _buildFilterButton('Reports'),
                    _buildFilterButton('Bills'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getLogsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('StreamBuilder error: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error loading logs: ${snapshot.error}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {
                                  _currentPage = 0;
                                  _lastDocuments[_selectedType] = [null];
                                  _fetchTotalPages(_selectedType);
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4FC3F7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final logs = snapshot.data?.docs ?? [];
                      print(
                          'Fetched ${logs.length} logs for type: $_selectedType, page: $_currentPage');

                      if (logs.isEmpty) {
                        return Center(
                          child: Text(
                            _selectedType == 'All'
                                ? 'No logs found.'
                                : 'No $_selectedType logs found.',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }

                      if (logs.isNotEmpty) {
                        if (_currentPage >=
                            _lastDocuments[_selectedType]!.length) {
                          _lastDocuments[_selectedType]!.add(logs.last);
                        } else {
                          _lastDocuments[_selectedType]![_currentPage] =
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
                                final data = log.data() as Map<String, dynamic>;
                                final fullName = data['fullName'] ?? 'Unknown';
                                final email = data['email'] ?? 'No email';
                                final description =
                                    data['description'] ?? 'No description';
                                final createdAt = data['createdAt']?.toDate();
                                final type = data['log_type'] ?? 'Unknown';
                                final formattedDate = createdAt != null
                                    ? DateFormat.yMMMd().format(createdAt)
                                    : 'Unknown date';

                                return FadeInUp(
                                  duration: const Duration(milliseconds: 300),
                                  child: Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    shadowColor: Colors.black12,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 60,
                                            color: _getTypeColor(type),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.circle,
                                                      size: 10,
                                                      color:
                                                          _getTypeColor(type),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        fullName,
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors
                                                              .grey.shade800,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  email,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  description,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  '$type • $formattedDate',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
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
