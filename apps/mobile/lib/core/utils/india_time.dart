const Duration _indiaStandardTimeOffset = Duration(hours: 5, minutes: 30);

/// Converts an instant to the wall-clock fields used for India Standard Time.
///
/// The returned value is kept in UTC so the device's local timezone cannot
/// shift it again during formatting. Use its date/time fields for display only.
DateTime toIndiaStandardTime(DateTime instant) {
  return instant.toUtc().add(_indiaStandardTimeOffset);
}

DateTime indiaStandardNow() {
  return toIndiaStandardTime(DateTime.now());
}
