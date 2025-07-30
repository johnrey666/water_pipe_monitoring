import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../components/admin_layout.dart';
import 'package:intl/intl.dart';

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

                    if (location == null || location is! GeoPoint) return null;

                    return Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 200,
                      height: 60,
                      child: GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Report Details'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.blueAccent,
                                        backgroundImage: avatarUrl != null &&
                                                avatarUrl is String
                                            ? NetworkImage(avatarUrl)
                                            : null,
                                        child: avatarUrl == null ||
                                                avatarUrl is! String
                                            ? const Icon(Icons.person,
                                                color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          fullName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text("Contact: ${data['contact'] ?? 'N/A'}"),
                                  Text("Status: ${data['status'] ?? 'N/A'}"),
                                  const SizedBox(height: 8),
                                  Text("Place: ${data['placeName'] ?? 'N/A'}"),
                                  const SizedBox(height: 8),
                                  Text(
                                      "Issue: ${data['issueDescription'] ?? 'N/A'}"),
                                  const SizedBox(height: 8),
                                  Text(
                                      "Reported: ${_formatTimestamp(data['createdAt'])}"),
                                  Text(
                                      "Incident Time: ${_formatTimestamp(data['dateTime'])}"),
                                  if (data['image'] != null &&
                                      data['image'] is String)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          data['image'],
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 36,
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
