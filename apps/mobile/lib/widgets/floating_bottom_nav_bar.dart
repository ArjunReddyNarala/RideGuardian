import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class FloatingBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const FloatingBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const double _barHeight = 76;
  static const double _startRideButtonSize = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final barBackground = isDarkMode
        ? const Color(0xFF192421)
        : Colors.white;

    final borderColor = isDarkMode
        ? const Color(0xFF34433E)
        : const Color(0xFFE4E7EC);

    final inactiveColor = colorScheme.onSurfaceVariant;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          height: _barHeight,
          decoration: BoxDecoration(
            color: barBackground,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.85),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDarkMode ? 0.12 : 0.06,
                ),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Home
              _buildDestination(
                context: context,
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
                activeColor: AppColors.primary,
                inactiveColor: inactiveColor,
              ),

              // Rides
              _buildDestination(
                context: context,
                index: 1,
                icon: Icons.route_rounded,
                label: 'Rides',
                activeColor: AppColors.primary,
                inactiveColor: inactiveColor,
              ),

              // Central Start Ride action
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Start Ride',
                  child: InkWell(
                    onTap: () => onDestinationSelected(2),
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: _barHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: _startRideButtonSize,
                            height: _startRideButtonSize,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Start Ride',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Guardians
              _buildDestination(
                context: context,
                index: 3,
                icon: Icons.people_alt_rounded,
                label: 'Guardians',
                activeColor: AppColors.primary,
                inactiveColor: inactiveColor,
              ),

              // Profile
              _buildDestination(
                context: context,
                index: 4,
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                activeColor: AppColors.primary,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestination({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final theme = Theme.of(context);
    final isSelected = selectedIndex == index;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 5,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onDestinationSelected(index),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        icon,
                        key: ValueKey('$index-$isSelected'),
                        size: 23,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: theme.textTheme.labelSmall!.copyWith(
                        fontSize: 10,
                        height: 1.1,
                        letterSpacing: 0.1,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}