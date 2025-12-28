import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';

class GeographicMappingPage extends StatefulWidget {
  const GeographicMappingPage({super.key});

  @override
  State<GeographicMappingPage> createState() => _GeographicMappingPageState();
}

class _GeographicMappingPageState extends State<GeographicMappingPage> {
  OverlayEntry? _errorOverlay;
  List<Map<String, dynamic>> _userReports = [];
  int _currentReportIndex = 0;

  void _showErrorOverlay(String message) {
    _errorOverlay?.remove();
    _errorOverlay = OverlayEntry(
      builder: (context) => Positioned(
        right: 16,
        bottom: 16,
        child: FadeOut(
          duration: const Duration(seconds: 5),
          animate: true,
          child: Material(
            elevation: 4,
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
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
    Future.delayed(const Duration(seconds: 5), () {
      _errorOverlay?.remove();
      _errorOverlay = null;
    });
  }

  void _showReportDialog(
      BuildContext context, List<Map<String, dynamic>> reports) {
    _userReports = reports;
    _currentReportIndex = 0;
    _showModal(context, _userReports[0], _userReports[0]['id']);
  }

  // Widget to display images in a carousel
  Widget _buildImageCarousel(
      List<String> base64Images, String issueDescription) {
    if (base64Images.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 40, color: Colors.grey.shade500),
              const SizedBox(height: 8),
              Text(
                'No images attached',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: base64Images.length,
          options: CarouselOptions(
            height: 180,
            aspectRatio: 16 / 9,
            viewportFraction: 0.8,
            initialPage: 0,
            enableInfiniteScroll: base64Images.length > 1,
            reverse: false,
            autoPlay: base64Images.length > 1,
            autoPlayInterval: const Duration(seconds: 3),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            enlargeFactor: 0.3,
            scrollDirection: Axis.horizontal,
          ),
          itemBuilder: (context, index, realIndex) {
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(base64Images[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image,
                                size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Image ${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        if (base64Images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Swipe to view ${base64Images.length} images',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Widget for single image display
  Widget _buildSingleImage(String base64Image, String issueDescription) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(base64Image),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image,
                        size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Image not available',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showModal(
      BuildContext context, Map<String, dynamic> data, String reportId) {
    bool isUpdating = false;

    Future<void> updateStatus(
        String newStatus, void Function(VoidCallback) setDialogState) async {
      if (isUpdating) return;
      setDialogState(() {
        isUpdating = true;
      });

      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({'status': newStatus});

        if (newStatus == 'Fixed') {
          final residentId = data['userId']?.toString();
          final issueDescription =
              data['issueDescription']?.toString() ?? 'Water issue';
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report marked as $newStatus')),
        );
        Navigator.pop(context);
      } catch (e) {
        print('Error updating status: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      } finally {
        setDialogState(() {
          isUpdating = false;
        });
      }
    }

    // Get images data
    final imageCount = data['imageCount'] ?? 0;
    final images = (data['images'] as List<dynamic>?)?.cast<String>() ?? [];
    final hasImages = images.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => FadeIn(
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.of(context).size.height * 0.80,
              ),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.white,
                elevation: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom:
                              BorderSide(color: Colors.grey.shade300, width: 1),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFE3F2FD),
                                  child: data['avatarUrl'] != null &&
                                          data['avatarUrl'] is String
                                      ? CachedNetworkImage(
                                          imageUrl: data['avatarUrl'],
                                          placeholder: (context, url) =>
                                              const Icon(
                                            Icons.person,
                                            color: Color(0xFF0288D1),
                                            size: 28,
                                          ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                            Icons.person,
                                            color: Color(0xFF0288D1),
                                            size: 28,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: Color(0xFF0288D1),
                                          size: 28,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['fullName'] ?? 'Unknown',
                                        style: GoogleFonts.poppins(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        data['contactNumber'] ?? 'No contact',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTimestamp(data['createdAt']),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (data['isPublic'] == true)
                                        const SizedBox(height: 4),
                                      if (data['isPublic'] == true)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Public Report',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Location information
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFBBDEFB)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Location',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['placeName'] ??
                                              'Unknown location',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.blue.shade700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Images section
                            if (hasImages)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 18,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Attached Images ($imageCount)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  images.length == 1
                                      ? _buildSingleImage(images[0],
                                          data['issueDescription'] ?? '')
                                      : _buildImageCarousel(images,
                                          data['issueDescription'] ?? ''),
                                  const SizedBox(height: 16),
                                ],
                              ),

                            const SizedBox(height: 16),

                            // Issue description
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.report_problem_outlined,
                                        size: 16,
                                        color: Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Issue Description',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    data['issueDescription'] ??
                                        'No description',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (data['isPublic'] == true &&
                                data['additionalLocationInfo'] != null &&
                                data['additionalLocationInfo'].isNotEmpty)
                              const SizedBox(height: 12),
                            if (data['isPublic'] == true &&
                                data['additionalLocationInfo'] != null &&
                                data['additionalLocationInfo'].isNotEmpty)
                              Text(
                                'Additional Location Info: ${data['additionalLocationInfo']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Status chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    _getStatusColor(data['status'] ?? 'Unknown')
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(
                                          data['status'] ?? 'Unknown')
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getStatusColor(
                                          data['status'] ?? 'Unknown'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    data['status'] ?? 'Unknown',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(
                                          data['status'] ?? 'Unknown'),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Fix button for non-fixed reports
                            if (data['status'] != 'Fixed')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isUpdating
                                      ? null
                                      : () =>
                                          updateStatus('Fixed', setDialogState),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0288D1),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    elevation: 2,
                                    shadowColor: Colors.black.withOpacity(0.1),
                                  ),
                                  child: isUpdating
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Mark as Fixed',
                                              style: GoogleFonts.poppins(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                            // Navigation for multiple reports
                            if (_userReports.length > 1)
                              const SizedBox(height: 16),
                            if (_userReports.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.chevron_left,
                                        color: _currentReportIndex > 0
                                            ? const Color(0xFF0288D1)
                                            : Colors.grey.shade400,
                                      ),
                                      onPressed: _currentReportIndex > 0
                                          ? () {
                                              setDialogState(() {
                                                _currentReportIndex--;
                                                data = _userReports[
                                                    _currentReportIndex];
                                                reportId = _userReports[
                                                    _currentReportIndex]['id'];
                                                isUpdating = false;
                                              });
                                            }
                                          : null,
                                    ),
                                    Text(
                                      'Report ${_currentReportIndex + 1} of ${_userReports.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.chevron_right,
                                        color: _currentReportIndex <
                                                _userReports.length - 1
                                            ? const Color(0xFF0288D1)
                                            : Colors.grey.shade400,
                                      ),
                                      onPressed: _currentReportIndex <
                                              _userReports.length - 1
                                          ? () {
                                              setDialogState(() {
                                                _currentReportIndex++;
                                                data = _userReports[
                                                    _currentReportIndex];
                                                reportId = _userReports[
                                                    _currentReportIndex]['id'];
                                                isUpdating = false;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'monitoring':
        return Colors.green.shade600;
      case 'unfixed reports':
        return Colors.red.shade600;
      case 'fixed':
        return Colors.amber.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMMMMd().add_jm().format(timestamp.toDate());
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .where('status', isNotEqualTo: 'Fixed')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showErrorOverlay(
                          'Error loading reports: ${snapshot.error}');
                    });
                    return Center(
                      child: Text(
                        'Error loading reports',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Group reports by location
                  final locationReports =
                      <String, List<Map<String, dynamic>>>{};
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isPublic = data['isPublic'] == true;
                    final isAssigned = data['assignedPlumber'] == user.uid;
                    if (isPublic || isAssigned) {
                      final location = data['location'] as GeoPoint?;
                      if (location != null) {
                        final locationKey =
                            '${location.latitude},${location.longitude}';
                        locationReports.putIfAbsent(locationKey, () => []).add({
                          'id': doc.id,
                          ...data,
                        });
                      }
                    }
                  }

                  final markers = locationReports.entries
                      .map((entry) {
                        final reports = entry.value;
                        final data = reports[0];
                        final location = data['location'] as GeoPoint?;
                        final isPublic = data['isPublic'] == true;
                        if (location == null) return null;

                        return Marker(
                          point: LatLng(location.latitude, location.longitude),
                          width: 60,
                          height: 60,
                          child: GestureDetector(
                            onTap: () => _showReportDialog(context, reports),
                            child: ZoomIn(
                              duration: const Duration(milliseconds: 300),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isPublic
                                          ? Colors.red.shade600
                                          : _getStatusColor(data['status'] ??
                                              'Unfixed Reports'),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  isPublic
                                      ? const Icon(
                                          Icons.warning,
                                          color: Colors.white,
                                          size: 24,
                                        )
                                      : CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.white,
                                          child: Text(
                                            (data['fullName'] ?? 'U')[0]
                                                .toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(
                                                  data['status'] ??
                                                      'Unfixed Reports'),
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        );
                      })
                      .whereType<Marker>()
                      .toList();

                  markers.add(
                    Marker(
                      point:
                          const LatLng(13.294678436001885, 123.75569591912894),
                      width: 140,
                      height: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'San Jose',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );

                  return FlutterMap(
                    options: MapOptions(
                      initialCenter:
                          const LatLng(13.294678436001885, 123.75569591912894),
                      initialZoom: 16,
                      minZoom: 15,
                      maxZoom: 18,
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds(
                          const LatLng(13.292678436001885, 123.75369591912894),
                          const LatLng(13.296678436001885, 123.75769591912894),
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
                        userAgentPackageName:
                            'WaterPipeMonitoring/1.0 (contact@yourdomain.com)',
                        tileProvider: CachedTileProvider(),
                        errorTileCallback: (tile, error, stackTrace) {
                          if (error.toString().contains('403')) {
                            _showErrorOverlay(
                                'Access blocked by OpenStreetMap.');
                          } else {
                            _showErrorOverlay(
                                'Failed to load map tiles. Check your internet.');
                          }
                        },
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  );
                },
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assigned Reports',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Icon(
                          Icons.map_outlined,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Scale: ~100m',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
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

class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheKey: '${coordinates.x}_${coordinates.y}_${coordinates.z}',
    );
  }
}
