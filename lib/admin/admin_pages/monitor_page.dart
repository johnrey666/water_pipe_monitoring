import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../components/admin_layout.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
// ignore: unused_import
import 'dart:typed_data';

class MonitorPage extends StatelessWidget {
  const MonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Monitor',
      selectedRoute: '/monitor',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('reports').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading reports'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final markers = snapshot.data!.docs
                  .map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final location = data['location'];
                    final fullName = data['fullName'] ?? 'Unknown';
                    final avatarUrl = data['avatarUrl'];
                    final imageBase64 = data['image'];

                    if (location == null || location is! GeoPoint) return null;

                    return Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 150,
                      height: 70,
                      child: GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) => Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Dialog(
                                backgroundColor: Colors.white,
                                elevation: 8,
                                insetPadding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: Colors.blueAccent,
                                            backgroundImage:
                                                avatarUrl != null &&
                                                        avatarUrl is String
                                                    ? NetworkImage(avatarUrl)
                                                    : null,
                                            child: avatarUrl == null ||
                                                    avatarUrl is! String
                                                ? const Icon(Icons.person,
                                                    color: Colors.white,
                                                    size: 28)
                                                : null,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fullName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  data['contact'] ??
                                                      'No contact',
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatTimestamp(
                                                      data['dateTime']),
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      if (imageBase64 != null &&
                                          imageBase64 is String &&
                                          imageBase64.isNotEmpty)
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.memory(
                                            base64Decode(imageBase64),
                                            width: double.infinity,
                                            height: 180,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                              padding: const EdgeInsets.all(16),
                                              alignment: Alignment.center,
                                              height: 180,
                                              color: Colors.grey[100],
                                              child: const Text(
                                                  'Unable to load image'),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          data['issueDescription'] ??
                                              'No issue description',
                                          style: const TextStyle(fontSize: 15),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Chip(
                                          label: Text(
                                            data['status'] ?? 'Unknown',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          backgroundColor: Colors.green.shade50,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26, blurRadius: 2),
                                ],
                              ),
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                    fontSize: 9.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 30,
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .whereType<Marker>()
                  .toList();

              return FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(13.1486, 123.7156),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMMMMd().add_jm().format(timestamp.toDate());
    }
    return 'N/A';
  }
}
