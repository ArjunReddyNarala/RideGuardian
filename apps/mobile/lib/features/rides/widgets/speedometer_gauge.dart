import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SpeedometerGauge extends StatelessWidget {
  const SpeedometerGauge({
    super.key,
    required this.speedKmh,
    this.speedLimitKmh,
    this.isRider = true,
    this.isSpeedAvailable = true,
  });

  static const double _maximumSpeed = 240;

  final double speedKmh;
  final double? speedLimitKmh;
  final bool isRider;
  final bool isSpeedAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final targetSpeed = isSpeedAvailable ? speedKmh : 0.0;

    return Column(
      children: [
        SizedBox(
          height: 238,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: targetSpeed),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, animatedSpeed, _) {
              final isOverLimit =
                  speedLimitKmh != null && animatedSpeed > speedLimitKmh!;
              final activeColor = isOverLimit
                  ? AppColors.danger
                  : AppColors.primary;

              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _SpeedometerPainter(
                      speedKmh: animatedSpeed,
                      maximumSpeed: _maximumSpeed,
                      speedLimitKmh: speedLimitKmh,
                      activeColor: activeColor,
                    ),
                  ),
                  Positioned(
                    top: 78,
                    left: 42,
                    right: 42,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'km/h',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          child: Text(
                            isSpeedAvailable
                                ? speedKmh.toStringAsFixed(2)
                                : '—',
                            key: ValueKey(
                              isSpeedAvailable
                                  ? speedKmh.toStringAsFixed(2)
                                  : 'unavailable',
                            ),
                            maxLines: 1,
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: colors.onSurface,
                              fontSize: 46,
                              height: 1,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -1.8,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isRider ? 'Current Speed' : 'Rider Speed',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  const _SpeedometerPainter({
    required this.speedKmh,
    required this.maximumSpeed,
    required this.speedLimitKmh,
    required this.activeColor,
  });

  final double speedKmh;
  final double maximumSpeed;
  final double? speedLimitKmh;
  final Color activeColor;

  static const double _startAngle = 135 * math.pi / 180;
  static const double _sweepAngle = 270 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    final radius = math.min(size.width * 0.46, size.height * 0.505);
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final ratio = (speedKmh / maximumSpeed).clamp(0.0, 1.0);

    // The subdued track remains unlit; the colored arc represents measured
    // speed and changes to the danger palette only after the configured limit.
    canvas.drawArc(
      bounds,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFF111A17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.butt,
    );

    canvas.drawArc(
      bounds,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFF52605A).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    if (ratio > 0) {
      final activeSweep = _sweepAngle * ratio;
      canvas.drawArc(
        bounds,
        _startAngle,
        activeSweep,
        false,
        Paint()
          ..color = activeColor.withValues(alpha: 0.36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 42
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawArc(
        bounds,
        _startAngle,
        activeSweep,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: _startAngle,
            endAngle: _startAngle + 2 * math.pi,
            colors: [
              activeColor.withValues(alpha: 0.68),
              activeColor,
              Color.lerp(activeColor, Colors.white, 0.48)!,
            ],
            stops: const [0, 0.78, 1],
          ).createShader(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 29
          ..strokeCap = StrokeCap.butt,
      );
      canvas.drawArc(
        bounds.deflate(2.8),
        _startAngle,
        activeSweep,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    _drawTicks(canvas, center, radius, ratio);
    _drawEndpointLabels(canvas, center, radius);

    if (speedLimitKmh != null && speedLimitKmh! <= maximumSpeed) {
      final limitRatio = (speedLimitKmh! / maximumSpeed).clamp(0.0, 1.0);
      final limitAngle = _startAngle + _sweepAngle * limitRatio;
      _drawDialMarker(
        canvas,
        center,
        radius,
        limitAngle,
        AppColors.warning,
        width: 3.5,
        innerOffset: 3,
        outerOffset: 7,
      );
    }

    final speedAngle = _startAngle + _sweepAngle * ratio;
    _drawDialMarker(
      canvas,
      center,
      radius,
      speedAngle,
      Colors.white,
      width: 5,
      innerOffset: 1,
      outerOffset: 5,
    );
  }

  void _drawTicks(Canvas canvas, Offset center, double radius, double ratio) {
    const divisions = 12;
    for (var index = 0; index <= divisions; index++) {
      final tickRatio = index / divisions;
      final angle = _startAngle + _sweepAngle * tickRatio;
      final isMajor = index % 3 == 0;
      final tickColor = tickRatio <= ratio
          ? Colors.black.withValues(alpha: 0.84)
          : Colors.white.withValues(alpha: 0.62);

      canvas.drawLine(
        _point(center, radius - (isMajor ? 43 : 33), angle),
        _point(center, radius - 4, angle),
        Paint()
          ..color = tickColor
          ..strokeWidth = isMajor ? 2.2 : 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawEndpointLabels(Canvas canvas, Offset center, double radius) {
    _drawLabel(
      canvas,
      '0',
      _point(center, radius - 15, _startAngle),
      Colors.white,
    );
    _drawLabel(
      canvas,
      maximumSpeed.toStringAsFixed(0),
      _point(center, radius - 15, _startAngle + _sweepAngle),
      Colors.white,
    );
  }

  void _drawDialMarker(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Color color, {
    required double width,
    required double innerOffset,
    required double outerOffset,
  }) {
    canvas.drawLine(
      _point(center, radius - 36 - innerOffset, angle),
      _point(center, radius + outerOffset, angle),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  Offset _point(Offset center, double radius, double angle) {
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  void _drawLabel(Canvas canvas, String label, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return speedKmh != oldDelegate.speedKmh ||
        maximumSpeed != oldDelegate.maximumSpeed ||
        speedLimitKmh != oldDelegate.speedLimitKmh ||
        activeColor != oldDelegate.activeColor;
  }
}
