import 'package:flutter/material.dart';

import 'ride_action_button.dart';

class StartRideButton extends StatelessWidget {
  const StartRideButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.isEnabled,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return RideActionButton(
      onPressed: onPressed,
      label: 'Start Ride',
      icon: Icons.navigation_rounded,
      isLoading: isLoading,
      isEnabled: isEnabled,
    );
  }
}
