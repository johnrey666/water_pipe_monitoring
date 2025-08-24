import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewReportsPage extends StatefulWidget {
  final String? initialReportId;

  const ViewReportsPage({super.key, this.initialReportId});

  @override
  State<ViewReportsPage> createState() => _ViewReportsPageState();
}

class _ViewReportsPageState extends State<ViewReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _publicPage = 1;
  int _monitoringPage = 1;
  int _fixedPage = 1;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialReportId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showReportModal(widget.initialReportId!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showReportModal(String reportId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .get();
      if (doc.exists && mounted) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.white,
            child: ReportDetailsModal(report: doc),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report not found.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: SafeArea(
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            flexibleSpace: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF87CEEB),
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: const Color(0xFF87CEEB),
              indicatorWeight: 3,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              labelStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Public Reports'),
                Tab(text: 'Monitoring'),
                Tab(text: 'Fixed'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildReportList(
                user.uid,
                null, // No status filter for public reports
                _publicPage,
                (page) => setState(() => _publicPage = page),
                isPublic: true,
              ),
              _buildReportList(
                user.uid,
                ['Unfixed Reports', 'Monitoring'],
                _monitoringPage,
                (page) => setState(() => _monitoringPage = page),
              ),
              _buildReportList(
                user.uid,
                ['Fixed'],
                _fixedPage,
                (page) => setState(() => _fixedPage = page),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportList(String userId, List<String>? statuses,
      int currentPage, Function(int) onPageChange,
      {bool isPublic = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: isPublic
          ? FirebaseFirestore.instance
              .collection('reports')
              .where('isPublic', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('reports')
              .where('assignedPlumber', isEqualTo: userId)
              .where('status', whereIn: statuses)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading reports: ${snapshot.error}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF87CEEB),
            ),
          );
        }

        final reports = snapshot.data!.docs;
        if (reports.isEmpty) {
          return Center(
            child: Text(
              'No reports available.',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        final totalPages = (reports.length / _pageSize).ceil();
        final startIndex = (currentPage - 1) * _pageSize;
        final endIndex = (startIndex + _pageSize).clamp(0, reports.length);
        final paginatedReports = reports.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: paginatedReports.length,
                itemBuilder: (context, index) {
                  final report = paginatedReports[index];
                  final fullName = report['fullName']?.toString() ?? '';
                  final issueDescription =
                      report['issueDescription']?.toString() ?? '';
                  final createdAt = report['createdAt'] is Timestamp
                      ? (report['createdAt'] as Timestamp).toDate()
                      : null;
                  final formattedDate = createdAt != null
                      ? DateFormat.yMMMd().format(createdAt)
                      : 'Unknown date';

                  return FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                      color: Colors.white,
                      shadowColor: Colors.black.withOpacity(0.05),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        title: Text(
                          fullName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              issueDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE3F2FD),
                            foregroundColor: const Color(0xFF87CEEB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFFBBDEFB)),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            minimumSize: const Size(90, 40),
                            elevation: 0,
                          ),
                          onPressed: () => _showReportModal(report.id),
                          child: Text(
                            'View',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF87CEEB),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageButton(
                      label: 'Previous',
                      onPressed: currentPage > 1
                          ? () => onPageChange(currentPage - 1)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$currentPage / $totalPages',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildPageButton(
                      label: 'Next',
                      onPressed: currentPage < totalPages
                          ? () => onPageChange(currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPageButton(
      {required String label, required VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF87CEEB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color:
                onPressed != null ? const Color(0xFFBBDEFB) : Colors.grey[300]!,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onPressed != null ? const Color(0xFF87CEEB) : Colors.grey[500],
        ),
      ),
    );
  }
}

class ReportDetailsModal extends StatefulWidget {
  final DocumentSnapshot report;

  const ReportDetailsModal({super.key, required this.report});

  @override
  State<ReportDetailsModal> createState() => _ReportDetailsModalState();
}

class _ReportDetailsModalState extends State<ReportDetailsModal> {
  bool _showLocation = false;
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .update({'status': newStatus});

      if (newStatus == 'Fixed') {
        final reportData = widget.report.data() as Map<String, dynamic>;
        final residentId = reportData['userId']?.toString();
        final issueDescription =
            reportData['issueDescription']?.toString() ?? 'Water issue';
        if (residentId != null) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'residentId': residentId,
            'type': 'report_status',
            'message':
                'Your reported issue: "$issueDescription" has been marked as Fixed.',
            'status': 'fixed',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report marked as $newStatus')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportData = widget.report.data() as Map<String, dynamic>;
    final fullName = reportData['fullName']?.toString() ?? '';
    final contactNumber = reportData['contactNumber']?.toString() ?? '';
    final issueDescription = reportData['issueDescription']?.toString() ?? '';
    final placeName = reportData['placeName']?.toString() ?? '';
    final additionalLocationInfo =
        reportData['additionalLocationInfo']?.toString();
    final dateTime = reportData['createdAt'] is Timestamp
        ? (reportData['createdAt'] as Timestamp).toDate()
        : null;
    final location = reportData['location'] as GeoPoint?;
    final imageBase64 = reportData['image']?.toString();
    final currentStatus = reportData['status']?.toString() ?? 'Unfixed Reports';

    final formattedDate = dateTime != null
        ? DateFormat.yMMMd().add_jm().format(dateTime)
        : 'Unknown';

    Uint8List? imageBytes;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } catch (_) {}
    }

    latlong.LatLng? mapLocation;
    if (location != null) {
      mapLocation = latlong.LatLng(location.latitude, location.longitude);
    }

    return FadeIn(
      duration: const Duration(milliseconds: 300),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE3F2FD), width: 1),
                ),
              ),
              child: Row(
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
                        color: Colors.black54, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFE3F2FD),
                          child: reportData['avatarUrl'] != null &&
                                  reportData['avatarUrl'] is String
                              ? CachedNetworkImage(
                                  imageUrl: reportData['avatarUrl'],
                                  placeholder: (context, url) => const Icon(
                                    Icons.person,
                                    color: Color(0xFF87CEEB),
                                    size: 24,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                    Icons.person,
                                    color: Color(0xFF87CEEB),
                                    size: 24,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Color(0xFF87CEEB),
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contactNumber,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              if (reportData['isPublic'] == true)
                                const SizedBox(height: 4),
                              if (reportData['isPublic'] == true)
                                Text(
                                  'Public Report',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (imageBase64 != null && imageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          imageBytes,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 140,
                            color: const Color(0xFFE3F2FD),
                            child: Center(
                              child: Text(
                                'Unable to load image',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      issueDescription,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    if (reportData['isPublic'] == true &&
                        additionalLocationInfo != null &&
                        additionalLocationInfo.isNotEmpty)
                      const SizedBox(height: 12),
                    if (reportData['isPublic'] == true &&
                        additionalLocationInfo != null &&
                        additionalLocationInfo.isNotEmpty)
                      Text(
                        'Additional Location Info: $additionalLocationInfo',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showLocation = !_showLocation;
                        });
                      },
                      child: Text(
                        _showLocation ? 'Hide Location' : 'View Location',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF87CEEB),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor:
                              const Color(0xFF87CEEB).withOpacity(0.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_showLocation && mapLocation != null)
                      FadeIn(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE3F2FD)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: mapLocation,
                                initialZoom: 14,
                                minZoom: 13,
                                maxZoom: 16,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                  userAgentPackageName:
                                      'WaterPipeMonitoring/1.0 (contact@yourdomain.com)',
                                  tileProvider: CachedTileProvider(),
                                  errorTileCallback: (tile, error, stackTrace) {
                                    if (error.toString().contains('403')) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Access blocked by OpenStreetMap. Please contact support or check your internet.'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: mapLocation,
                                      width: 32,
                                      height: 32,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Color(0xFF87CEEB),
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                                const Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Text(
                                    '© OpenStreetMap contributors',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_showLocation && mapLocation == null)
                      Text(
                        'No location data available',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      placeName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    if (currentStatus != 'Fixed') const SizedBox(height: 16),
                    if (currentStatus != 'Fixed')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _isUpdating ? null : () => _updateStatus('Fixed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF87CEEB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: _isUpdating
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : Text(
                                  'Mark as Fixed',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    const SizedBox(height: 8),
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

class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheKey: '${coordinates.x}_${coordinates.y}_${coordinates.z}',
    );
  }
}
