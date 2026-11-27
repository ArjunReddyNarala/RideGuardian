import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/india_time.dart';
import '../models/ride.dart';
import '../models/ride_guardian.dart';
import '../models/ride_location_point.dart';
import '../models/ride_summary.dart';
import '../services/rides_api_service.dart';

class RideHistoryDetailScreen extends StatefulWidget {
  const RideHistoryDetailScreen({
    super.key,
    required this.ride,
    required this.ridesApiService,
    this.isMonitoredRide = false,
  });

  final Ride ride;
  final RidesApiService ridesApiService;
  final bool isMonitoredRide;

  @override
  State<RideHistoryDetailScreen> createState() =>
      _RideHistoryDetailScreenState();
}

class _RideHistoryDetailScreenState extends State<RideHistoryDetailScreen> {
  GoogleMapController? _mapController;
  List<RideLocationPoint> _locations = const [];
  List<RideGuardian> _guardians = const [];
  RideSummary? _summary;
  bool _loading = true;
  String? _error;

  List<LatLng> get _routePoints => _locations
      .map((point) => LatLng(point.latitude, point.longitude))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detailsRequests = <Future<Object>>[
        widget.isMonitoredRide
            ? widget.ridesApiService.getMonitoredRideSummary(widget.ride.id)
            : widget.ridesApiService.getRideSummary(widget.ride.id),
        widget.isMonitoredRide
            ? widget.ridesApiService.getMonitoredRideLocations(widget.ride.id)
            : widget.ridesApiService.getRideLocations(widget.ride.id),
        if (!widget.isMonitoredRide)
          widget.ridesApiService.getRideHistoryGuardians(widget.ride.id),
      ];
      final results = await Future.wait<Object>(detailsRequests);
      if (!mounted) return;

      setState(() {
        _summary = results[0] as RideSummary;
        _locations = results[1] as List<RideLocationPoint>;
        _guardians = widget.isMonitoredRide
            ? const []
            : results[2] as List<RideGuardian>;
        _loading = false;
      });
      _fitMapToRoute();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _fitMapToRoute() async {
    final controller = _mapController;
    final points = _routePoints;
    if (controller == null || points.isEmpty) return;

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
      return;
    }

    var south = points.first.latitude;
    var north = south;
    var west = points.first.longitude;
    var east = west;
    for (final point in points.skip(1)) {
      south = point.latitude < south ? point.latitude : south;
      north = point.latitude > north ? point.latitude : north;
      west = point.longitude < west ? point.longitude : west;
      east = point.longitude > east ? point.longitude : east;
    }

    if (south == north && west == east) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        48,
      ),
    );
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading && _summary == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _summary == null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  if (_error != null) ...[
                    _buildRefreshError(colors),
                    const SizedBox(height: 12),
                  ],
                  _buildRideHeader(colors),
                  const SizedBox(height: 16),
                  _buildRouteCard(colors),
                  const SizedBox(height: 22),
                  _sectionTitle('Ride summary'),
                  const SizedBox(height: 11),
                  _buildSummaryGrid(colors),
                  const SizedBox(height: 22),
                  _sectionTitle('Ride timeline'),
                  const SizedBox(height: 11),
                  _buildTimeline(colors),
                  if (!widget.isMonitoredRide) ...[
                    const SizedBox(height: 22),
                    _sectionTitle('Guardians on this ride'),
                    const SizedBox(height: 11),
                    _buildGuardians(colors),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load this ride',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadDetails,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshError(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Could not refresh ride details. Showing the last loaded information.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideHeader(ColorScheme colors) {
    final ride = widget.ride;
    final statusColor = ride.isCompleted
        ? AppColors.primary
        : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: AppColors.primary,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.displayLabel,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isMonitoredRide
                      ? 'Rider • ${ride.riderName ?? 'Ride participant'}'
                      : 'Ride completed',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ride.status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(ColorScheme colors) {
    final points = _routePoints;
    return Container(
      height: 282,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: points.isEmpty
          ? _buildNoRoute(colors)
          : Stack(
              children: [
                GoogleMap(
                  key: ValueKey('ride-history-map-${widget.ride.id}'),
                  initialCameraPosition: CameraPosition(
                    target: points.first,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    unawaited(_fitMapToRoute());
                  },
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('ride-start'),
                      position: points.first,
                      infoWindow: const InfoWindow(title: 'Ride started'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                    ),
                    if (points.length > 1)
                      Marker(
                        markerId: const MarkerId('ride-end'),
                        position: points.last,
                        infoWindow: const InfoWindow(title: 'Ride ended'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                  },
                  polylines: points.length > 1
                      ? {
                          Polyline(
                            polylineId: const PolylineId('ride-route'),
                            points: points,
                            color: AppColors.primary,
                            width: 6,
                            geodesic: true,
                          ),
                        }
                      : const {},
                ),
              ],
            ),
    );
  }

  Widget _buildNoRoute(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 42, color: colors.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              'Route history unavailable',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'No saved GPS points were found for this ride.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800),
  );

  Widget _buildSummaryGrid(ColorScheme colors) {
    final summary = _summary!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                colors,
                'Distance',
                '${summary.distanceKm.toStringAsFixed(2)} km',
                Icons.route_rounded,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _summaryTile(
                colors,
                'Duration',
                _formatDuration(summary.durationSeconds),
                Icons.timer_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                colors,
                'Average speed',
                '${summary.averageSpeedKmh.toStringAsFixed(1)} km/h',
                Icons.speed_rounded,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _summaryTile(
                colors,
                'Highest saved speed',
                summary.maxSpeedKmh == null
                    ? 'Unavailable'
                    : '${summary.maxSpeedKmh!.toStringAsFixed(1)} km/h',
                Icons.bolt_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryTile(
    ColorScheme colors,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ColorScheme colors) {
    final end = widget.ride.endedAt;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          _timelinePoint(
            color: AppColors.primary,
            title: 'Started',
            value: _formatDateTime(widget.ride.startedAt),
          ),
          if (end != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Container(
                width: 2,
                height: 24,
                color: colors.outlineVariant,
              ),
            ),
            _timelinePoint(
              color: AppColors.warning,
              title: 'Ended',
              value: _formatDateTime(end),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timelinePoint({
    required Color color,
    required String title,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(Icons.circle, size: 15, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuardians(ColorScheme colors) {
    if (_guardians.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Text(
          'No guardians were assigned to this ride.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: _guardians
          .map((guardian) => _guardianCard(guardian, colors))
          .toList(),
    );
  }

  Widget _guardianCard(RideGuardian guardian, ColorScheme colors) {
    final imageUrl = guardian.profileImageUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: imageUrl == null || imageUrl.isEmpty
                ? null
                : NetworkImage(imageUrl),
            child: imageUrl == null || imageUrl.isEmpty
                ? const Icon(Icons.person_rounded, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardian.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (guardian.email != null && guardian.email!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    guardian.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.verified_user_rounded, color: AppColors.primary),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final indiaDateTime = toIndiaStandardTime(dateTime);
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(indiaDateTime);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(indiaDateTime));
    return '$date • $time IST';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${remainingSeconds}s';
    return '${remainingSeconds}s';
  }
}
