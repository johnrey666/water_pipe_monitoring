import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  OverlayEntry? _successOverlay;

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
      query = query.where('role', whereIn: ['Plumber', 'Resident']);
    } else {
      query = query.where('role', isEqualTo: _selectedRole);
    }

    query = query.orderBy('createdAt', descending: true).limit(_pageSize);

    if (_lastDocument != null && _currentPage > 0) {
      query = query.startAfterDocument(_lastDocument!);
    }

    return query.snapshots();
  }

  Future<void> _deleteUser(String userId, String email) async {
    try {
      // Delete from Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      // Show success overlay immediately after Firestore deletion
      _showSuccessOverlay('User Successfully deleted!');

      // Delete from Firebase Authentication
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        List<String> signInMethods =
            await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (signInMethods.isNotEmpty) {
          // Attempt to delete the user; requires admin privileges or re-auth
          try {
            User? userToDelete = await FirebaseAuth.instance.currentUser!.uid ==
                    userId
                ? currentUser
                : null; // Only delete self directly; otherwise, need admin SDK
            if (userToDelete != null) {
              await userToDelete.delete();
              _successOverlay?.remove();
              _showSuccessOverlay('User deleted successfully!');
            } else {
              // This is a placeholder; client-side can't delete other users without re-auth or admin SDK
              throw FirebaseAuthException(
                code: 'permission-denied',
                message:
                    'Cannot delete other users. Use Admin SDK or set admin claims.',
              );
            }
          } catch (authError) {
            print('Auth deletion error: $authError');
            _successOverlay?.remove();
            _showSuccessOverlay(
                'Deleted from Firestore only. Authentication failed. Ensure admin privileges.');
            return;
          }
        }
      }
    } catch (e) {
      print('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e. Check admin setup.')),
      );
    }
  }

  void _showSuccessOverlay(String message) {
    _successOverlay?.remove();
    _successOverlay = OverlayEntry(
      builder: (context) => Positioned(
        right: 16,
        bottom: 16,
        child: FadeOut(
          duration: const Duration(seconds: 5),
          animate: true,
          child: Material(
            color: Colors.green.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_successOverlay!);
    Future.delayed(const Duration(seconds: 3), () {
      _successOverlay?.remove();
      _successOverlay = null;
    });
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
                    print('StreamBuilder error: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error loading users: ${snapshot.error}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.redAccent,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {
                              _currentPage = 0;
                              _lastDocument = null;
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A2C6F),
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

                  final users = snapshot.data?.docs ?? [];
                  print(
                      'Fetched users roles: ${users.map((doc) => doc['role']).toList()}');

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

                  _lastDocument = users.isNotEmpty ? users.last : null;

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final userId = user.id;
                            final fullName = user['fullName'] ?? 'Unknown';
                            final email = user['email'] ?? 'No email';
                            final contact = user['contactNumber'] ??
                                user['contactNumber'] ??
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
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _showDeleteConfirmationDialog(
                                                userId, email),
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
                                    _lastDocument != null
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                    });
                                  }
                                : null,
                            child: Text(
                              'Next',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: users.length == _pageSize &&
                                        _lastDocument != null
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

  void _showDeleteConfirmationDialog(String userId, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete',
            style:
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500)),
        content: Text('Are you sure you want to delete $email?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFF4A2C6F))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteUser(userId, email);
            },
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
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
