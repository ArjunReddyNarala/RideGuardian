import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../websocket/websocket_events.dart';

import '../../models/ride.dart';
import '../../services/ride_location_service.dart';
import '../../services/rides_api_service.dart';

class GuardianActiveRideScreen extends StatefulWidget {
  const GuardianActiveRideScreen({
    super.key,
    required this.ride,
    required this.ridesApiService,
  });

  final Ride ride;
  final RidesApiService ridesApiService;

  @override
  State<GuardianActiveRideScreen> createState() =>
      _GuardianActiveRideScreenState();
}

class _GuardianActiveRideScreenState
    extends State<GuardianActiveRideScreen> {
  final RideLocationService _locationService =
      RideLocationService.instance;

  GoogleMapController? _mapController;

  StreamSubscription<WebSocketMessage>?
      _messageSubscription;

  LatLng? _riderLocation;

  double _currentSpeed = 0;

  double? _speedLimit;

  bool _speedAlertEnabled = false;

  bool _isLoading = true;

  bool _isConnected = false;

  bool _rideEnded = false;

  String? _errorMessage;

  String? _speedWarning;

  @override
  void initState() {
    super.initState();

    _startMonitoring();
  }

  Future<void> _startMonitoring() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final snapshot =
          await widget.ridesApiService.getTrackingSnapshot(
        widget.ride.id,
      );

      if (!mounted) return;

      final location = snapshot['currentLocation'];

      final speedLimit = snapshot['speedLimitKmh'];

      setState(() {
        if (location is Map<String, dynamic>) {
          _riderLocation = LatLng(
            _toDouble(location['latitude']),
            _toDouble(location['longitude']),
          );

          _currentSpeed = _toDouble(
            location['speedKmh'],
          );
        }

        _speedLimit = speedLimit == null
            ? null
            : _toDouble(speedLimit);

        _speedAlertEnabled =
            snapshot['speedAlertEnabled'] == true;

        _isLoading = false;
      });

      _messageSubscription =
          _locationService.messages.listen(
        _handleMessage,
      );

      await _locationService.connectAsGuardian(
        rideId: widget.ride.id,
        backendBaseUrl: EnvConfig.backendBaseUrl,
      );

      if (!mounted) return;

      setState(() {
        _isConnected = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  void _handleMessage(WebSocketMessage message) {
    if (!mounted) return;

    switch (message.type) {
      case WebSocketEvents.connected:
        setState(() {
          _isConnected = true;
        });
        break;

      case WebSocketEvents.locationUpdate:
        final data = message.data;

        if (data == null) return;

        final latitude = _toDouble(data['latitude']);
        final longitude = _toDouble(data['longitude']);

        final speed = _toDouble(data['speedKmh']);

        setState(() {
          _riderLocation = LatLng(
            latitude,
            longitude,
          );

          _currentSpeed = speed;
        });

        _moveCamera();

        break;

      case WebSocketEvents.speedLimitExceeded:
        final data = message.data;

        if (data == null) return;

        setState(() {
          _speedWarning =
              'Speed limit exceeded! '
              'Current speed: '
              '${data['currentSpeedKmh']} km/h. '
              'Limit: ${data['speedLimitKmh']} km/h.';
        });

        break;

      case WebSocketEvents.rideEnded:
        setState(() {
          _rideEnded = true;
          _isConnected = false;
        });

        break;

      case WebSocketEvents.error:
        if (message.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.message!),
            ),
          );
        }

        break;
    }
  }

  void _moveCamera() {
    final location = _riderLocation;

    final controller = _mapController;

    if (location == null || controller == null) return;

    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLng(location),
      ).catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();

    /*
     * Disconnect only the guardian's receive-only socket.
     * Never stop the rider's tracking from this screen.
     */
    unawaited(
      _locationService.disconnectGuardian(),
    );

    _mapController = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Ride Monitoring',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: Icon(
                Icons.circle,
                size: 10,
                color: _rideEnded
                    ? Colors.grey
                    : _isConnected
                        ? Colors.green
                        : Colors.orange,
              ),
              label: Text(
                _rideEnded
                    ? 'ENDED'
                    : _isConnected
                        ? 'LIVE'
                        : 'CONNECTING',
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? _buildError()
              : Column(
                  children: [
                    _buildMap(),
                    if (_speedWarning != null)
                      _buildWarning(),
                    if (_rideEnded)
                      _buildRideEnded(),
                    Expanded(
                      child: _buildDetails(colors),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMap() {
    final location = _riderLocation ??
        const LatLng(17.3850, 78.4867);

    return SizedBox(
      height: 330,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: location,
          zoom: 16,
        ),
        markers: _riderLocation == null
            ? {}
            : {
                Marker(
                  markerId: const MarkerId('rider'),
                  position: location,
                  infoWindow: const InfoWindow(
                    title: 'Rider location',
                  ),
                ),
              },
        zoomControlsEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        onMapCreated: (controller) {
          _mapController = controller;
          _moveCamera();
        },
      ),
    );
  }

  Widget _buildWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.red.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _speedWarning!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _speedWarning = null;
              });
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildRideEnded() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.grey.withValues(alpha: 0.15),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The rider has completed this ride.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'RIDER CURRENT SPEED',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _currentSpeed.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'km/h',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  'Speed limit',
                  _speedLimit == null
                      ? 'Not configured'
                      : '${_speedLimit!.toStringAsFixed(0)} km/h',
                  Icons.speed,
                  colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  'Alerts',
                  _speedAlertEnabled ? 'Enabled' : 'Disabled',
                  Icons.notifications_active_outlined,
                  colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoCard(
            'Ride code',
            widget.ride.rideCode,
            Icons.shield_outlined,
            colors,
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    String title,
    String value,
    IconData icon,
    ColorScheme colors,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off,
              color: Colors.red,
              size: 55,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startMonitoring,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
