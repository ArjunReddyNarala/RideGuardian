import 'package:flutter/material.dart';

import '../../guardians/models/guardian_relationship.dart';

class SelectedGuardiansSection extends StatelessWidget {
  const SelectedGuardiansSection({
    super.key,
    required this.guardians,
    required this.onRemove,
  });

  final List<GuardianRelationship> guardians;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Selected guardians',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${guardians.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (guardians.isEmpty)
          Text(
            'Select at least one guardian to share your ride.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: guardians.map((relationship) {
              final guardian = relationship.guardian;
              final guardianName = guardian?.name ?? 'Guardian';

              return InputChip(
                avatar: CircleAvatar(
                  backgroundColor:
                      colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    guardianName.isNotEmpty
                        ? guardianName[0].toUpperCase()
                        : 'G',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                label: Text(guardianName),
                onDeleted: () => onRemove(relationship.guardianId),
                deleteIconColor: colorScheme.onSurfaceVariant,
                backgroundColor: colorScheme.surfaceContainerHighest,
                side: BorderSide.none,
              );
            }).toList(),
          ),
      ],
    );
  }
}