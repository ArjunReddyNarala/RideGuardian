import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../guardians/models/guardian_relationship.dart';

class GuardianSelectionCard extends StatelessWidget {
  const GuardianSelectionCard({
    super.key,
    required this.relationship,
    required this.isSelected,
    required this.onTap,
    this.isUnavailable = false,
  });

  final GuardianRelationship relationship;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isUnavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final guardian = relationship.guardian;

    final guardianName = guardian?.name ?? 'Guardian';
    final contact = guardian?.contact ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.07)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: guardian?.profileImageUrl != null
                    ? NetworkImage(guardian!.profileImageUrl!)
                    : null,
                child: guardian?.profileImageUrl == null
                    ? Text(
                        guardianName.isNotEmpty
                            ? guardianName[0].toUpperCase()
                            : 'G',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guardianName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (contact.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        contact,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    if (isUnavailable) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Do Not Disturb is on',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (!isUnavailable)
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Connected guardian',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : colorScheme.outline,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
