import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:water_pipe_monitoring/admin/components/admin_layout.dart';

class MonitorPage extends StatefulWidget {
  final String? reportId;

  const MonitorPage({super.key, this.reportId});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  OverlayEntry? _errorOverlay;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _userReports = [];
  int _currentReportIndex = 0;
  bool _hasShownInitialModal = false;

  // Light blue color palette
  static const Color primaryBlue = Color(0xFF90CAF9);
  static const Color lightBlue = Color(0xFFE3F2FD);
  // ignore: unused_field
  static const Color accentBlue = Color(0xFFBBDEFB);

  // Status-based marker colors
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Monitoring':
        return primaryBlue;
      case 'Unfixed Reports':
        return Colors.redAccent;
      case 'Fixed':
        return const Color(0xFFC18B00);
      default:
        return Colors.grey;
    }
  }

  // Format timestamp for display
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMMMMd().add_jm().format(timestamp.toDate());
    }
    return 'N/A';
  }

  // Fetch plumbers for assignment
  Future<List<Map<String, dynamic>>> _fetchPlumbers() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Plumber')
          .get();
      print('Fetched plumbers: ${querySnapshot.docs.length} documents');
      final plumbers = querySnapshot.docs
          .map((doc) => {
                'uid': doc.id,
                'fullName': doc.data()['fullName'] ?? 'Unknown Plumber'
              })
          .toList();
      print('Plumbers data: $plumbers');
      return plumbers;
    } catch (e) {
      print('Error fetching plumbers: $e');
      _showErrorOverlay('Failed to load plumbers: $e');
      return [];
    }
  }

  // Show error overlay with modern design
  void _showErrorOverlay(String message) {
    _errorOverlay?.remove();
    _errorOverlay = OverlayEntry(
      builder: (context) => Positioned(
        right: 16,
        bottom: 16,
        child: FadeOut(
          duration: const Duration(seconds: 3),
          animate: true,
          child: Material(
            color: Colors.redAccent.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
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
    Overlay.of(context).insert(_errorOverlay!);
    Future.delayed(const Duration(seconds: 3), () {
      _errorOverlay?.remove();
      _errorOverlay = null;
    });
  }

  // Fetch and show report modal - fixed to handle direct report ID
  Future<void> _fetchAndShowReportModal(String id, bool isPublic) async {
    try {
      if (isPublic) {
        // For public reports, fetch the specific report by ID
        final doc = await FirebaseFirestore.instance
            .collection('reports')
            .doc(id)
            .get();
        if (doc.exists) {
          setState(() {
            _userReports = [
              {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }
            ];
            _currentReportIndex = 0;
          });
          _showReportModal(context, _userReports[0], _userReports[0]['id']);
        } else {
          _showErrorOverlay('Report not found.');
        }
      } else {
        // For private reports, fetch all reports for this user
        final querySnapshot = await FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: id)
            .where('isPublic', isEqualTo: false)
            .where('status', isNotEqualTo: 'Fixed')
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            _userReports = querySnapshot.docs
                .map((doc) => {
                      'id': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    })
                .toList();
            _currentReportIndex = 0;
          });
          _showReportModal(context, _userReports[0], _userReports[0]['id']);
        } else {
          _showErrorOverlay('No reports found.');
        }
      }
    } catch (e) {
      print('Error fetching reports: $e');
      _showErrorOverlay('Error loading reports: $e');
    }
  }

  // Show report modal with modern design
  void _showReportModal(
      BuildContext context, Map<String, dynamic> data, String reportId) async {
    String? selectedPlumberUid = data['assignedPlumber'] as String?;
    DateTime? selectedDate = data['monitoringDate'] is Timestamp
        ? (data['monitoringDate'] as Timestamp).toDate()
        : null;
    bool isButtonDisabled = data['assignedPlumber'] != null;
    List<Map<String, dynamic>> plumbers = await _fetchPlumbers();

    void _assignPlumber() async {
      if (selectedPlumberUid == null) {
        _showErrorOverlay('Please select a plumber.');
        return;
      }
      if (selectedDate == null) {
        _showErrorOverlay('Please select a monitoring date.');
        return;
      }
      try {
        final docRef =
            FirebaseFirestore.instance.collection('reports').doc(reportId);
        final doc = await docRef.get();
        if (!doc.exists) {
          throw Exception('Report document does not exist');
        }
        await docRef.update({
          'assignedPlumber': selectedPlumberUid,
          'monitoringDate': Timestamp.fromDate(selectedDate!),
          'status': 'Monitoring',
        });
        _showErrorOverlay('Plumber assigned successfully.');
        setState(() {
          isButtonDisabled = true;
        });
        Navigator.of(context).pop();
      } catch (e) {
        print('Error assigning plumber: $e');
        _showErrorOverlay('Failed to assign plumber: $e');
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Report Details',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.grey, size: 24),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: primaryBlue,
                              backgroundImage: data['avatarUrl'] != null &&
                                      data['avatarUrl'] is String
                                  ? NetworkImage(data['avatarUrl'] as String)
                                  : null,
                              child: data['avatarUrl'] == null ||
                                      data['avatarUrl'] is! String
                                  ? Text(
                                      (data['fullName'] ?? 'Unknown')[0],
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['fullName'] ?? 'Unknown',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['contactNumber'] ?? 'No contact',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(data['createdAt']),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  if (data['isPublic'])
                                    const SizedBox(height: 4),
                                  if (data['isPublic'])
                                    Text(
                                      'Public Report',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (data['image'] != null &&
                            data['image'] is String &&
                            (data['image'] as String).isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(data['image'] as String),
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                padding: const EdgeInsets.all(12),
                                alignment: Alignment.center,
                                height: 160,
                                color: lightBlue,
                                child: Text(
                                  'Unable to load image',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          data['issueDescription'] ?? 'No issue description',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        if (data['isPublic'] &&
                            data['additionalLocationInfo'] != null)
                          const SizedBox(height: 12),
                        if (data['isPublic'] &&
                            data['additionalLocationInfo'] != null)
                          Text(
                            'Additional Location Info: ${data['additionalLocationInfo']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Chip(
                          label: Text(
                            data['status'] ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor:
                              _getStatusColor(data['status'] ?? 'Unknown'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        if (!data['isPublic'] &&
                            data['assignedPlumber'] != null)
                          const SizedBox(height: 12),
                        if (!data['isPublic'] &&
                            data['assignedPlumber'] != null)
                          Text(
                            'Assigned: ${plumbers.firstWhere(
                              (p) => p['uid'] == data['assignedPlumber'],
                              orElse: () => {'fullName': 'Unknown'},
                            )['fullName']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (!data['isPublic']) const SizedBox(height: 16),
                        if (!data['isPublic'])
                          const Divider(height: 1, color: Colors.grey),
                        if (!data['isPublic']) const SizedBox(height: 16),
                        if (!data['isPublic'])
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Assign Plumber',
                                    labelStyle: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                    filled: true,
                                    fillColor: lightBlue,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: primaryBlue, width: 1.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 1),
                                    ),
                                  ),
                                  value: selectedPlumberUid,
                                  dropdownColor: Colors.white,
                                  items: plumbers.isNotEmpty
                                      ? plumbers.map((plumber) {
                                          return DropdownMenuItem<String>(
                                            value: plumber['uid'],
                                            child: Text(
                                              plumber['fullName'],
                                              style: GoogleFonts.poppins(
                                                  fontSize: 14),
                                            ),
                                          );
                                        }).toList()
                                      : [
                                          DropdownMenuItem<String>(
                                            value: null,
                                            child: Text(
                                              'No plumbers available',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                  onChanged: plumbers.isNotEmpty
                                      ? (value) {
                                          setDialogState(() {
                                            selectedPlumberUid = value;
                                            isButtonDisabled = false;
                                          });
                                        }
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Monitoring Date',
                                    labelStyle: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                    filled: true,
                                    fillColor: lightBlue,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: primaryBlue, width: 1.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.grey, width: 1),
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.calendar_today,
                                      color: primaryBlue,
                                      size: 20,
                                    ),
                                  ),
                                  controller: TextEditingController(
                                    text: selectedDate != null
                                        ? DateFormat.yMMMd()
                                            .format(selectedDate!)
                                        : '',
                                  ),
                                  onTap: () async {
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          selectedDate ?? DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                              primary: primaryBlue,
                                              onPrimary: Colors.white,
                                              onSurface: Colors.black87,
                                            ),
                                            textButtonTheme:
                                                TextButtonThemeData(
                                              style: TextButton.styleFrom(
                                                foregroundColor: primaryBlue,
                                              ),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (pickedDate != null) {
                                      setDialogState(() {
                                        selectedDate = pickedDate;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        if (!data['isPublic']) const SizedBox(height: 16),
                        if (!data['isPublic'])
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  isButtonDisabled ? null : _assignPlumber,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isButtonDisabled
                                    ? Colors.grey[400]
                                    : primaryBlue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: isButtonDisabled ? 0 : 4,
                                shadowColor: Colors.black26,
                              ),
                              child: Text(
                                isButtonDisabled
                                    ? 'Plumber Assigned'
                                    : (data['assignedPlumber'] != null
                                        ? 'Re-assign Plumber'
                                        : 'Assign Plumber'),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (!data['isPublic'] && _userReports.length > 1)
                          const SizedBox(height: 16),
                        if (!data['isPublic'] && _userReports.length > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(Icons.chevron_left,
                                    color: _currentReportIndex > 0
                                        ? primaryBlue
                                        : Colors.grey),
                                onPressed: _currentReportIndex > 0
                                    ? () {
                                        setDialogState(() {
                                          _currentReportIndex--;
                                          data =
                                              _userReports[_currentReportIndex];
                                          reportId =
                                              _userReports[_currentReportIndex]
                                                  ['id'];
                                          selectedPlumberUid =
                                              data['assignedPlumber']
                                                  as String?;
                                          selectedDate = data['monitoringDate']
                                                  is Timestamp
                                              ? (data['monitoringDate']
                                                      as Timestamp)
                                                  .toDate()
                                              : null;
                                          isButtonDisabled =
                                              data['assignedPlumber'] != null;
                                        });
                                      }
                                    : null,
                              ),
                              Text(
                                '${_currentReportIndex + 1}/${_userReports.length}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.chevron_right,
                                    color: _currentReportIndex <
                                            _userReports.length - 1
                                        ? primaryBlue
                                        : Colors.grey),
                                onPressed: _currentReportIndex <
                                        _userReports.length - 1
                                    ? () {
                                        setDialogState(() {
                                          _currentReportIndex++;
                                          data =
                                              _userReports[_currentReportIndex];
                                          reportId =
                                              _userReports[_currentReportIndex]
                                                  ['id'];
                                          selectedPlumberUid =
                                              data['assignedPlumber']
                                                  as String?;
                                          selectedDate = data['monitoringDate']
                                                  is Timestamp
                                              ? (data['monitoringDate']
                                                      as Timestamp)
                                                  .toDate()
                                              : null;
                                          isButtonDisabled =
                                              data['assignedPlumber'] != null;
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FirebaseAuth.instance.currentUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    
    // Only show modal once when navigating with a reportId
    if (widget.reportId != null && 
        widget.reportId!.isNotEmpty && 
        !_hasShownInitialModal) {
      _hasShownInitialModal = true;
      
      // Use Future.delayed to ensure the widget tree is built
      Future.delayed(Duration.zero, () {
        FirebaseFirestore.instance
            .collection('reports')
            .doc(widget.reportId)
            .get()
            .then((doc) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            // ignore: unused_local_variable
            final isPublic = data['isPublic'] ?? false;
            
            // For direct report view, always show just this report
            setState(() {
              _userReports = [
                {
                  'id': doc.id,
                  ...data,
                }
              ];
              _currentReportIndex = 0;
            });
            
            _showReportModal(context, _userReports[0], doc.id);
          } else {
            _showErrorOverlay('Report not found.');
          }
        }).catchError((error) {
          print('Error loading report: $error');
          _showErrorOverlay('Error loading report: $error');
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController.move(
              const LatLng(13.294678436001885, 123.75569591912894), 16);
        },
        backgroundColor: primaryBlue,
        child: const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Reset Map',
      ),
      body: AdminLayout(
        title: 'Monitor Reports',
        selectedRoute: '/monitor',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reports')
                        .where('status', isNotEqualTo: 'Fixed')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('StreamBuilder error: ${snapshot.error}');
                        return Center(
                          child: Text(
                            'Error loading reports',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                            child:
                                CircularProgressIndicator(color: primaryBlue));
                      }

                      // Group reports by userId for private reports
                      final userReports =
                          <String, List<Map<String, dynamic>>>{};
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final userId = data['userId'] as String?;
                        final isPublic = data['isPublic'] ?? false;
                        if (userId != null) {
                          if (!isPublic) {
                            userReports.putIfAbsent(userId, () => []).add({
                              'id': doc.id,
                              ...data,
                            });
                          } else {
                            userReports[doc.id] = [
                              {'id': doc.id, ...data}
                            ]; // Treat public reports individually
                          }
                        }
                      }

                      final markers = userReports.entries
                          .map((entry) {
                            final reports = entry.value;
                            final data = reports[0];
                            final location = data['location'];
                            final isPublic = data['isPublic'] ?? false;
                            final status = data['status'] ?? 'Unknown';
                            if (location == null || location is! GeoPoint) {
                              return null;
                            }

                            return Marker(
                              point:
                                  LatLng(location.latitude, location.longitude),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _fetchAndShowReportModal(
                                    entry.key, isPublic),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isPublic
                                            ? Colors.red
                                            : _getStatusColor(status),
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                    isPublic
                                        ? const Icon(
                                            Icons.warning,
                                            color: Colors.white,
                                            size: 20,
                                          )
                                        : Text(
                                            (data['fullName'] ?? 'Unknown')[0],
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .whereType<Marker>()
                          .toList();

                      markers.add(
                        Marker(
                          point: const LatLng(
                              13.294678436001885, 123.75569591912894),
                          width: 140,
                          height: 40,
                          child: Text(
                            'San Jose',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue[900],
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );

                      return FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(
                              13.294678436001885, 123.75569591912894),
                          initialZoom: 16,
                          minZoom: 15,
                          maxZoom: 18,
                          initialCameraFit: CameraFit.bounds(
                            bounds: LatLngBounds(
                              const LatLng(
                                  13.292678436001885, 123.75369591912894),
                              const LatLng(
                                  13.296678436001885, 123.75769591912894),
                            ),
                            padding: const EdgeInsets.all(50),
                          ),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.doubleTapZoom &
                                ~InteractiveFlag.flingAnimation,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.app',
                            maxNativeZoom: 19,
                            maxZoom: 19,
                            errorTileCallback: (tile, error, stackTrace) {
                              print('Tile loading error: $error');
                              _showErrorOverlay('Failed to load map tiles.');
                            },
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      );
                    },
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'San Jose Water Services',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '© OpenStreetMap',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _errorOverlay?.remove();
    _mapController.dispose();
    super.dispose();
  }
}