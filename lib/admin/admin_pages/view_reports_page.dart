import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../components/admin_layout.dart';
import 'monitor_page.dart';

class ViewReportsPage extends StatefulWidget {
  const ViewReportsPage({super.key});

  @override
  State<ViewReportsPage> createState() => _ViewReportsPageState();
}

class _ViewReportsPageState extends State<ViewReportsPage> {
  int _currentPage = 0;
  final int _pageSize = 5;
  String _selectedStatus = 'All'; // Default to show all reports
  // ignore: unused_field
  DocumentSnapshot? _lastDocument;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Monitoring':
        return const Color(0xFF2F8E2F);
      case 'Unfixed':
        return const Color(0xFFD94B3B);
      case 'Fixed':
        return const Color(0xC18B00);
      default:
        return Colors.grey;
    }
  }

  // Build Firestore query based on selected status
  Stream<QuerySnapshot> _getReportsStream() {
    Query query = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_selectedStatus != 'All') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    // Debug query
    query.get().then((snapshot) {
      print(
          'Query for status $_selectedStatus returned ${snapshot.docs.length} documents');
    }).catchError((error) {
      print('Query error: $error');
    });

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'View Reports',
      selectedRoute: '/reports',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterButton('All'),
                _buildFilterButton('Monitoring'),
                _buildFilterButton('Unfixed'),
                _buildFilterButton('Fixed'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getReportsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('StreamBuilder error: ${snapshot.error}');
                    return Center(
                      child: Text(
                        'Error loading reports: ${snapshot.error}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final reports = snapshot.data?.docs ?? [];

                  if (reports.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedStatus == 'All'
                            ? 'No reports found.'
                            : 'No $_selectedStatus reports found.',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  // Update _lastDocument for the next page
                  DocumentSnapshot? newLastDocument;
                  if (reports.isNotEmpty) {
                    newLastDocument = reports.last;
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: reports.length,
                          itemBuilder: (context, index) {
                            final report = reports[index];
                            final data = report.data() as Map<String, dynamic>;
                            final fullName = data['fullName'] ?? 'Unknown';
                            final issueDescription =
                                data['issueDescription'] ?? 'No description';
                            final createdAt = data['createdAt']?.toDate();
                            final status = data['status'] ?? 'Unfixed';
                            final formattedDate = createdAt != null
                                ? DateFormat.yMMMd().format(createdAt)
                                : 'Unknown date';

                            return FadeInUp(
                              duration: const Duration(milliseconds: 300),
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
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
                                        color: _getStatusColor(status),
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
                                                      _getStatusColor(status),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    fullName,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          Colors.grey.shade800,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              issueDescription,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              '$status • $formattedDate',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => MonitorPage(
                                                reportId: report.id,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'View',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: const Color(0xFF4A2C6F),
                                          ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _currentPage > 0
                                ? () {
                                    setState(() {
                                      _currentPage--;
                                      _lastDocument =
                                          null; // Reset for previous pages
                                    });
                                  }
                                : null,
                            child: Text(
                              'Previous',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _currentPage > 0
                                    ? const Color(0xFF4A2C6F)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          Text(
                            'Page ${_currentPage + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          TextButton(
                            onPressed: reports.length == _pageSize &&
                                    newLastDocument != null
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                      _lastDocument =
                                          newLastDocument; // Update for next page
                                    });
                                  }
                                : null,
                            child: Text(
                              'Next',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: reports.length == _pageSize &&
                                        newLastDocument != null
                                    ? const Color(0xFF4A2C6F)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String status) {
    final isSelected = _selectedStatus == status;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedStatus = status;
          _currentPage = 0; // Reset page when changing filter
          _lastDocument = null; // Reset document for new filter
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFF4A2C6F) : Colors.grey.shade200,
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
      child: Text(status),
    );
  }
}
