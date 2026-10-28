import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';

class LiveMapCard extends StatefulWidget {
  const LiveMapCard({super.key});

  @override
  State<LiveMapCard> createState() => _LiveMapCardState();
}

class _LiveMapCardState extends State<LiveMapCard> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  bool _isLoading = true;
  bool _isFollowingLocation = true;
  String? _locationError;

  static const LatLng _fallbackLocation = LatLng(17.3850, 78.4867);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _setLocationError('Location services are disabled. Please enable GPS.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setLocationError(
          'Location permission is required to show your live location.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationError(
          'Location access is disabled for RideGuardian. '
          'Enable it in your device settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _locationError = null;
      });

      await _moveCamera(position);

      await _positionSubscription?.cancel();

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 2,
            ),
          ).listen(
            _onPositionUpdate,
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('RideGuardian location stream error: $error');

              if (!mounted) return;

              setState(() {
                _locationError = 'Unable to update your live location.';
              });
            },
          );
    } catch (error, stackTrace) {
      debugPrint('RideGuardian location error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _setLocationError(
        'Unable to get your location. '
        'Please check location access and try again.',
      );
    }
  }

  void _setLocationError(String message) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _locationError = message;
    });
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _locationError = null;
    });

    if (_isFollowingLocation) {
      _moveCamera(position);
    }
  }

  Future<void> _moveCamera(Position position) async {
    final controller = _mapController;

    if (controller == null) return;

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.5,
            tilt: 0,
            bearing: 0,
          ),
        ),
      );
    } catch (error) {
      debugPrint('RideGuardian map camera update error: $error');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    final position = _currentPosition;

    if (position != null) {
      _moveCamera(position);
    }
  }

  Future<void> _recenterMap() async {
    final position = _currentPosition;

    if (position == null) {
      await _initializeLocation();
      return;
    }

    setState(() {
      _isFollowingLocation = true;
    });

    await _moveCamera(position);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = theme.scaffoldBackgroundColor;

    final currentPosition = _currentPosition;

    final initialTarget = currentPosition == null
        ? _fallbackLocation
        : LatLng(currentPosition.latitude, currentPosition.longitude);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: SizedBox(
          height: 260,
          width: double.infinity,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: 15,
                ),
                onMapCreated: _onMapCreated,

                // Keep Google Maps gestures enabled.
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,

                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
                buildingsEnabled: true,
                trafficEnabled: false,

                // Give map gestures priority over the parent scroll view.
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },

                onCameraMoveStarted: () {
                  if (_isFollowingLocation && mounted) {
                    setState(() {
                      _isFollowingLocation = false;
                    });
                  }
                },

                // Use the normal Google Maps appearance.
                style: null,

                markers: currentPosition == null
                    ? <Marker>{}
                    : <Marker>{
                        Marker(
                          markerId: const MarkerId('rider_location'),
                          position: LatLng(
                            currentPosition.latitude,
                            currentPosition.longitude,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                          infoWindow: const InfoWindow(
                            title: 'Your location',
                            snippet: 'RideGuardian live tracking',
                          ),
                        ),
                      },
              ),

              // Location loading state.
              if (_isLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: isDark
                        ? const Color(0xCC101918)
                        : const Color(0xCCF8FAFC),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Finding your location...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Location error state.
              if (!_isLoading && _locationError != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: isDark
                        ? const Color(0xEE101918)
                        : const Color(0xEEF8FAFC),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_off_rounded,
                              color: AppColors.primary,
                              size: 34,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _locationError!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _initializeLocation,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Live location status badge.
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xE6192421)
                        : const Color(0xEFFFFFFF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: currentPosition != null
                              ? AppColors.primary
                              : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentPosition != null ? 'LIVE LOCATION' : 'LOCATION',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recenter on the rider's current location.
              Positioned(
                right: 14,
                bottom: 14,
                child: Material(
                  color: isDark ? const Color(0xF0192421) : Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _recenterMap,
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.my_location_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),

              // Soft dissolving edge effect.
              // IgnorePointer ensures this layer does not block map gestures.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          backgroundColor.withValues(alpha: 0.16),
                          Colors.transparent,
                          Colors.transparent,
                          backgroundColor.withValues(alpha: 0.18),
                        ],
                        stops: const [0.0, 0.16, 0.82, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
