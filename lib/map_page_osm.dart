import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class OSMMapPage extends StatefulWidget {
  const OSMMapPage({super.key});

  @override
  State<OSMMapPage> createState() => _OSMMapPageState();
}

class _OSMMapPageState extends State<OSMMapPage> {
  final MapController _mapController = MapController();

  Position? _currentPosition;
  LatLng? _destination;
  List<LatLng> _polylinePoints = [];

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  // 🔑 Replace with your OpenRouteService API key
  final String orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjY2MjRmYzgwZjBkNjQxZDRhNjdkZjU4ZWVkOThkNTY2IiwiaCI6Im11cm11cjY0In0=';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = pos;
    });

    _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
  }

  Future<List<LatLng>> fetchRoute(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${origin.longitude},${origin.latitude}&end=${destination.longitude},${destination.latitude}',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['features'][0]['geometry']['coordinates'] as List;
      return coords
          .map((point) => LatLng(point[1] as double, point[0] as double))
          .toList();
    } else {
      throw Exception('Failed to fetch route: ${response.body}');
    }
  }

  void _setDestination(LatLng dest) async {
    if (_currentPosition == null) return;

    setState(() {
      _destination = dest;
      _polylinePoints = [];
    });

    final origin = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    try {
      final route = await fetchRoute(origin, dest);
      setState(() {
        _polylinePoints = route;
      });

      // Fit bounds
      final bounds = LatLngBounds.fromPoints([origin, dest]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching route: $e')));
      }
    }
  }

  void _setDestinationFromInputs() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return;
    _setDestination(LatLng(lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(-26.2041, 28.0473); // fallback

    final markers = <Marker>[
      if (_currentPosition != null)
        Marker(
          width: 40,
          height: 40,
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          child: const Icon(Icons.my_location, size: 32),
        ),
      if (_destination != null)
        Marker(
          width: 40,
          height: 40,
          point: _destination!,
          child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
        ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPos, point) {
                _setDestination(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      color: Colors.blue,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Top controls
          Positioned(
            top: 40,
            left: 12,
            right: 12,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Set destination',
                      onPressed: _setDestinationFromInputs,
                      icon: const Icon(Icons.check_circle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _initLocation,
        label: const Text('My location'),
        icon: const Icon(Icons.gps_fixed),
      ),
    );
  }
}
