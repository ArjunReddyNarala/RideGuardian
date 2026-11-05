import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/india_time.dart';
import '../../../core/widgets/pulsing_location_marker.dart';
import '../../guardians/models/guardian_relationship.dart';
import '../../guardians/services/guardians_api_service.dart';
import '../../../websocket/websocket_events.dart';

import '../models/ride.dart';
import '../models/gps_speed_reading.dart';
import '../models/ride_guardian.dart';
import '../services/ride_location_service.dart';
import '../services/rides_api_service.dart';
import '../widgets/speedometer_gauge.dart';

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
  final RideLocationService _locationService = RideLocationService.instance;
  late final ApiClient _guardiansApiClient = ApiClient();
  late final GuardiansApiService _guardiansApi = GuardiansApiService(
    _guardiansApiClient,
  );

  GoogleMapController? _mapController;
  BitmapDescriptor? _locationMarkerIcon;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<WebSocketMessage>? _messageSubscription;

  Timer? _durationTimer;

  LatLng? _currentLocation;
  LatLng? _lastDistanceLocation;
  DateTime? _lastDistancePositionTime;
  double? _lastDistanceAccuracyMeters;

  double _distanceKm = 0;
  double _maxSpeed = 0;
  double _currentSpeed = 0;
  double? _locationAccuracyMeters;
  bool _hasSpeedReading = false;

  double? _speedLimit;
  int? _riderBatteryLevel;
  int _selectedActiveRideTab = 0;
  List<RideGuardian> _rideGuardians = [];
  List<GuardianRelationship> _guardianRelationships = [];
  bool _loadingRideGuardians = true;
  bool _addingRideGuardians = false;
  String? _rideGuardiansError;

  Duration _duration = Duration.zero;

  DateTime? _lastPositionTime;
  DateTime? _lastPositionReceivedAt;

  bool _isLoading = true;
  bool _isTracking = false;
  bool _isEndingRide = false;
  bool _isMapReady = false;
  bool _isDisposed = false;
  bool _isStoppingTracking = false;

  String? _errorMessage;
  String? _speedWarning;

  static const double _minimumMovementMeters = 3;
  static const double _maximumAccuracyMeters = 35;
  static const double _maximumDistanceNoiseThresholdMeters = 20;
  static const double _maximumPlausibleSpeedMetersPerSecond = 70;
  static const Duration _speedFixStaleAfter = Duration(seconds: 5);
  static const Duration _maximumDistanceFixGap = Duration(seconds: 10);

  bool get _isRider => !widget.isGuardian;

  @override
  void initState() {
    super.initState();

    _duration = DateTime.now().difference(widget.ride.startedAt);

    _loadLocationMarkerIcon();
    _startRideTracking();
    if (!widget.isGuardian) unawaited(_loadRideGuardianData());
  }

  Future<void> _loadLocationMarkerIcon() async {
    try {
      final markerIcon = await LiveLocationMarker.createIcon();
      if (!mounted || _isDisposed) return;

      setState(() => _locationMarkerIcon = markerIcon);
    } catch (error) {
      debugPrint('RideGuardian marker rendering error: $error');
    }
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
    if (!_locationService.isTracking || !_locationService.isConnected) {
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

    // Listen before the socket opens so the first live GPS/battery update is
    // not missed while the guardian screen is attaching its stream handler.
    _messageSubscription = _locationService.messages.listen(
      _handleWebSocketMessage,
      onError: _handleTrackingError,
    );

    await _locationService.connectAsGuardian(
      rideId: widget.ride.id,
      backendBaseUrl: EnvConfig.backendBaseUrl,
    );
  }

  String _errorText(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  Future<void> _loadRideGuardianData({bool showLoading = true}) async {
    if (!mounted || widget.isGuardian) return;

    if (showLoading) {
      setState(() {
        _loadingRideGuardians = true;
        _rideGuardiansError = null;
      });
    }

    try {
      final rideGuardians = await widget.ridesApiService.getRideGuardians(
        widget.ride.id,
      );
      final relationships = await _guardiansApi.getRelationships();
      if (!mounted) return;

      setState(() {
        _rideGuardians = rideGuardians;
        _guardianRelationships = relationships
            .where(
              (relationship) =>
                  relationship.isAccepted &&
                  relationship.riderId == widget.ride.riderId &&
                  relationship.guardian != null,
            )
            .toList();
        _loadingRideGuardians = false;
        _rideGuardiansError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRideGuardians = false;
        _rideGuardiansError = _errorText(error);
      });
    }
  }

  Future<void> _showAddRideGuardians() async {
    if (_loadingRideGuardians || _addingRideGuardians) return;
    if (_rideGuardiansError != null) {
      _showMessage('Refresh the guardians list before adding someone.');
      return;
    }

    final assignedIds = _rideGuardians.map((guardian) => guardian.id).toSet();
    final candidates = _guardianRelationships
        .where((relationship) => !assignedIds.contains(relationship.guardianId))
        .toList();

    if (candidates.isEmpty) {
      _showMessage('No new accepted guardians are available to add.');
      return;
    }

    final selectedGuardianIds = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final selected = <String>{};
        final colors = Theme.of(sheetContext).colorScheme;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.78,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.outlineVariant,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Add ride guardians',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose accepted guardians to share this live ride with.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                      itemCount: candidates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final relationship = candidates[index];
                        final guardian = relationship.guardian!;
                        final isDnd = guardian.doNotDisturb;
                        final isSelected = selected.contains(guardian.id);
                        final dndColor = const Color(0xFF8B5CF6);

                        return Material(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.38,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: isDnd
                                ? null
                                : () {
                                    setSheetState(() {
                                      if (isSelected) {
                                        selected.remove(guardian.id);
                                      } else {
                                        selected.add(guardian.id);
                                      }
                                    });
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 23,
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.13),
                                    backgroundImage:
                                        guardian.profileImageUrl?.isNotEmpty ==
                                            true
                                        ? NetworkImage(
                                            guardian.profileImageUrl!,
                                          )
                                        : null,
                                    child:
                                        guardian.profileImageUrl?.isNotEmpty ==
                                            true
                                        ? null
                                        : const Icon(
                                            Icons.person_rounded,
                                            color: AppColors.primary,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          guardian.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          guardian.email ??
                                              guardian.phone ??
                                              'Ride Guardian contact',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                        if (isDnd) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Do Not Disturb · unavailable',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: dndColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: isDnd ? false : isSelected,
                                    onChanged: isDnd
                                        ? null
                                        : (checked) {
                                            setSheetState(() {
                                              if (checked == true) {
                                                selected.add(guardian.id);
                                              } else {
                                                selected.remove(guardian.id);
                                              }
                                            });
                                          },
                                    activeColor: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(selected),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          selected.isEmpty
                              ? 'Select guardians'
                              : 'Add ${selected.length} to this ride',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedGuardianIds == null || selectedGuardianIds.isEmpty) return;
    await _addGuardiansToActiveRide(selectedGuardianIds);
  }

  Future<void> _addGuardiansToActiveRide(Set<String> guardianIds) async {
    if (!mounted) return;
    setState(() => _addingRideGuardians = true);

    var addedCount = 0;
    final failedIds = <String>[];
    for (final guardianId in guardianIds) {
      try {
        await widget.ridesApiService.addGuardian(
          rideId: widget.ride.id,
          guardianId: guardianId,
        );
        addedCount++;
      } catch (_) {
        failedIds.add(guardianId);
      }
    }

    await _loadRideGuardianData(showLoading: false);
    if (!mounted) return;
    setState(() => _addingRideGuardians = false);

    if (failedIds.isEmpty) {
      _showMessage(
        addedCount == 1
            ? 'Guardian added to this ride.'
            : '$addedCount guardians added to this ride.',
      );
    } else if (addedCount > 0) {
      _showMessage(
        '$addedCount guardian(s) added. ${failedIds.length} could not be added.',
      );
    } else {
      _showMessage('Could not add the selected guardians. Please try again.');
    }
  }

  void _applyTrackingSnapshot(Map<String, dynamic> snapshot) {
    final location =
        snapshot['currentLocation'] ??
        snapshot['location'] ??
        snapshot['latestLocation'];

    if (location is Map) {
      final latitude = _toDouble(location['latitude']);
      final longitude = _toDouble(location['longitude']);
      final recordedAt = DateTime.tryParse(
        location['recordedAt']?.toString() ?? '',
      );
      final accuracyMeters = _toDouble(location['accuracy']);
      if (widget.isGuardian) {
        _riderBatteryLevel = _toInt(location['batteryLevel']);
      }
      final isFresh = _isFreshPositionTime(recordedAt);

      if (isFresh && latitude != null && longitude != null) {
        _currentLocation = LatLng(latitude, longitude);
        _distanceDeltaForFix(_currentLocation!, accuracyMeters, recordedAt);
      } else {
        _currentLocation = null;
        _lastDistanceLocation = null;
        _lastDistancePositionTime = null;
        _lastDistanceAccuracyMeters = null;
      }

      final speedReading = isFresh
          ? GpsSpeedReading.fromValues(
              speedKmh: _toDouble(location['speedKmh']),
              accuracyKmh: _toDouble(location['speedAccuracyKmh']),
            )
          : GpsSpeedReading.fromValues(speedKmh: null);
      _locationAccuracyMeters = isFresh ? accuracyMeters : null;
      _lastPositionTime = recordedAt;
      _lastPositionReceivedAt = isFresh ? DateTime.now() : null;

      if (speedReading.speedKmh != null) {
        _currentSpeed = speedReading.speedKmh!;
        _maxSpeed = _currentSpeed;
      } else {
        _currentSpeed = 0;
      }

      _hasSpeedReading = speedReading.speedKmh != null;
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

  int? _toInt(dynamic value) {
    if (value is int && value >= 0 && value <= 100) return value;
    if (value is num && value >= 0 && value <= 100) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed >= 0 && parsed <= 100) return parsed;
    }
    return null;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isDisposed) return;

      setState(() {
        _duration = DateTime.now().difference(widget.ride.startedAt);

        if (!_hasRecentPosition) {
          // Do not present an old GPS fix as current when updates stop.
          _currentSpeed = 0;
          _hasSpeedReading = false;
          _locationAccuracyMeters = null;
        }
      });
    });
  }

  // ---------------------------------------------------------------------------
  // GPS position handling - rider only
  // ---------------------------------------------------------------------------

  void _handlePosition(Position position) {
    if (!mounted || _isDisposed) return;

    // A cached or delayed platform fix must not be presented as live simply
    // because it was delivered to this stream moments ago.
    if (!_isFreshPositionTime(position.timestamp)) return;

    if (_lastPositionTime != null &&
        position.timestamp.isBefore(_lastPositionTime!)) {
      return;
    }

    final newLocation = LatLng(position.latitude, position.longitude);
    final distanceDeltaKm = _distanceDeltaForFix(
      newLocation,
      position.hasAccuracy ? position.accuracy : null,
      position.timestamp,
    );

    final speedReading = GpsSpeedReading.fromPosition(position);
    final hasSpeed = speedReading.speedKmh != null;
    final speed = speedReading.speedKmh ?? 0;

    setState(() {
      _distanceKm += distanceDeltaKm;
      _currentLocation = newLocation;
      _locationAccuracyMeters = position.hasAccuracy ? position.accuracy : null;
      _currentSpeed = speed;
      _hasSpeedReading = hasSpeed;

      if (hasSpeed && speed > _maxSpeed) {
        _maxSpeed = speed;
      }

      _lastPositionTime = position.timestamp;
      _lastPositionReceivedAt = DateTime.now();
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message.message!)));
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
    final speedReading = GpsSpeedReading.fromValues(
      speedKmh: _toDouble(data['speedKmh']),
      accuracyKmh: _toDouble(data['speedAccuracyKmh']),
    );
    final locationAccuracy = _toDouble(data['accuracyMeters']);
    final fixTime = DateTime.tryParse(data['recordedAt']?.toString() ?? '');

    if (latitude == null || longitude == null) return;
    if (fixTime == null || !_isFreshPositionTime(fixTime)) return;
    if (_lastPositionTime != null && fixTime.isBefore(_lastPositionTime!)) {
      return;
    }

    final newLocation = LatLng(latitude, longitude);
    final distanceDeltaKm = _distanceDeltaForFix(
      newLocation,
      locationAccuracy,
      fixTime,
    );

    setState(() {
      _distanceKm += distanceDeltaKm;
      _currentLocation = newLocation;
      _locationAccuracyMeters = locationAccuracy;
      _riderBatteryLevel = _toInt(data['batteryLevel']);

      if (speedReading.speedKmh != null) {
        final speed = speedReading.speedKmh!;
        _currentSpeed = speed;
        _hasSpeedReading = true;
        if (speed > _maxSpeed) {
          _maxSpeed = speed;
        }
      } else {
        _currentSpeed = 0;
        _hasSpeedReading = false;
      }

      _lastPositionTime = fixTime;
      _lastPositionReceivedAt = DateTime.now();
    });

    _animateMapToLocation(newLocation);
  }

  bool _isFreshPositionTime(DateTime? timestamp) {
    if (timestamp == null) return false;
    final age = DateTime.now().toUtc().difference(timestamp.toUtc());
    return age <= _speedFixStaleAfter && age >= -_speedFixStaleAfter;
  }

  bool get _hasRecentPosition {
    final receivedAt = _lastPositionReceivedAt;
    if (receivedAt == null) return false;
    final age = DateTime.now().difference(receivedAt);
    return age >= Duration.zero && age <= _speedFixStaleAfter;
  }

  double _distanceDeltaForFix(
    LatLng location,
    double? accuracyMeters,
    DateTime? timestamp,
  ) {
    if (accuracyMeters == null ||
        !accuracyMeters.isFinite ||
        accuracyMeters < 0 ||
        accuracyMeters > _maximumAccuracyMeters ||
        timestamp == null ||
        !location.latitude.isFinite ||
        !location.longitude.isFinite) {
      _lastDistanceLocation = null;
      _lastDistancePositionTime = null;
      _lastDistanceAccuracyMeters = null;
      return 0;
    }

    final previousLocation = _lastDistanceLocation;
    final previousTime = _lastDistancePositionTime;
    if (previousLocation == null || previousTime == null) {
      _setDistanceAnchor(location, timestamp, accuracyMeters);
      return 0;
    }

    final gap = timestamp.toUtc().difference(previousTime.toUtc());
    if (gap <= Duration.zero) return 0;

    if (gap > _maximumDistanceFixGap) {
      _setDistanceAnchor(location, timestamp, accuracyMeters);
      return 0;
    }

    final distanceMeters = Geolocator.distanceBetween(
      previousLocation.latitude,
      previousLocation.longitude,
      location.latitude,
      location.longitude,
    );
    final elapsedSeconds = gap.inMilliseconds / 1000;
    final maximumPlausibleDistance =
        elapsedSeconds * _maximumPlausibleSpeedMetersPerSecond + 10;

    // GPS jumps can otherwise add a large false distance in a single fix.
    if (!distanceMeters.isFinite || distanceMeters > maximumPlausibleDistance) {
      _setDistanceAnchor(location, timestamp, accuracyMeters);
      return 0;
    }

    final previousAccuracy = _lastDistanceAccuracyMeters ?? accuracyMeters;
    final noiseThreshold = math.max(
      _minimumMovementMeters,
      math.min(
        _maximumDistanceNoiseThresholdMeters,
        (previousAccuracy + accuracyMeters) / 2,
      ),
    );

    // Keep the last accepted point while the movement is below the noise
    // threshold. Slow movement then accumulates instead of being discarded
    // fix by fix.
    if (distanceMeters < noiseThreshold) return 0;

    _setDistanceAnchor(location, timestamp, accuracyMeters);
    return distanceMeters / 1000;
  }

  void _setDistanceAnchor(
    LatLng location,
    DateTime timestamp,
    double accuracyMeters,
  ) {
    _lastDistanceLocation = location;
    _lastDistancePositionTime = timestamp;
    _lastDistanceAccuracyMeters = accuracyMeters;
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
      const SnackBar(content: Text('The rider has ended this ride.')),
    );
  }

  void _handleTrackingError(Object error) {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tracking connection error: $error')),
    );
  }

  // ---------------------------------------------------------------------------
  // Map
  // ---------------------------------------------------------------------------

  void _animateMapToLocation(LatLng location) {
    if (!mounted || _isDisposed || !_isMapReady) return;

    final controller = _mapController;

    if (controller == null) return;

    try {
      unawaited(
        controller
            .animateCamera(CameraUpdate.newLatLng(location))
            .catchError((Object _) {}),
      );
    } on StateError {
      // Google Maps checks widget attachment synchronously before returning
      // the Future. Ignore a controller that became stale during disposal.
      if (identical(_mapController, controller)) {
        _mapController = null;
        _isMapReady = false;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // End ride - rider only
  // ---------------------------------------------------------------------------

  Future<void> _endRide() async {
    if (_isEndingRide || _isDisposed || widget.isGuardian) return;

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.outlineVariant),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.stop_circle_outlined,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(child: Text('End this ride?')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your guardians will stop receiving your live location and speed, '
                'including safety alerts if you exceed the speed limit.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                        side: BorderSide(color: colors.outlineVariant),
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Keep riding'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('End ride'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        backgroundColor: AppColors.danger.withValues(
                          alpha: 0.08,
                        ),
                        side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.38),
                        ),
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

        _duration = DateTime.now().difference(widget.ride.startedAt);
      });

      await _showRideSummary();
    } catch (error) {
      if (!mounted || _isDisposed) return;

      setState(() {
        _isEndingRide = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to end ride: $error')));
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ride completed',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ride tracking has stopped. Here’s your trip summary.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryMetric(
                          icon: Icons.route_rounded,
                          label: 'Distance',
                          value: '${_distanceKm.toStringAsFixed(2)} km',
                          context: sheetContext,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryMetric(
                          icon: Icons.schedule_rounded,
                          label: 'Duration',
                          value: _formatDuration(_duration),
                          context: sheetContext,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryMetric(
                          icon: Icons.speed_rounded,
                          label: 'Average speed',
                          value: '${_averageSpeed.toStringAsFixed(1)} km/h',
                          context: sheetContext,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryMetric(
                          icon: Icons.speed_rounded,
                          label: 'Maximum speed',
                          value: '${_maxSpeed.toStringAsFixed(1)} km/h',
                          context: sheetContext,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to Rides'),
                    ),
                  ),
                ],
              ),
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

  Widget _summaryMetric({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
    _guardiansApiClient.close();

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
    final title = widget.isGuardian ? 'Live Rider Tracking' : 'Active Ride';

    return PopScope(
      // Allow back navigation without ending the ride.
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: _isTracking
                    ? _BlinkingLiveDot(color: _liveAccuracyColor)
                    : const Icon(Icons.circle, color: Colors.orange, size: 12),
                label: Text(_isTracking ? 'LIVE' : 'CONNECTING'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildError()
              : Column(
                  children: [
                    if (_isRider) _buildActiveRideTabSelector(),
                    Expanded(
                      child: _isRider && _selectedActiveRideTab == 1
                          ? _buildRideGuardiansTab()
                          : _buildRideDashboard(),
                    ),
                    if (_isRider) _buildEndRideButton(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildActiveRideTabSelector() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _activeRideTabButton('Ride', Icons.route_rounded, 0),
          _activeRideTabButton(
            'Guardians${_rideGuardians.isEmpty ? '' : ' ${_rideGuardians.length}'}',
            Icons.shield_outlined,
            1,
          ),
        ],
      ),
    );
  }

  Widget _activeRideTabButton(String label, IconData icon, int index) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selectedActiveRideTab == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => _selectActiveRideTab(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: selected
                  ? Border.all(color: colors.outlineVariant)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

  void _selectActiveRideTab(int index) {
    if (_selectedActiveRideTab == index) return;

    // Leaving the ride tab disposes its GoogleMap widget while location
    // tracking continues. Drop the old controller before that happens.
    if (index != 0) {
      _isMapReady = false;
      _mapController = null;
    }

    setState(() => _selectedActiveRideTab = index);
  }

  Widget _buildRideDashboard() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMap(),
          if (_speedWarning != null) _buildSpeedWarning(),
          _buildRideDetails(),
        ],
      ),
    );
  }

  Widget _buildRideGuardiansTab() {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => _loadRideGuardianData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guardians on this ride',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'These people can view your live ride details.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _loadingRideGuardians || _addingRideGuardians
                    ? null
                    : () => _loadRideGuardianData(),
                tooltip: 'Refresh guardians',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _loadingRideGuardians || _addingRideGuardians
                  ? null
                  : _showAddRideGuardians,
              icon: _loadingRideGuardians
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : _addingRideGuardians
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                _loadingRideGuardians
                    ? 'Loading guardians…'
                    : _addingRideGuardians
                    ? 'Adding guardians…'
                    : 'Add guardians',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_loadingRideGuardians && _rideGuardians.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 55),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rideGuardiansError != null && _rideGuardians.isEmpty)
            _rideGuardiansLoadError()
          else if (_rideGuardians.isEmpty)
            _rideGuardiansEmptyState()
          else ...[
            ..._rideGuardians.map(_rideGuardianCard),
            if (_addingRideGuardians)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ],
      ),
    );
  }

  Widget _rideGuardianCard(RideGuardian guardian) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = guardian.profileImageUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary.withValues(alpha: 0.13),
            backgroundImage: imageUrl == null || imageUrl.isEmpty
                ? null
                : NetworkImage(imageUrl),
            child: imageUrl == null || imageUrl.isEmpty
                ? const Icon(Icons.person_rounded, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardian.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  guardian.email ?? guardian.phone ?? 'Ride Guardian user',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'MONITORING THIS RIDE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 9,
                      letterSpacing: 0.55,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.verified_user_rounded, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _rideGuardiansEmptyState() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 35, 24, 35),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
              size: 29,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No guardians on this ride yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Add someone you trust to share your live ride with them.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _rideGuardiansLoadError() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 34),
          const SizedBox(height: 10),
          const Text('Could not load ride guardians'),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _loadRideGuardianData(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ---------------------------------------------------------------------------
  // Google Maps
  // ---------------------------------------------------------------------------

  Widget _buildMap() {
    final location = _currentLocation;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final target = location ?? const LatLng(17.3850, 78.4867);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: SizedBox(
          height: 300,
          child: Stack(
            children: [
              Positioned.fill(
                child: LocationAccuracyLayer(
                  position: location,
                  accuracyMeters: _locationAccuracyMeters,
                  builder: (context, accuracyCircles) => GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: target,
                      zoom: 17,
                    ),
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      if (!mounted || _isDisposed) {
                        return;
                      }

                      _mapController = controller;
                      _isMapReady = true;

                      if (_currentLocation != null) {
                        _animateMapToLocation(_currentLocation!);
                      }
                    },
                    circles: accuracyCircles,
                    markers: location == null || _locationMarkerIcon == null
                        ? {}
                        : {
                            Marker(
                              markerId: const MarkerId('rider'),
                              position: location,
                              anchor: const Offset(0.5, 0.5),
                              icon: _locationMarkerIcon!,
                              infoWindow: InfoWindow(
                                title: widget.isGuardian
                                    ? 'Rider location'
                                    : 'Your current location',
                              ),
                            ),
                          },
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Tooltip(
                  message: 'Recenter on live location',
                  child: Material(
                    color: theme.colorScheme.surface,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: location == null
                          ? null
                          : () => _animateMapToLocation(location),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.my_location_rounded,
                          color: location == null
                              ? theme.colorScheme.onSurfaceVariant
                              : AppColors.primary,
                          size: 22,
                        ),
                      ),
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
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
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
            icon: const Icon(Icons.close, color: Colors.red),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ride details
  // ---------------------------------------------------------------------------

  Widget _buildRideDetails() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          SpeedometerGauge(
            speedKmh: _currentSpeed,
            isSpeedAvailable: _hasSpeedReading,
            speedLimitKmh: _speedLimit,
            isRider: _isRider,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  'Distance',
                  '${_distanceKm.toStringAsFixed(2)} km',
                  Icons.route,
                  helperText: _distanceFreshnessLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  'Duration',
                  _formatDuration(_duration),
                  Icons.timer_outlined,
                  helperText: 'Elapsed',
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
                  helperText: 'Ride peak',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _gpsAccuracyCard()),
            ],
          ),
          if (widget.isGuardian) ...[
            const SizedBox(height: 12),
            _riderBatteryCard(),
          ],
          if (_lastPositionTime != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last location update: '
              '${TimeOfDay.fromDateTime(toIndiaStandardTime(_lastPositionTime!)).format(context)} IST',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _riderBatteryCard() {
    final level = _riderBatteryLevel;
    final color = level == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : level <= 15
        ? AppColors.danger
        : level <= 30
        ? AppColors.warning
        : AppColors.primary;
    final icon = level == null
        ? Icons.battery_unknown_rounded
        : level <= 15
        ? Icons.battery_alert_rounded
        : Icons.battery_full_rounded;
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rider battery',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  level == null
                      ? 'Waiting for rider data'
                      : 'Reported by rider device',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            level == null ? '—' : '$level%',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    String title,
    String value,
    IconData icon, {
    required String helperText,
  }) {
    return _buildRideMetricCard(
      title: title,
      value: value,
      icon: icon,
      helperText: helperText,
    );
  }

  Widget _gpsAccuracyCard() {
    final accuracyMeters = _locationAccuracyMeters;
    final quality = accuracyMeters == null
        ? null
        : _gpsAccuracyQuality(accuracyMeters);
    final colorScheme = Theme.of(context).colorScheme;
    final qualityColor = accuracyMeters == null
        ? colorScheme.onSurfaceVariant
        : _gpsAccuracyColor(accuracyMeters);

    return _buildRideMetricCard(
      title: 'GPS accuracy',
      value: accuracyMeters == null
          ? '—'
          : '±${accuracyMeters.toStringAsFixed(1)} m',
      icon: Icons.gps_fixed,
      helperText: quality ?? 'Waiting for GPS',
      helperColor: qualityColor,
      onInfoPressed: _showGpsAccuracyInfo,
    );
  }

  Widget _buildRideMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required String helperText,
    Color? helperColor,
    VoidCallback? onInfoPressed,
  }) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 150,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 19),
                ),
                const Spacer(),
                if (onInfoPressed != null)
                  IconButton(
                    onPressed: onInfoPressed,
                    tooltip: 'About GPS accuracy',
                    icon: const Icon(Icons.info_outline_rounded),
                    color: colors.onSurfaceVariant,
                    iconSize: 19,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 36,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              helperText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: helperColor ?? colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _gpsAccuracyQuality(double accuracyMeters) {
    if (accuracyMeters <= 5) return 'Excellent';
    if (accuracyMeters <= 10) return 'Good';
    if (accuracyMeters <= 25) return 'Fair';
    return 'Weak';
  }

  String get _distanceFreshnessLabel {
    if (_hasRecentPosition) return 'Trip total';
    return _lastPositionTime == null ? 'Waiting for GPS' : 'No recent GPS fix';
  }

  Color _gpsAccuracyColor(double accuracyMeters) {
    if (accuracyMeters <= 5) return AppColors.primary;
    if (accuracyMeters <= 10) return AppColors.success;
    if (accuracyMeters <= 25) return AppColors.warning;
    return AppColors.danger;
  }

  Color get _liveAccuracyColor {
    final accuracyMeters = _locationAccuracyMeters;
    if (accuracyMeters == null) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    if (accuracyMeters <= 5) return AppColors.primary;
    if (accuracyMeters <= 10) return AppColors.success;
    if (accuracyMeters <= 25) return AppColors.warning;
    return AppColors.danger;
  }

  void _showGpsAccuracyInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('GPS accuracy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GPS accuracy is the estimated radius around the rider’s '
                'location. A smaller number means a more precise location.',
              ),
              const SizedBox(height: 18),
              _accuracyRangeRow('0–5 m', 'Excellent', AppColors.primary),
              _accuracyRangeRow('>5–10 m', 'Good', AppColors.success),
              _accuracyRangeRow('>10–25 m', 'Fair', AppColors.warning),
              _accuracyRangeRow('>25 m', 'Weak', AppColors.danger),
              const SizedBox(height: 12),
              Text(
                'These ranges are guidance. Buildings, weather, and device '
                'conditions can affect the GPS estimate.',
                style: Theme.of(dialogContext).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Widget _accuracyRangeRow(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 72, child: Text(range)),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isEndingRide ? null : _endRide,
          icon: _isEndingRide
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.danger,
                  ),
                )
              : const Icon(Icons.stop_circle_outlined, size: 19),
          label: Text(_isEndingRide ? 'Ending ride…' : 'End ride'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            backgroundColor: AppColors.danger.withValues(alpha: 0.08),
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.38)),
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
            const Icon(Icons.location_off, color: Colors.red, size: 56),
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

class _BlinkingLiveDot extends StatefulWidget {
  const _BlinkingLiveDot({required this.color});

  final Color color;

  @override
  State<_BlinkingLiveDot> createState() => _BlinkingLiveDotState();
}

class _BlinkingLiveDotState extends State<_BlinkingLiveDot> {
  Timer? _blinkTimer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() => _isVisible = !_isVisible);
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1 : 0.25,
      duration: const Duration(milliseconds: 400),
      child: Icon(Icons.circle, color: widget.color, size: 12),
    );
  }
}
