import 'ride.dart';

class PaginatedRides {
  const PaginatedRides({
    required this.rides,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<Ride> rides;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory PaginatedRides.fromJson(Map<String, dynamic> json) {
    final rawRides = json['data'];
    final pagination = json['pagination'];

    if (rawRides is! List || pagination is! Map<String, dynamic>) {
      throw const FormatException('Invalid paginated rides response.');
    }

    int readInt(String key) {
      final value = pagination[key];
      if (value is! num || !value.isFinite || value < 0) {
        throw FormatException('Invalid pagination field: $key');
      }
      return value.toInt();
    }

    return PaginatedRides(
      rides: rawRides.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid ride item in response.');
        }
        return Ride.fromJson(item);
      }).toList(),
      page: readInt('page'),
      limit: readInt('limit'),
      total: readInt('total'),
      totalPages: readInt('totalPages'),
    );
  }
}
