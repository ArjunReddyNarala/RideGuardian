import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shared outlined action style for authentication and verification flows.
class AuthActionButton extends StatelessWidget {
  const AuthActionButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
    this.trailingIcon = Icons.arrow_forward_rounded,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingLabel;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEnabled = onPressed != null && !isLoading;
    final accent = isEnabled ? AppColors.primary : colors.onSurfaceVariant;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: AppColors.primary.withValues(alpha: isEnabled ? 0.34 : 0.16),
      ),
    );

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: isLoading ? (loadingLabel ?? label) : label,
      child: SizedBox(
        width: double.infinity,
        height: 62,
        child: Material(
          color: colors.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.58 : 0.78,
          ),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isEnabled ? 0.13 : 0.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: isLoading
                        ? SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          )
                        : leading,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      isLoading ? (loadingLabel ?? label) : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isEnabled
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(trailingIcon, color: accent, size: 21),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
