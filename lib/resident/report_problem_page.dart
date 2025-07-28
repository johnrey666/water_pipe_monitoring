import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  latlong.LatLng? _selectedLocation;
  String? _selectedPlaceName;
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();
  MapController? _mapController;
  DateTime? _selectedDateTime;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    final permission = sdkInt >= 33 ? Permission.photos : Permission.storage;
    final status = await permission.request();

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access gallery')),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1'),
        headers: {'User-Agent': 'WaterPipeMonitoring/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final placeName = data[0]['display_name'];
          setState(() {
            _selectedLocation = latlong.LatLng(lat, lon);
            _selectedPlaceName = placeName;
            _locationController.text = placeName;
          });
          print(
              'Searched location: $_selectedLocation, Place: $_selectedPlaceName');
          if (_mapController != null) {
            _mapController!.move(_selectedLocation!, 14);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found')),
          );
        }
      } else {
        throw Exception('Failed to search location: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    }
  }

  Future<String> _getPlaceName(latlong.LatLng position) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json'),
        headers: {'User-Agent': 'WaterPipeMonitoring/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          _selectedDateTime = selectedDateTime;
          _dateTimeController.text =
              '${selectedDateTime.toLocal().toString().substring(0, 16)}';
        });
      }
    }
  }

  Future<Map<String, String>?> _getUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) {
        throw Exception('User data not found');
      }
      return {
        'userId': user.uid,
        'fullName': userDoc.data()?['fullName'] ?? 'Unknown',
        'contact': userDoc.data()?['contact'] ?? 'Unknown',
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user info: $e')),
      );
      return null;
    }
  }

  Future<String?> _convertImageToBase64(XFile? imageFile) async {
    if (imageFile == null) return null;
    try {
      final bytes = await File(imageFile.path).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error encoding image: $e')),
      );
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userInfo = await _getUserInfo();
      if (userInfo == null) {
        throw Exception('Failed to fetch user info');
      }

      final reportData = {
        'userId': userInfo['userId'],
        'fullName': userInfo['fullName'],
        'contact': userInfo['contact'],
        'issueDescription': _issueController.text,
        'location': GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        'placeName': _selectedPlaceName ?? 'Unknown location',
        'dateTime': Timestamp.fromDate(_selectedDateTime!),
        'createdAt': Timestamp.now(),
      };

      // Optionally include base64 image
      final base64Image = await _convertImageToBase64(_imageFile);
      if (base64Image != null) {
        reportData['image'] = base64Image;
      }

      await FirebaseFirestore.instance.collection('reports').add(reportData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      // Clear form
      setState(() {
        _issueController.clear();
        _locationController.clear();
        _dateTimeController.clear();
        _imageFile = null;
        _selectedLocation = null;
        _selectedPlaceName = null;
        _selectedDateTime = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting report: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _onMapCreated(MapController controller) {
    _mapController = controller;
    if (_selectedLocation != null) {
      _mapController!.move(_selectedLocation!, 14);
    }
    print('Map created, controller initialized');
  }

  void _openMapPicker() {
    latlong.LatLng initial = _selectedLocation ??
        const latlong.LatLng(13.1486, 123.7156); // Daraga, Albay
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, modalSetState) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Location',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Daraga, Albay',
                    suffixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _searchLocation(value);
                      modalSetState(() {});
                    }
                  },
                ),
              ),
              Expanded(
                child: FlutterMap(
                  mapController: _mapController ??= MapController(),
                  options: MapOptions(
                    initialCenter: initial,
                    initialZoom: 14,
                    onTap: (tapPosition, position) async {
                      final placeName = await _getPlaceName(position);
                      modalSetState(() {
                        _selectedLocation = position;
                        _selectedPlaceName = placeName;
                      });
                      print(
                          'Tapped location: $_selectedLocation, Place: $_selectedPlaceName');
                      _mapController?.move(position, 14);
                    },
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture && _selectedLocation != null) {
                        modalSetState(() {
                          _selectedLocation = position.center;
                        });
                        print('Marker dragged to: $_selectedLocation');
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.water_pipe_monitoring',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onPanUpdate: (details) async {
                                final newPosition =
                                    _mapController!.camera.center;
                                final placeName =
                                    await _getPlaceName(newPosition);
                                modalSetState(() {
                                  _selectedLocation = newPosition;
                                  _selectedPlaceName = placeName;
                                });
                                print(
                                    'Marker dragged to: $_selectedLocation, Place: $_selectedPlaceName');
                              },
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedLocation != null) {
                      setState(() {
                        _locationController.text = _selectedPlaceName ?? '';
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A2C6F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirm Location',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _issueController.dispose();
    _locationController.dispose();
    _dateTimeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Report a Water Issue',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        const Text('Please provide details below:',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _issueController,
                          decoration: const InputDecoration(
                            labelText: 'Issue Description *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          readOnly: true,
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.map),
                            hintText: 'Tap to select or search location',
                          ),
                          onTap: _openMapPicker,
                          validator: (value) =>
                              _selectedLocation == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          readOnly: true,
                          controller: _dateTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Date & Time *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                            hintText: 'Tap to select date and time',
                          ),
                          onTap: _selectDateTime,
                          validator: (value) =>
                              _selectedDateTime == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Upload Image (Optional)',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.image),
                                ),
                                controller: TextEditingController(
                                    text: _imageFile?.name ?? ''),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _pickImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A2C6F),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Upload',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white)),
                            ),
                          ],
                        ),
                        if (_imageFile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_imageFile!.path),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.center,
                          child: Text('Fields marked with * are required',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Submit Report',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: const Color(0xFF4A2C6F),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Submit',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white)),
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
    );
  }
}
