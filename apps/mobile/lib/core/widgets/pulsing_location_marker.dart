import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

class LiveLocationMarker {
  LiveLocationMarker._();

  static Future<BitmapDescriptor> createIcon() async {
    const imageSize = 192.0;
    const logicalSize = 64.0;
    final center = Offset(imageSize / 2, imageSize / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      center,
      66,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          66,
          [
            AppColors.primary.withValues(alpha: 0.24),
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0),
          ],
          const [0, 0.58, 1],
        ),
    );
    canvas.drawCircle(
      center,
      39,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, 35, Paint()..color = Colors.white);
    canvas.drawCircle(center, 26, Paint()..color = AppColors.primary);

    final image = await recorder.endRecording().toImage(
      imageSize.toInt(),
      imageSize.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (data == null) {
      throw StateError('Unable to render the live location marker.');
    }

    final bytes = data.buffer.asUint8List();
    return BitmapDescriptor.bytes(
      Uint8List.fromList(bytes),
      width: logicalSize,
      height: logicalSize,
    );
  }
}

typedef LocationAccuracyMapBuilder = Widget Function(
  BuildContext context,
  Set<Circle> pulseCircles,
);

/// Builds one stable GPS accuracy circle for a live map marker.
///
/// Keeping animation out of the GoogleMap widget prevents native overlay
/// updates from being sent every animation frame, including during teardown.
class LocationAccuracyLayer extends StatelessWidget {
  const LocationAccuracyLayer({
    super.key,
    required this.position,
    required this.builder,
    this.accuracyMeters,
  });

  final LatLng? position;
  final LocationAccuracyMapBuilder builder;
  final double? accuracyMeters;

  Widget build(BuildContext context) {
    final currentPosition = position;
    if (currentPosition == null) {
      return builder(context, const <Circle>{});
    }

    final accuracy = accuracyMeters;
    final radius = accuracy != null && accuracy.isFinite && accuracy >= 0
        ? accuracy
        : 20.0;

    return builder(context, {
      Circle(
        circleId: const CircleId('live_location_accuracy'),
        center: currentPosition,
        radius: radius,
        fillColor: AppColors.primary.withValues(alpha: 0.1),
        strokeColor: AppColors.primary.withValues(alpha: 0.2),
        strokeWidth: 1,
        zIndex: -1,
      ),
    });
  }
}
