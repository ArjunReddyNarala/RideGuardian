import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GuardiansSectionSelector extends StatelessWidget {
  final int selectedIndex;
  final int pendingRequestsCount;
  final ValueChanged<int> onChanged;

  const GuardiansSectionSelector({
    super.key,
    required this.selectedIndex,
    required this.pendingRequestsCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _SectionButton(
            label: 'My Guardians',
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          _SectionButton(
            label: 'Monitoring',
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
          _SectionButton(
            label: 'Requests',
            selected: selectedIndex == 2,
            badge: pendingRequestsCount,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _SectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (badge > 0 && label == 'Requests') ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
