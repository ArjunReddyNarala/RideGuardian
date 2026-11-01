class StartRideRequest {
  const StartRideRequest({
    required this.guardianIds,
  });

  final List<String> guardianIds;

  Map<String, dynamic> toJson() {
    return {
      'guardianIds': guardianIds,
    };
  }
}