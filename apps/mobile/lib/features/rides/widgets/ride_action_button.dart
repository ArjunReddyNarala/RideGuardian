import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shared ride CTA styling used on Home, My Rides, and Start a Ride.
class RideActionButton extends StatelessWidget {
  const RideActionButton({
    super.key,
    required this.onPressed,
    this.label = 'Start a ride',
    this.icon = Icons.route_rounded,
    this.isLoading = false,
    this.isEnabled = true,
    this.height = 62,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final bool isLoading;
  final bool isEnabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canPress = isEnabled && !isLoading && onPressed != null;
    final isAvailable = isEnabled || isLoading;
    final accent = isAvailable ? AppColors.primary : colors.onSurfaceVariant;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: AppColors.primary.withValues(alpha: isAvailable ? 0.35 : 0.14),
      ),
    );

    return Semantics(
      button: true,
      enabled: canPress,
      label: isLoading ? 'Starting ride' : label,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Material(
          color: colors.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.52 : 0.72,
          ),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canPress ? onPressed : null,
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(
                        alpha: isAvailable ? 0.15 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: isLoading
                        ? SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: accent,
                            ),
                          )
                        : Icon(icon, color: accent, size: 23),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isLoading ? 'Starting ride…' : label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isAvailable
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: accent, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
