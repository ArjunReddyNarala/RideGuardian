class ApiUrls {
  ApiUrls._();

  static const String apiPrefix = '/api/v1';

  // Guardian relationships.
  static const String guardianRelationships =
      '$apiPrefix/guardian-relationships';
  static const String guardians = '$apiPrefix/guardians';

  static String revokeRelationship(String relationshipId) =>
      '$guardianRelationships/$relationshipId/revoke';

  // Invitations.
  static const String invitations = '$apiPrefix/invitations';

  static String acceptInvitation(String token) => '$invitations/$token/accept';

  static String declineInvitation(String token) =>
      '$invitations/$token/decline';

  static String cancelInvitation(String invitationId) =>
      '$invitations/$invitationId/cancel';

  // Rider safety settings.
  static const String riderSafetySettings = '$apiPrefix/rider-safety-settings';

  static String riderSafetySettingsForRider(String riderId) =>
      '$riderSafetySettings/$riderId';

  // Rides.
  static const String rides = '$apiPrefix/rides';

  static const String activeRide = '$rides/active';

  static const String favoriteGuardians = '$rides/favorite-guardians';

  static String rideById(String rideId) => '$rides/$rideId';

  static String endRide(String rideId) => '$rides/$rideId/end';

  static String addRideGuardian(String rideId) => '$rides/$rideId/guardians';

  static String rideGuardians(String rideId) => '$rides/$rideId/guardians';

  static String rideLocations(String rideId) => '$rides/$rideId/locations';

  static String rideCurrentLocation(String rideId) =>
      '$rides/$rideId/current-location';

  static String rideSummary(String rideId) => '$rides/$rideId/summary';

  static const String guardianActiveRides = '$rides/monitoring/active';

  static const String guardianRideSummary = '$rides/monitoring/summary';

  static const String guardianRideHistory = '$rides/monitoring/history';

  static String rideTrackingSnapshot(String rideId) =>
      '$rides/$rideId/tracking-snapshot';
}
