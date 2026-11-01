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

typedef PulsingLocationMapBuilder = Widget Function(
  BuildContext context,
  Set<Circle> pulseCircles,
);

/// Adds low-frequency expanding and fading circles around a live map marker.
class PulsingLocationLayer extends StatefulWidget {
  const PulsingLocationLayer({
    super.key,
    required this.position,
    required this.builder,
    this.accuracyMeters,
  });

  final LatLng? position;
  final PulsingLocationMapBuilder builder;
  final double? accuracyMeters;

  @override
  State<PulsingLocationLayer> createState() => _PulsingLocationLayerState();
}

class _PulsingLocationLayerState extends State<PulsingLocationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ValueNotifier<double> _pulseProgress = ValueNotifier(0);
  final Stopwatch _frameClock = Stopwatch()..start();
  int _lastFrameMilliseconds = -100;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..addListener(_onAnimationTick);

    if (widget.position != null) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulsingLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.position == null && widget.position != null) {
      _controller.repeat();
    } else if (oldWidget.position != null && widget.position == null) {
      _controller.stop();
      _pulseProgress.value = 0;
    }
  }

  void _onAnimationTick() {
    final now = _frameClock.elapsedMilliseconds;
    if (now - _lastFrameMilliseconds < 70) return;

    _lastFrameMilliseconds = now;
    _pulseProgress.value = _controller.value;
  }

  Set<Circle> _buildPulseCircles(double progress) {
    final position = widget.position;
    if (position == null) return const <Circle>{};

    return {
      Circle(
        circleId: const CircleId('live_location_accuracy'),
        center: position,
        radius:
            widget.accuracyMeters != null &&
                widget.accuracyMeters!.isFinite &&
                widget.accuracyMeters! >= 0
            ? widget.accuracyMeters!
            : 20,
        fillColor: AppColors.primary.withValues(alpha: 0.1),
        strokeColor: AppColors.primary.withValues(alpha: 0.2),
        strokeWidth: 1,
        zIndex: -1,
      ),
      _pulseCircle(position, progress, 'live_location_pulse_a'),
      _pulseCircle(position, (progress + 0.5) % 1, 'live_location_pulse_b'),
    };
  }

  Circle _pulseCircle(LatLng position, double phase, String id) {
    final opacity = 1 - phase;
    return Circle(
      circleId: CircleId(id),
      center: position,
      radius: 18 + (phase * 68),
      fillColor: AppColors.primary.withValues(alpha: 0.1 * opacity),
      strokeColor: AppColors.primary.withValues(alpha: 0.28 * opacity),
      strokeWidth: 2,
      zIndex: -1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _pulseProgress,
      builder: (context, progress, _) {
        return widget.builder(context, _buildPulseCircles(progress));
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseProgress.dispose();
    _frameClock.stop();
    super.dispose();
  }
}
