import '../../../core/constants/api_urls.dart';
import '../../../core/network/api_client.dart';

import '../models/ride.dart';
import '../models/start_ride_request.dart';

class RidesApiService {
  RidesApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<Ride> createRide(StartRideRequest request) async {
    final response = await _apiClient.post(
      ApiUrls.rides,
      body: request.toJson(),
    );

    return Ride.fromJson(_requireObject(response));
  }

  Future<Ride?> getActiveRide() async {
    final response = await _apiClient.get(
      ApiUrls.activeRide,
    );

    if (response == null) return null;

    return Ride.fromJson(_requireObject(response));
  }

  Future<Ride> getRide(String rideId) async {
    final response = await _apiClient.get(
      ApiUrls.rideById(rideId),
    );

    return Ride.fromJson(_requireObject(response));
  }

  Future<void> addGuardian({
    required String rideId,
    required String guardianId,
  }) async {
    await _apiClient.post(
      ApiUrls.addRideGuardian(rideId),
      body: {
        'guardianId': guardianId,
      },
    );
  }

  Future<void> endRide(String rideId) async {
    await _apiClient.post(
      ApiUrls.endRide(rideId),
    );
  }

  /// Returns active rides assigned to the authenticated guardian.
  Future<List<Ride>> getGuardianActiveRides() async {
    final response = await _apiClient.get(
      ApiUrls.guardianActiveRides,
    );

    dynamic data = response;

    if (data is Map<String, dynamic> &&
        data.containsKey('data')) {
      data = data['data'];
    }

    if (data is! List) {
      throw const FormatException(
        'Invalid guardian active rides response.',
      );
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Invalid ride item received.',
        );
      }

      return Ride.fromJson(item);
    }).toList();
  }

  /// Retrieves the initial location and speed settings for
  /// a ride that the authenticated user is allowed to monitor.
  Future<Map<String, dynamic>> getTrackingSnapshot(
    String rideId,
  ) async {
    final response = await _apiClient.get(
      ApiUrls.rideTrackingSnapshot(rideId),
    );

    return _requireObject(response);
  }

  Map<String, dynamic> _requireObject(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];

      if (data is Map<String, dynamic>) {
        return data;
      }

      return response;
    }

    throw const FormatException(
      'Invalid ride response received from server.',
    );
  }

  Future<List<Ride>> getRides() async {
    final response = await _apiClient.get(
      ApiUrls.rides,
    );

    dynamic data = response;

    if (data is Map<String, dynamic> &&
        data.containsKey('data')) {
      data = data['data'];
    }

    if (data is! List) {
      throw const FormatException(
        'Invalid rides response received from server.',
      );
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Invalid ride item received.',
        );
      }

      return Ride.fromJson(item);
    }).toList();
  }
}