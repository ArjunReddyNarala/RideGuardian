class ApiUrls {
  ApiUrls._();

  static const String apiPrefix = '/api/v1';

  // Guardian relationships.
  static const String guardianRelationships =
      '$apiPrefix/guardian-relationships';

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
}
