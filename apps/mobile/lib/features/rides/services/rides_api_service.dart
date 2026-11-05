import 'package:flutter/foundation.dart';

import '../../../core/constants/api_urls.dart';
import '../../../core/network/api_client.dart';

import '../models/ride.dart';
import '../models/paginated_rides.dart';
import '../models/favorite_guardian.dart';
import '../models/ride_guardian.dart';
import '../models/start_ride_request.dart';

enum RideLifecycleChange { started, ended }

class RidesApiService extends ChangeNotifier {
  RidesApiService(this._apiClient);

  final ApiClient _apiClient;
  RideLifecycleChange? _lastLifecycleChange;

  RideLifecycleChange? get lastLifecycleChange => _lastLifecycleChange;

  void _publishLifecycleChange(RideLifecycleChange change) {
    _lastLifecycleChange = change;
    notifyListeners();
  }

  Future<Ride> createRide(StartRideRequest request) async {
    final response = await _apiClient.post(
      ApiUrls.rides,
      body: request.toJson(),
    );

    final ride = Ride.fromJson(_requireObject(response));
    _publishLifecycleChange(RideLifecycleChange.started);
    return ride;
  }

  Future<Ride?> getActiveRide() async {
    final response = await _apiClient.get(ApiUrls.activeRide);

    if (response == null) return null;

    return Ride.fromJson(_requireObject(response));
  }

  Future<Ride> getRide(String rideId) async {
    final response = await _apiClient.get(ApiUrls.rideById(rideId));

    return Ride.fromJson(_requireObject(response));
  }

  Future<void> addGuardian({
    required String rideId,
    required String guardianId,
  }) async {
    await _apiClient.post(
      ApiUrls.addRideGuardian(rideId),
      body: {'guardianId': guardianId},
    );
  }

  Future<List<RideGuardian>> getRideGuardians(String rideId) async {
    final response = await _apiClient.get(ApiUrls.rideGuardians(rideId));
    dynamic data = response;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      data = data['data'];
    }
    if (data is! List) {
      throw const FormatException('Invalid ride guardians response.');
    }
    return data
        .whereType<Map>()
        .map((item) => RideGuardian.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> endRide(String rideId) async {
    await _apiClient.post(ApiUrls.endRide(rideId));
    _publishLifecycleChange(RideLifecycleChange.ended);
  }

  /// Returns active rides assigned to the authenticated guardian.
  Future<List<Ride>> getGuardianActiveRides() async {
    final response = await _apiClient.get(ApiUrls.guardianActiveRides);

    dynamic data = response;

    if (data is Map<String, dynamic> && data.containsKey('data')) {
      data = data['data'];
    }

    if (data is! List) {
      throw const FormatException('Invalid guardian active rides response.');
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid ride item received.');
      }

      return Ride.fromJson(item);
    }).toList();
  }

  Future<int> getGuardianRidesCoveredCount() async {
    final response = await _apiClient.get(ApiUrls.guardianRideSummary);
    dynamic data = response;

    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      data = data['data'];
    }

    if (data is Map<String, dynamic> && data['ridesCovered'] is num) {
      return (data['ridesCovered'] as num).toInt();
    }

    throw const FormatException('Invalid guardian ride summary response.');
  }

  Future<List<FavoriteGuardian>> getFavoriteGuardians() async {
    final response = await _apiClient.get(ApiUrls.favoriteGuardians);
    dynamic data = response;

    if (data is Map<String, dynamic> && data.containsKey('data')) {
      data = data['data'];
    }
    if (data is! List) {
      throw const FormatException('Invalid favorite guardians response.');
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid favorite guardian item.');
      }
      return FavoriteGuardian.fromJson(item);
    }).toList();
  }

  /// Retrieves the initial location and speed settings for
  /// a ride that the authenticated user is allowed to monitor.
  Future<Map<String, dynamic>> getTrackingSnapshot(String rideId) async {
    final response = await _apiClient.get(ApiUrls.rideTrackingSnapshot(rideId));

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

    throw const FormatException('Invalid ride response received from server.');
  }

  Future<PaginatedRides> getRides({int page = 1, int limit = 20}) async {
    _validatePagination(page, limit);
    final response = await _apiClient.get(
      ApiUrls.rides,
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );

    return PaginatedRides.fromJson(_requirePaginatedObject(response));
  }

  Future<PaginatedRides> getGuardianRideHistory({
    int page = 1,
    int limit = 20,
  }) async {
    _validatePagination(page, limit);
    final response = await _apiClient.get(
      ApiUrls.guardianRideHistory,
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );

    return PaginatedRides.fromJson(_requirePaginatedObject(response));
  }

  void _validatePagination(int page, int limit) {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'Must be at least 1.');
    }
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 50.');
    }
  }

  Map<String, dynamic> _requirePaginatedObject(dynamic response) {
    if (response is Map<String, dynamic> &&
        response['data'] is List &&
        response['pagination'] is Map<String, dynamic>) {
      return response;
    }

    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      final nested = response['data'] as Map<String, dynamic>;
      if (nested['data'] is List &&
          nested['pagination'] is Map<String, dynamic>) {
        return nested;
      }
    }

    throw const FormatException('Invalid paginated rides response.');
  }
}
