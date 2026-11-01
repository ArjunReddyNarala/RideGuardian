import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../websocket/websocket_events.dart';

import '../models/ride.dart';
import '../services/ride_location_service.dart';
import '../services/rides_api_service.dart';

class ActiveRideScreen extends StatefulWidget {
  const ActiveRideScreen({
    super.key,
    required this.ride,
    required this.ridesApiService,
    this.isGuardian = false,
  });

  final Ride ride;
  final RidesApiService ridesApiService;

  /// When true, this screen receives the rider's location.
  /// It never starts GPS tracking on the guardian's device.
  final bool isGuardian;

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final RideLocationService _locationService =
      RideLocationService.instance;

  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<WebSocketMessage>? _messageSubscription;

  Timer? _durationTimer;

  LatLng? _currentLocation;

  double _distanceKm = 0;
  double _maxSpeed = 0;
  double _currentSpeed = 0;

  double? _speedLimit;

  Duration _duration = Duration.zero;

  DateTime? _lastPositionTime;

  bool _isLoading = true;
  bool _isTracking = false;
  bool _isEndingRide = false;
  bool _isMapReady = false;
  bool _isDisposed = false;
  bool _isStoppingTracking = false;

  String? _errorMessage;
  String? _speedWarning;

  static const double _minimumMovementMeters = 3;
  static const double _maximumAccuracyMeters = 50;

  bool get _isRider => !widget.isGuardian;

  @override
  void initState() {
    super.initState();

    _duration = DateTime.now().difference(widget.ride.startedAt);

    _startRideTracking();
  }

  // ---------------------------------------------------------------------------
  // Tracking initialization
  // ---------------------------------------------------------------------------

