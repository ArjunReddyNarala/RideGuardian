import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../websocket/websocket_events.dart';

class RideLocationService {
  RideLocationService._();

  static final RideLocationService instance =
      RideLocationService._();

  StreamSubscription<Position>? _positionSubscription;

  StreamSubscription<dynamic>? _socketSubscription;

  WebSocketChannel? _channel;

  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();

  Stream<Position> get positions =>
      _positionController.stream;

  Stream<WebSocketMessage> get messages =>
      _messageController.stream;

  bool _isTracking = false;

  bool _isConnected = false;

  bool get isTracking => _isTracking;

  bool get isConnected => _isConnected;

  /// Rider connection: GPS updates are published to the backend.
  Future<void> startTracking({
    required String rideId,
    required String backendBaseUrl,
  }) async {
    if (_isTracking && _isConnected) return;

    await _checkLocationPermission();

    await _connect(
      rideId: rideId,
      backendBaseUrl: backendBaseUrl,
    );

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
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

    await _connect(
      rideId: rideId,
      backendBaseUrl: backendBaseUrl,
    );
  }

  Future<void> _connect({
    required String rideId,
    required String backendBaseUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Unable to retrieve Firebase ID token.',
      );
    }

    final wsBaseUrl = backendBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    final uri = Uri.parse(
      '$wsBaseUrl/ws/rides',
    ).replace(
      queryParameters: {
        'rideId': rideId,
        'token': token,
      },
    );

    final channel = WebSocketChannel.connect(uri);

    _channel = channel;

    try {
      await channel.ready.timeout(
        const Duration(seconds: 15),
      );

      _isConnected = true;

      _socketSubscription = channel.stream.listen(
        (event) {
          try {
            final decoded = jsonDecode(
              event.toString(),
            );

            if (decoded is Map<String, dynamic>) {
              _messageController.add(
                WebSocketMessage.fromJson(decoded),
              );
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

          _messageController.add(
            WebSocketMessage(
              type: WebSocketEvents.error,
              message: error.toString(),
            ),
          );
        },
        onDone: () {
          _isConnected = false;
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
    final channel = _channel;

    if (channel == null || !_isConnected) return;

    if (position.accuracy > 50) return;

    final speedKmh = position.speed < 0
        ? 0.0
        : position.speed * 3.6;

    final message = WebSocketMessage(
      type: WebSocketEvents.locationUpdate,
      data: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speedKmh': speedKmh,
        'accuracyMeters': position.accuracy,
        'headingDegrees': position.heading >= 0
            ? position.heading
            : 0,
      },
    );

    channel.sink.add(message.encode());
  }

  Future<void> _checkLocationPermission() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Please enable location services.',
      );
    }

    var permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is required to track your ride.',
      );
    }
  }

  /// Stops GPS and WebSocket connections.
  ///
  /// Call this when the rider explicitly ends the ride.
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;

    await _socketSubscription?.cancel();

    _socketSubscription = null;

    await _channel?.sink.close();

    _channel = null;

    _isTracking = false;
    _isConnected = false;
  }

  /// Stops only the guardian's receive-only connection.
  Future<void> disconnectGuardian() async {
    await _socketSubscription?.cancel();

    _socketSubscription = null;

    await _channel?.sink.close();

    _channel = null;

    _isConnected = false;
  }

  /// Call only when the application-level service is no longer needed.
  Future<void> dispose() async {
    await stopTracking();

    await _positionController.close();

    await _messageController.close();
  }
}
