import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GuardiansSummaryCard extends StatelessWidget {
  final int myGuardiansCount;
  final int peopleIMonitorCount;
  final int pendingRequestsCount;

  const GuardiansSummaryCard({
    super.key,
    required this.myGuardiansCount,
    required this.peopleIMonitorCount,
    required this.pendingRequestsCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.045,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.diversity_3_rounded,
                  color: AppColors.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your trusted circle',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'People connected to your ride safety',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingRequestsCount > 0) ...[
                const SizedBox(width: 8),
                _CountBadge(count: pendingRequestsCount),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  value: myGuardiansCount,
                  label: 'My guardians',
                  icon: Icons.shield_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SummaryMetric(
                  value: peopleIMonitorCount,
                  label: 'I monitor',
                  icon: Icons.remove_red_eye_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SummaryMetric(
                  value: pendingRequestsCount,
                  label: 'Requests',
                  icon: Icons.inbox_outlined,
                  emphasize: pendingRequestsCount > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final bool emphasize;

  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.icon,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = emphasize ? AppColors.primary : colors.onSurfaceVariant;

    return Container(
      constraints: const BoxConstraints(minHeight: 91),
      padding: const EdgeInsets.fromLTRB(11, 12, 8, 10),
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.primary.withValues(alpha: 0.09)
            : colors.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasize
              ? AppColors.primary.withValues(alpha: 0.22)
              : colors.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                '$value',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: emphasize ? AppColors.primary : colors.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            '$count new',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
