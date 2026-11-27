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
    final isOverLimit = speedLimitKmh != null && speedKmh > speedLimitKmh!;
    final accent = isOverLimit ? AppColors.danger : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17231F), Color(0xFF0B1210)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF34463E), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.speed_rounded, color: accent, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  isRider ? 'RIDER SPEED' : 'LIVE RIDER SPEED',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFDDE8E2),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 204,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: speedKmh),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, animatedSpeed, _) {
                final overLimit =
                    speedLimitKmh != null && animatedSpeed > speedLimitKmh!;
                final activeColor = overLimit
                    ? AppColors.danger
                    : AppColors.primary;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _RacingGaugePainter(
                        speedKmh: isSpeedAvailable ? animatedSpeed : 0,
                        maximumSpeed: _maximumSpeed,
                        speedLimitKmh: speedLimitKmh,
                        activeColor: activeColor,
                      ),
                    ),
                    Positioned(
                      top: 72,
                      left: 30,
                      right: 30,
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              isSpeedAvailable
                                  ? speedKmh.toStringAsFixed(0)
                                  : '—',
                              key: ValueKey(
                                isSpeedAvailable
                                    ? speedKmh.toStringAsFixed(0)
                                    : 'no-gps',
                              ),
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSpeedAvailable ? 68 : 40,
                                height: 0.98,
                                fontWeight: FontWeight.w800,
                                letterSpacing: isSpeedAvailable ? -3.2 : 0,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 15,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'km/h',
                            style: TextStyle(
                              color: Color(0xFF9FB0A7),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.3,
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
          Row(
            children: [
              _RangeLabel(value: '0', caption: 'MIN'),
              const Spacer(),
              if (speedLimitKmh != null)
                _SpeedLimitPill(speedLimitKmh: speedLimitKmh!),
              const Spacer(),
              _RangeLabel(value: '240', caption: 'MAX'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeLabel extends StatelessWidget {
  const _RangeLabel({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFE9F1EC),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          caption,
          style: const TextStyle(
            color: Color(0xFF788A80),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _SpeedLimitPill extends StatelessWidget {
  const _SpeedLimitPill({required this.speedLimitKmh});

  final double speedLimitKmh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Text(
        'LIMIT ${speedLimitKmh.toStringAsFixed(0)}',
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _RacingGaugePainter extends CustomPainter {
  const _RacingGaugePainter({
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
    final center = Offset(size.width / 2, size.height * 0.51);
    final radius = math.min(size.width * 0.39, size.height * 0.49);
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final ratio = (speedKmh / maximumSpeed).clamp(0.0, 1.0);

    canvas.drawArc(
      bounds,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFF35463E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );

    _drawTicks(canvas, center, radius, ratio);

    if (ratio > 0) {
      final activeSweep = _sweepAngle * ratio;
      canvas.drawArc(
        bounds,
        _startAngle,
        activeSweep,
        false,
        Paint()
          ..color = activeColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawArc(
        bounds,
        _startAngle,
        activeSweep,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: _startAngle,
            endAngle: _startAngle + _sweepAngle,
            colors: [
              activeColor.withValues(alpha: 0.62),
              activeColor,
              Color.lerp(activeColor, Colors.white, 0.35)!,
            ],
            stops: const [0, 0.72, 1],
          ).createShader(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );

      final angle = _startAngle + activeSweep;
      final needleStart = _point(center, radius - 26, angle);
      final needleEnd = _point(center, radius + 4, angle);
      canvas.drawLine(
        needleStart,
        needleEnd,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.94)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(needleEnd, 4, Paint()..color = activeColor);
    }

    if (speedLimitKmh != null && speedLimitKmh! <= maximumSpeed) {
      final limitRatio = (speedLimitKmh! / maximumSpeed).clamp(0.0, 1.0);
      final angle = _startAngle + _sweepAngle * limitRatio;
      canvas.drawLine(
        _point(center, radius - 17, angle),
        _point(center, radius + 8, angle),
        Paint()
          ..color = AppColors.warning
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawTicks(Canvas canvas, Offset center, double radius, double ratio) {
    const divisions = 24;
    for (var index = 0; index <= divisions; index++) {
      final tickRatio = index / divisions;
      final angle = _startAngle + _sweepAngle * tickRatio;
      final isMajor = index % 3 == 0;
      final passed = tickRatio <= ratio;
      final color = passed
          ? activeColor.withValues(alpha: 0.90)
          : Colors.white.withValues(alpha: isMajor ? 0.52 : 0.20);
      canvas.drawLine(
        _point(center, radius - (isMajor ? 18 : 13), angle),
        _point(center, radius - 3, angle),
        Paint()
          ..color = color
          ..strokeWidth = isMajor ? 2.2 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  Offset _point(Offset center, double radius, double angle) => Offset(
    center.dx + radius * math.cos(angle),
    center.dy + radius * math.sin(angle),
  );

  @override
  bool shouldRepaint(covariant _RacingGaugePainter oldDelegate) =>
      speedKmh != oldDelegate.speedKmh ||
      maximumSpeed != oldDelegate.maximumSpeed ||
      speedLimitKmh != oldDelegate.speedLimitKmh ||
      activeColor != oldDelegate.activeColor;
}
