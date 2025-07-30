import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../components/admin_layout.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  int _currentPage = 0;
  final int _pageSize = 5;
  String _selectedRole = 'All';
  DocumentSnapshot? _lastDocument;

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'plumber':
        return const Color(0xFF2F8E2F);
      case 'resident':
        return const Color(0xFF0288D1);
      default:
        return Colors.grey;
    }
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  Stream<QuerySnapshot> _getUsersStream() {
    Query query = FirebaseFirestore.instance.collection('users');

    if (_selectedRole == 'All') {
      query = query.where('role', whereIn: ['plumber', 'resident']);
    } else {
      query = query.where('role', isEqualTo: _selectedRole.toLowerCase());
    }

    query = query.orderBy('createdAt', descending: true).limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Users',
      selectedRoute: '/users',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Residents and Plumbers',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildFilterButton('All'),
                const SizedBox(width: 8),
                _buildFilterButton('Plumber'),
                const SizedBox(width: 8),
                _buildFilterButton('Resident'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Error loading users',
                        style: TextStyle(fontSize: 16, color: Colors.redAccent),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data?.docs ?? [];

                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedRole == 'All'
                            ? 'No Plumbers or Residents found.'
                            : 'No $_selectedRole users found.',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  DocumentSnapshot? newLastDocument;
                  if (users.isNotEmpty) {
                    newLastDocument = users.last;
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final fullName = user['fullName'] ?? 'Unknown';
                            final email = user['email'] ?? 'No email';
                            final contact = user['contactNumber'] ??
                                user['contact'] ??
                                'No contact';
                            final address = user['address'] ?? 'No address';
                            final role = (user['role'] ?? 'Unknown').toString();
                            final createdAtRaw = user['createdAt'];
                            final formattedDate = createdAtRaw is Timestamp
                                ? DateFormat.yMMMd()
                                    .format(createdAtRaw.toDate())
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
                                        height: 80,
                                        color: _getRoleColor(role),
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
                                                  color: _getRoleColor(role),
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
                                              email,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              contact,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              address,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${_capitalize(role)} • $formattedDate',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _currentPage > 0
                                ? () {
                                    setState(() {
                                      _currentPage--;
                                      _lastDocument = null;
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
                            onPressed: users.length == _pageSize &&
                                    newLastDocument != null
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                      _lastDocument = newLastDocument;
                                    });
                                  }
                                : null,
                            child: Text(
                              'Next',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: users.length == _pageSize &&
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

  Widget _buildFilterButton(String role) {
    final isSelected = _selectedRole == role;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedRole = role;
          _currentPage = 0;
          _lastDocument = null;
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
      child: Text(role),
    );
  }
}
