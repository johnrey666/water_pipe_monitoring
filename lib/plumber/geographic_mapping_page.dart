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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => FadeIn(
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom:
                              BorderSide(color: Color(0xFFE0E0E0), width: 1),
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
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFE3F2FD),
                                  child: data['avatarUrl'] != null &&
                                          data['avatarUrl'] is String
                                      ? CachedNetworkImage(
                                          imageUrl: data['avatarUrl'],
                                          placeholder: (context, url) =>
                                              const Icon(
                                            Icons.person,
                                            color: Color(0xFF0288D1),
                                            size: 26,
                                          ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                            Icons.person,
                                            color: Color(0xFF0288D1),
                                            size: 26,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: Color(0xFF0288D1),
                                          size: 26,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTimestamp(data['createdAt']),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (data['isPublic'] == true)
                                        const SizedBox(height: 4),
                                      if (data['isPublic'] == true)
                                        Text(
                                          'Public Report',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (data['image'] != null &&
                                data['image'] is String &&
                                (data['image'] as String).isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(data['image'] as String),
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 120,
                                    color: const Color(0xFFE3F2FD),
                                    child: Center(
                                      child: Text(
                                        'Unable to load image',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              data['issueDescription'] ?? 'No description',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            if (data['isPublic'] == true &&
                                data['additionalLocationInfo'] != null &&
                                data['additionalLocationInfo'].isNotEmpty)
                              const SizedBox(height: 8),
                            if (data['isPublic'] == true &&
                                data['additionalLocationInfo'] != null &&
                                data['additionalLocationInfo'].isNotEmpty)
                              Text(
                                'Additional Location Info: ${data['additionalLocationInfo']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            const SizedBox(height: 8),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: _getStatusColor(
                                          data['status'] ?? 'Unknown')
                                      .withOpacity(0.3),
                                ),
                              ),
                              elevation: 1,
                            ),
                            const SizedBox(height: 12),
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    elevation: 1,
                                  ),
                                  child: isUpdating
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
                            if (_userReports.length > 1)
                              const SizedBox(height: 12),
                            if (_userReports.length > 1)
                              Row(
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
                                    '${_currentReportIndex + 1}/${_userReports.length}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
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
