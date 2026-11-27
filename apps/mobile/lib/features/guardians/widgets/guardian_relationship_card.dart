import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/guardian_relationship.dart';
import '../models/rider_safety_settings.dart';

class GuardianRelationshipCard extends StatelessWidget {
  final GuardianRelationship relationship;
  final RiderSafetySettings? setting;
  final bool currentUserIsGuardian;
  final VoidCallback onConfigure;
  final VoidCallback onRemove;
  final Widget? monitoringStatus;

  const GuardianRelationshipCard({
    super.key,
    required this.relationship,
    required this.setting,
    required this.currentUserIsGuardian,
    required this.onConfigure,
    required this.onRemove,
    this.monitoringStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final person = currentUserIsGuardian
        ? relationship.rider
        : relationship.guardian;

    final photoUrl = person?.profileImageUrl;

    final maxSpeed = setting?.maxSpeedKmh;
    final speedSettingsAction = maxSpeed == null ? 'Configure' : 'Edit';
    final removeAction = currentUserIsGuardian
        ? 'Stop monitoring'
        : 'Remove guardian';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primary.withValues(alpha: 0.13),
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 27,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person?.name ?? 'RideGuardian user',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      person?.email ??
                          person?.phone ??
                          'Contact details unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const _StatusLabel(status: 'Connected'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.speed_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    maxSpeed == null
                        ? 'Speed limit not configured'
                        : 'Speed limit: ${maxSpeed.toStringAsFixed(0)} km/h',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (currentUserIsGuardian)
                  TextButton(
                    onPressed: onConfigure,
                    child: Text(
                      speedSettingsAction,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (monitoringStatus != null) ...[
            const SizedBox(height: 12),
            monitoringStatus!,
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: Text(removeAction),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                backgroundColor: AppColors.danger.withValues(alpha: 0.07),
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.28),
                ),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final String status;

  const _StatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
