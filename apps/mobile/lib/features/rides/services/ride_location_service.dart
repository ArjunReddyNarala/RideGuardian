import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../websocket/websocket_events.dart';
import 'device_battery_service.dart';
import '../models/gps_speed_reading.dart';

class RideLocationService {
  RideLocationService._();

  static final RideLocationService instance = RideLocationService._();

  StreamSubscription<Position>? _positionSubscription;

  StreamSubscription<dynamic>? _socketSubscription;

  WebSocketChannel? _channel;

  Timer? _reconnectTimer;
  Timer? _batteryRefreshTimer;
  Position? _latestPosition;
  int? _batteryLevel;
  DateTime? _lastBatteryRefreshAt;
  bool _isRefreshingBattery = false;
  final DeviceBatteryService _batteryService = DeviceBatteryService();
  String? _rideId;
  String? _backendBaseUrl;
  bool _isGuardianConnection = false;
  bool _shouldReconnect = false;
  int _reconnectAttempt = 0;

  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();

  Stream<Position> get positions => _positionController.stream;

  Stream<WebSocketMessage> get messages => _messageController.stream;

  bool _isTracking = false;

  bool _isConnected = false;

  bool get isTracking => _isTracking;

  bool get isConnected => _isConnected;

  /// Rider connection: GPS updates are published to the backend.
  Future<void> startTracking({
    required String rideId,
    required String backendBaseUrl,
  }) async {
    if (_isTracking) {
      if (!_isConnected && _rideId == rideId) {
        _scheduleReconnect();
      }
      return;
    }

    await _checkLocationPermission();

    _rideId = rideId;
    _backendBaseUrl = backendBaseUrl;
    _isGuardianConnection = false;
    _shouldReconnect = true;
    _startBatteryMonitoring();

    await _connect(rideId: rideId, backendBaseUrl: backendBaseUrl);

    final LocationSettings locationSettings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        // Send every GPS fix to the guardian. The backend applies its own
        // movement threshold before writing another database location row.
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      ),
      TargetPlatform.iOS => AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      ),
      _ => const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    };

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            _positionController.add(position);
            _sendLocation(position);
          },
          onError: (error) {
            _messageController.add(
              WebSocketMessage(
                type: WebSocketEvents.error,
                message: error.toString(),
              ),
            );
          },
        );

    _isTracking = true;
  }

  /// Guardian connection: receives updates only.
  ///
  /// This method intentionally does not:
  /// - Request location permission.
  /// - Start a GPS stream.
  /// - Publish LOCATION_UPDATE events.
  Future<void> connectAsGuardian({
    required String rideId,
    required String backendBaseUrl,
  }) async {
    if (_isConnected) return;

    _rideId = rideId;
    _backendBaseUrl = backendBaseUrl;
    _isGuardianConnection = true;
    _shouldReconnect = true;

    await _connect(rideId: rideId, backendBaseUrl: backendBaseUrl);
  }

  Future<void> _connect({
    required String rideId,
    required String backendBaseUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to retrieve Firebase ID token.');
    }

    final wsBaseUrl = backendBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    final uri = Uri.parse('$wsBaseUrl/ws/rides')
        .replace(queryParameters: {'rideId': rideId, 'token': token});

    final channel = WebSocketChannel.connect(uri);

    _channel = channel;

    try {
      await channel.ready.timeout(const Duration(seconds: 15));

      _isConnected = true;
      _reconnectAttempt = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      if (!_isGuardianConnection && _latestPosition != null) {
        final age = DateTime.now().difference(_latestPosition!.timestamp);
        if (age >= const Duration(seconds: -5) &&
            age <= const Duration(seconds: 5)) {
          _sendLocation(_latestPosition!);
        }
      }

      _socketSubscription = channel.stream.listen(
        (event) {
          try {
            final decoded = jsonDecode(event.toString());

            if (decoded is Map<String, dynamic>) {
              _messageController.add(WebSocketMessage.fromJson(decoded));
            }
          } catch (_) {
            _messageController.add(
              const WebSocketMessage(
                type: WebSocketEvents.error,
                message: 'Invalid server response.',
              ),
            );
          }
        },
        onError: (error) {
          _isConnected = false;
          _scheduleReconnect();

          _messageController.add(
            WebSocketMessage(
              type: WebSocketEvents.error,
              message: error.toString(),
            ),
          );
        },
        onDone: () {
          _isConnected = false;
          if (identical(_channel, channel)) {
            _channel = null;
          }
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _channel = null;
      _isConnected = false;

      await channel.sink.close();

      rethrow;
    }
  }

  void _sendLocation(Position position) {
    if (_latestPosition != null &&
        position.timestamp.isBefore(_latestPosition!.timestamp)) {
      return;
    }
    _latestPosition = position;
    final lastBatteryRefresh = _lastBatteryRefreshAt;
    if (lastBatteryRefresh == null ||
        DateTime.now().difference(lastBatteryRefresh) >=
            const Duration(seconds: 30)) {
      unawaited(_refreshBatteryLevel());
    }
    final channel = _channel;

    if (channel == null || !_isConnected) return;

    final speedReading = GpsSpeedReading.fromPosition(position);

    final message = WebSocketMessage(
      type: WebSocketEvents.locationUpdate,
      data: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speedKmh': speedReading.speedKmh,
        'speedAccuracyKmh': speedReading.accuracyKmh,
        'accuracyMeters': position.hasAccuracy && position.accuracy.isFinite
            ? position.accuracy
            : null,
        'headingDegrees': position.hasHeading && position.heading >= 0
            ? position.heading
            : null,
        'batteryLevel': _batteryLevel,
        'recordedAt': position.timestamp.toUtc().toIso8601String(),
      },
    );

    channel.sink.add(message.encode());
  }

  void _startBatteryMonitoring() {
    _batteryRefreshTimer?.cancel();
    unawaited(_refreshBatteryLevel());
    _batteryRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshBatteryLevel()),
    );
  }

  Future<void> _refreshBatteryLevel() async {
    if (_isRefreshingBattery) return;
    _isRefreshingBattery = true;
    _lastBatteryRefreshAt = DateTime.now();
    try {
      _batteryLevel = await _batteryService.getLevel();
    } finally {
      _isRefreshingBattery = false;
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectTimer != null) return;

    final rideId = _rideId;
    final backendBaseUrl = _backendBaseUrl;
    if (rideId == null || backendBaseUrl == null) return;

    final delaySeconds = 1 << _reconnectAttempt.clamp(0, 5).toInt();
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      if (!_shouldReconnect || _isConnected) return;

      _connect(rideId: rideId, backendBaseUrl: backendBaseUrl).catchError((
        Object _,
      ) {
        _scheduleReconnect();
      });
    });
  }

  Future<void> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Please enable location services.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to track your ride.');
    }
  }

  /// Stops GPS and WebSocket connections.
  ///
  /// Call this when the rider explicitly ends the ride.
  Future<void> stopTracking() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _batteryRefreshTimer?.cancel();
    _batteryRefreshTimer = null;
    await _positionSubscription?.cancel();

    _positionSubscription = null;

    await _socketSubscription?.cancel();

    _socketSubscription = null;

    await _channel?.sink.close();

    _channel = null;

    _isTracking = false;
    _isConnected = false;
    _rideId = null;
    _backendBaseUrl = null;
    _latestPosition = null;
    _batteryLevel = null;
    _lastBatteryRefreshAt = null;
  }

  /// Stops only the guardian's receive-only connection.
  Future<void> disconnectGuardian() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _socketSubscription?.cancel();

    _socketSubscription = null;

    await _channel?.sink.close();

    _channel = null;

    _isConnected = false;
    _rideId = null;
    _backendBaseUrl = null;
  }

  /// Call only when the application-level service is no longer needed.
  Future<void> dispose() async {
    await stopTracking();

    await _positionController.close();

    await _messageController.close();
  }
}
