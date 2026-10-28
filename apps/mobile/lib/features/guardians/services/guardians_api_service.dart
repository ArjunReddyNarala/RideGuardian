import '../../../core/constants/api_urls.dart';
import '../../../core/network/api_client.dart';
import '../models/guardian_invitation.dart';
import '../models/guardian_relationship.dart';
import '../models/rider_safety_settings.dart';

class GuardiansApiService {
  GuardiansApiService(this._apiClient);

  final ApiClient _apiClient;

  // ------------------------------------------------------------
  // Guardian relationships
  // ------------------------------------------------------------

  Future<List<GuardianRelationship>> getRelationships() async {
    final response = await _apiClient.get(ApiUrls.guardianRelationships);

    final data = _extractList(response);

    return data.map((json) => GuardianRelationship.fromJson(json)).toList();
  }

  Future<void> revokeRelationship(String relationshipId) async {
    await _apiClient.patch(ApiUrls.revokeRelationship(relationshipId));
  }

  // ------------------------------------------------------------
  // Invitations
  // ------------------------------------------------------------

  Future<List<GuardianInvitation>> getInvitations() async {
    final response = await _apiClient.get(ApiUrls.invitations);

    return _extractList(response).map(GuardianInvitation.fromJson).toList();
  }

  Future<Map<String, dynamic>> createInvitation({
    required String relationshipType,
    String? email,
    String? phone,
  }) async {
    final normalizedEmail = email?.trim().toLowerCase();
    final normalizedPhone = phone?.trim();

    if ((normalizedEmail == null || normalizedEmail.isEmpty) &&
        (normalizedPhone == null || normalizedPhone.isEmpty)) {
      throw ArgumentError('An email address or phone number is required.');
    }

    if (normalizedEmail != null &&
        normalizedEmail.isNotEmpty &&
        normalizedPhone != null &&
        normalizedPhone.isNotEmpty) {
      throw ArgumentError(
        'Provide either an email address or a phone number, not both.',
      );
    }

    final body = <String, dynamic>{
      'relationshipType': relationshipType,
      if (normalizedEmail != null && normalizedEmail.isNotEmpty)
        'inviteeEmail': normalizedEmail,
      if (normalizedPhone != null && normalizedPhone.isNotEmpty)
        'inviteePhone': normalizedPhone,
    };

    final response = await _apiClient.post(ApiUrls.invitations, body: body);

    if (response is Map<String, dynamic>) {
      return response;
    }

    return <String, dynamic>{};
  }

  Future<void> acceptInvitation(String token) async {
    await _apiClient.patch(ApiUrls.acceptInvitation(token));
  }

  Future<void> declineInvitation(String token) async {
    await _apiClient.patch(ApiUrls.declineInvitation(token));
  }

  Future<void> cancelInvitation(String invitationId) async {
    await _apiClient.patch(ApiUrls.cancelInvitation(invitationId));
  }

  // ------------------------------------------------------------
  // Rider safety settings
  // ------------------------------------------------------------

  Future<List<RiderSafetySettings>> getSafetySettings() async {
    final response = await _apiClient.get(ApiUrls.riderSafetySettings);

    return _extractList(response).map(RiderSafetySettings.fromJson).toList();
  }

  Future<void> updateSafetySettings({
    required String riderId,
    double? maxSpeedKmh,
    bool? speedAlertEnabled,
    int? speedAlertCooldownSeconds,
  }) async {
    final body = <String, dynamic>{
      if (maxSpeedKmh != null) 'maxSpeedKmh': maxSpeedKmh,
      if (speedAlertEnabled != null) 'speedAlertEnabled': speedAlertEnabled,
      if (speedAlertCooldownSeconds != null)
        'speedAlertCooldownSeconds': speedAlertCooldownSeconds,
    };

    await _apiClient.put(
      ApiUrls.riderSafetySettingsForRider(riderId),
      body: body,
    );
  }

  // ------------------------------------------------------------
  // Response parsing
  // ------------------------------------------------------------

  List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (response is Map<String, dynamic>) {
      // Supports common paginated/enveloped API response formats.
      final data = response['data'] ?? response['items'];

      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    throw const FormatException(
      'The server returned an unexpected list response.',
    );
  }
}