  Future<void> _startRideTracking() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isGuardian) {
        await _startGuardianTracking();
      } else {
        await _startRiderTracking();
      }

      if (_isDisposed || !mounted) return;

      _startDurationTimer();

      setState(() {
        _isLoading = false;
        _isTracking = true;
      });
    } catch (error) {
      if (!mounted || _isDisposed) return;

      setState(() {
        _isLoading = false;
        _isTracking = false;
        _errorMessage = _errorText(error);
      });

      if (widget.isGuardian) {
        await _locationService.disconnectGuardian();
      }
    }
  }

  Future<void> _startRiderTracking() async {
    // The service is shared. If tracking is already active, do not start
    // another GPS stream or another WebSocket connection.
    if (!_locationService.isTracking ||
        !_locationService.isConnected) {
      await _locationService.startTracking(
        rideId: widget.ride.id,
        backendBaseUrl: EnvConfig.backendBaseUrl,
      );
    }

    if (_isDisposed || !mounted) return;

    _positionSubscription = _locationService.positions.listen(
      _handlePosition,
      onError: _handleTrackingError,
    );

    _messageSubscription = _locationService.messages.listen(
      _handleWebSocketMessage,
      onError: _handleTrackingError,
    );
  }

  Future<void> _startGuardianTracking() async {
    // Fetch the initial state before opening the live connection.
    final snapshot = await widget.ridesApiService.getTrackingSnapshot(
      widget.ride.id,
    );

    if (_isDisposed || !mounted) return;

    _applyTrackingSnapshot(snapshot);

    await _locationService.connectAsGuardian(
      rideId: widget.ride.id,
      backendBaseUrl: EnvConfig.backendBaseUrl,
    );

    if (_isDisposed || !mounted) return;

    _messageSubscription = _locationService.messages.listen(
      _handleWebSocketMessage,
      onError: _handleTrackingError,
    );
  }

  String _errorText(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  void _applyTrackingSnapshot(Map<String, dynamic> snapshot) {
    final location = snapshot['currentLocation'] ??
        snapshot['location'] ??
        snapshot['latestLocation'];

    if (location is Map) {
      final latitude = _toDouble(location['latitude']);
      final longitude = _toDouble(location['longitude']);

      if (latitude != null && longitude != null) {
        _currentLocation = LatLng(latitude, longitude);
      }

      final speed = _toDouble(location['speedKmh']);

      if (speed != null) {
        _currentSpeed = speed;
        _maxSpeed = speed;
      }
    }

    _speedLimit = _toDouble(snapshot['speedLimitKmh']);

    if (_currentLocation != null) {
      _animateMapToLocation(_currentLocation!);
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();

    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || _isDisposed) return;

        setState(() {
          _duration = DateTime.now().difference(
            widget.ride.startedAt,
          );
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // GPS position handling - rider only
  // ---------------------------------------------------------------------------

  void _handlePosition(Position position) {
    if (!mounted || _isDisposed) return;

    if (position.accuracy > _maximumAccuracyMeters) {
      return;
    }

    final newLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    if (_currentLocation != null) {
      final distanceMeters = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );

      if (distanceMeters < _minimumMovementMeters) {
        return;
      }

      _distanceKm += distanceMeters / 1000;
    }

    final speed = position.speed.isFinite
        ? (position.speed * 3.6).clamp(0.0, double.infinity)
        : 0.0;

    setState(() {
      _currentLocation = newLocation;
      _currentSpeed = speed;

      if (speed > _maxSpeed) {
        _maxSpeed = speed;
      }

      _lastPositionTime = position.timestamp;
    });

    _animateMapToLocation(newLocation);
  }

  // ---------------------------------------------------------------------------
  // WebSocket message handling
  // ---------------------------------------------------------------------------

  void _handleWebSocketMessage(WebSocketMessage message) {
    if (!mounted || _isDisposed) return;

    switch (message.type) {
      case WebSocketEvents.connected:
        setState(() {
          _isTracking = true;
        });
        break;

      case WebSocketEvents.locationUpdate:
        if (!widget.isGuardian) break;

        _handleGuardianLocation(message.data);
        break;

      case WebSocketEvents.speedLimitExceeded:
        final data = message.data;

        if (data == null) return;

        final currentSpeed = data['currentSpeedKmh'];
        final speedLimit = data['speedLimitKmh'];

        setState(() {
          _speedWarning =
              'Speed limit exceeded! '
              'Current speed: $currentSpeed km/h. '
              'Limit: $speedLimit km/h.';
        });

        break;

      case WebSocketEvents.rideEnded:
        _handleRideEnded();
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

      default:
        break;
    }
  }

  void _handleGuardianLocation(Map<String, dynamic>? data) {
    if (data == null) return;

    final latitude = _toDouble(data['latitude']);
    final longitude = _toDouble(data['longitude']);
    final speed = _toDouble(data['speedKmh']);

    if (latitude == null || longitude == null) return;

    final newLocation = LatLng(latitude, longitude);

    if (_currentLocation != null) {
      final distanceMeters = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        latitude,
        longitude,
      );

      if (distanceMeters >= _minimumMovementMeters) {
        _distanceKm += distanceMeters / 1000;
      }
    }

    setState(() {
      _currentLocation = newLocation;

      if (speed != null) {
        _currentSpeed = speed;

        if (speed > _maxSpeed) {
          _maxSpeed = speed;
        }
      }

      _lastPositionTime = DateTime.tryParse(
        data['recordedAt']?.toString() ?? '',
      );
    });

    _animateMapToLocation(newLocation);
  }

  void _handleRideEnded() {
    if (!mounted || _isDisposed) return;

    _durationTimer?.cancel();

    setState(() {
      _isTracking = false;
      _isEndingRide = false;
    });

    if (widget.isGuardian) {
      _locationService.disconnectGuardian();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The rider has ended this ride.'),
      ),
    );
  }

  void _handleTrackingError(Object error) {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tracking connection error: $error'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Map
  // ---------------------------------------------------------------------------

  void _animateMapToLocation(LatLng location) {
    if (!mounted || _isDisposed || !_isMapReady) return;

    final controller = _mapController;

    if (controller == null) return;

    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLng(location),
      ).catchError((Object error) {
        // Ignore camera errors during map disposal.
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // End ride - rider only
  // ---------------------------------------------------------------------------

  Future<void> _endRide() async {
    if (_isEndingRide || _isDisposed || widget.isGuardian) return;

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End ride?'),
          content: const Text(
            'Are you sure you want to end this ride?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Continue ride'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('End ride'),
            ),
          ],
        );
      },
    );

    if (shouldEnd != true || !mounted || _isDisposed) return;

    setState(() {
      _isEndingRide = true;
    });

    try {
      await widget.ridesApiService.endRide(widget.ride.id);

      await _stopRiderTracking();

      if (!mounted || _isDisposed) return;

      setState(() {
        _isTracking = false;
        _isEndingRide = false;

        _duration = DateTime.now().difference(
          widget.ride.startedAt,
        );
      });

      await _showRideSummary();
    } catch (error) {
      if (!mounted || _isDisposed) return;

      setState(() {
        _isEndingRide = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to end ride: $error'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Stop tracking
  // ---------------------------------------------------------------------------

  Future<void> _stopRiderTracking() async {
    if (_isStoppingTracking) return;

    _isStoppingTracking = true;

    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      await _positionSubscription?.cancel();
      await _messageSubscription?.cancel();

      _positionSubscription = null;
      _messageSubscription = null;

      await _locationService.stopTracking();
    } finally {
      _isTracking = false;
      _isStoppingTracking = false;
    }
  }

  Future<void> _disconnectGuardian() async {
    _durationTimer?.cancel();

    await _messageSubscription?.cancel();
    _messageSubscription = null;

    await _locationService.disconnectGuardian();

    _isTracking = false;
  }

  // ---------------------------------------------------------------------------
  // Ride summary
  // ---------------------------------------------------------------------------

  Future<void> _showRideSummary() async {
    if (!mounted || _isDisposed) return;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ride completed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _summaryRow(
                  'Distance',
                  '${_distanceKm.toStringAsFixed(2)} km',
                ),
                _summaryRow(
                  'Duration',
                  _formatDuration(_duration),
                ),
                _summaryRow(
                  'Average speed',
                  '${_averageSpeed.toStringAsFixed(1)} km/h',
                ),
                _summaryRow(
                  'Maximum speed',
                  '${_maxSpeed.toStringAsFixed(1)} km/h',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Back to Rides'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || _isDisposed) return;

    Navigator.of(context).pop();
  }

  double get _averageSpeed {
    final hours = _duration.inSeconds / 3600;

    if (hours <= 0) return 0;

    return _distanceKm / hours;
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  String _formatDuration(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(duration.inHours)}:'
        '${two(duration.inMinutes.remainder(60))}:'
        '${two(duration.inSeconds.remainder(60))}';
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _isDisposed = true;
    _isMapReady = false;

    _mapController = null;

    _durationTimer?.cancel();

    // Important:
    // Do not stop rider tracking here. The shared service must continue
    // publishing locations when the rider navigates away from this screen.
    //
    // A guardian only disconnects their own receive-only socket.
    if (widget.isGuardian) {
      unawaited(_disconnectGuardian());
    }

    unawaited(_positionSubscription?.cancel());
    unawaited(_messageSubscription?.cancel());

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Main UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = widget.isGuardian
        ? 'Live Rider Tracking'
        : 'Active Ride';

    return PopScope(
      // Allow back navigation without ending the ride.
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: Icon(
                  Icons.circle,
                  color: _isTracking ? Colors.green : Colors.orange,
                  size: 12,
                ),
                label: Text(
                  _isTracking ? 'LIVE' : 'CONNECTING',
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _errorMessage != null
                  ? _buildError()
                  : Column(
                      children: [
                        _buildMap(),
                        if (_speedWarning != null)
                          _buildSpeedWarning(),
                        Expanded(
                          child: _buildRideDetails(),
                        ),
                        if (_isRider) _buildEndRideButton(),
                      ],
                    ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Google Maps
  // ---------------------------------------------------------------------------

  Widget _buildMap() {
    final location = _currentLocation;

    final target = location ??
        const LatLng(17.3850, 78.4867);

    return SizedBox(
      height: 300,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: target,
          zoom: 17,
        ),
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        onMapCreated: (controller) {
          if (!mounted || _isDisposed) {
            controller.dispose();
            return;
          }

          _mapController = controller;
          _isMapReady = true;

          if (_currentLocation != null) {
            _animateMapToLocation(_currentLocation!);
          }
        },
        markers: location == null
            ? {}
            : {
                Marker(
                  markerId: const MarkerId('rider'),
                  position: location,
                  infoWindow: InfoWindow(
                    title: widget.isGuardian
                        ? 'Rider location'
                        : 'Your current location',
                  ),
                ),
              },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Speed warning
  // ---------------------------------------------------------------------------

  Widget _buildSpeedWarning() {
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
          const SizedBox(width: 12),
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
            icon: const Icon(
              Icons.close,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ride details
  // ---------------------------------------------------------------------------

  Widget _buildRideDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  widget.isGuardian
                      ? 'RIDER CURRENT SPEED'
                      : 'CURRENT SPEED',
                  style: const TextStyle(
                    color: Colors.white70,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentSpeed.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'km/h',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                if (_speedLimit != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Speed limit: ${_speedLimit!.toStringAsFixed(0)} km/h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  'Distance',
                  '${_distanceKm.toStringAsFixed(2)} km',
                  Icons.route,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  'Duration',
                  _formatDuration(_duration),
                  Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  'Max speed',
                  '${_maxSpeed.toStringAsFixed(1)} km/h',
                  Icons.speed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  'Ride code',
                  widget.ride.rideCode,
                  Icons.shield_outlined,
                ),
              ),
            ],
          ),
          if (_lastPositionTime != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last location update: '
              '${TimeOfDay.fromDateTime(_lastPositionTime!).format(context)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(
    String title,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // End ride button
  // ---------------------------------------------------------------------------

  Widget _buildEndRideButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _isEndingRide ? null : _endRide,
          icon: _isEndingRide
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.stop_circle_outlined,
                ),
          label: Text(
            _isEndingRide ? 'Ending ride...' : 'End Ride',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              color: Colors.red,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unable to start ride tracking.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (widget.isGuardian) {
                        await _locationService.disconnectGuardian();
                      }

                      if (!mounted || _isDisposed) return;

                      await _startRideTracking();
                    },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}