import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/india_time.dart';
import '../../guardians/models/guardian_relationship.dart';
import '../../guardians/services/guardians_api_service.dart';
import '../models/ride.dart';
import '../models/start_ride_request.dart';
import '../services/rides_api_service.dart';
import '../widgets/guardian_selection_card.dart';
import '../widgets/ride_action_button.dart';
import '../widgets/start_ride_button.dart';
import 'active_ride_screen.dart';

class RideStartScreen extends StatefulWidget {
  const RideStartScreen({
    super.key,
    this.isVisible = true,
    this.ridesApiService,
  });

  /// Whether this screen is currently selected in the home tab stack.
  /// Standalone routes default to visible.
  final bool isVisible;
  final RidesApiService? ridesApiService;

  @override
  State<RideStartScreen> createState() => _RideStartScreenState();
}

class _RideStartScreenState extends State<RideStartScreen>
    with WidgetsBindingObserver {
  late final ApiClient _apiClient;
  late final GuardiansApiService _guardiansApiService;
  late final RidesApiService _ridesApiService;

  List<GuardianRelationship> _guardians = [];
  Ride? _activeRide;
  final Set<String> _selectedGuardianIds = {};

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isStartingRide = false;
  bool _activeRideCheckFailed = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _apiClient = ApiClient();
    _guardiansApiService = GuardiansApiService(_apiClient);
    _ridesApiService = widget.ridesApiService ?? RidesApiService(_apiClient);

    if (widget.isVisible) {
      _loadGuardians();
    }
  }

  @override
  void didUpdateWidget(covariant RideStartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isVisible && widget.isVisible) {
      // Refresh when the rider opens this tab so newly accepted guardians
      // are available without polling in the background.
      _loadGuardians(showLoader: _guardians.isEmpty);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && widget.isVisible) {
      _loadGuardians(showLoader: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _apiClient.close();

    super.dispose();
  }

  String get _currentEmail {
    return FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
  }

  String get _currentPhone {
    return FirebaseAuth.instance.currentUser?.phoneNumber?.trim() ?? '';
  }

  bool _isCurrentRider(GuardianRelationship relationship) {
    final rider = relationship.rider;

    if (rider == null) return false;

    final riderEmail = rider.email?.trim().toLowerCase() ?? '';
    final riderPhone = rider.phone?.trim() ?? '';

    final emailMatches =
        _currentEmail.isNotEmpty && riderEmail == _currentEmail;

    final phoneMatches =
        _currentPhone.isNotEmpty && riderPhone == _currentPhone;

    return emailMatches || phoneMatches;
  }

  Future<void> _loadGuardians({bool showLoader = true}) async {
    // Avoid simultaneous requests.
    if (_isRefreshing || !mounted) return;

    _isRefreshing = true;

    if (showLoader && _guardians.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final activeRide = await _ridesApiService.getActiveRide();
      final relationships = await _guardiansApiService.getRelationships();

      final acceptedGuardians = relationships.where((relationship) {
        return relationship.isAccepted &&
            !relationship.isRevoked &&
            _isCurrentRider(relationship) &&
            relationship.guardian != null;
      }).toList();

      if (!mounted) return;

      setState(() {
        _activeRide = activeRide?.isActive == true ? activeRide : null;
        _activeRideCheckFailed = false;
        _guardians = acceptedGuardians;

        // Keep only selections that still have an accepted relationship.
        final availableIds = acceptedGuardians
            .map((item) => item.guardianId)
            .toSet();

        _selectedGuardianIds.removeWhere((id) => !availableIds.contains(id));

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      // Do not replace the existing guardian list with an error state
      // during a silent background refresh.
      if (showLoader || _guardians.isEmpty) {
        setState(() {
          _isLoading = false;
          _activeRideCheckFailed = true;
          _errorMessage = error.toString();
        });
      } else {
        setState(() {
          _activeRideCheckFailed = true;
          _errorMessage = error.toString();
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _toggleGuardian(String guardianId) {
    setState(() {
      if (_selectedGuardianIds.contains(guardianId)) {
        _selectedGuardianIds.remove(guardianId);
      } else {
        _selectedGuardianIds.add(guardianId);
      }
    });
  }

  Future<void> _startRide() async {
    if (_selectedGuardianIds.isEmpty || _isStartingRide) return;

    setState(() {
      _isStartingRide = true;
    });

    try {
      // Recheck on submission in case another screen started a ride after
      // this screen was opened.
      final existingRide = await _ridesApiService.getActiveRide();
      if (existingRide?.isActive == true) {
        if (mounted) {
          setState(() {
            _activeRide = existingRide;
            _activeRideCheckFailed = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final request = StartRideRequest(
        guardianIds: _selectedGuardianIds.toList(),
      );

      final ride = await _ridesApiService.createRide(request);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ActiveRideScreen(ride: ride, ridesApiService: _ridesApiService),
        ),
      );

      // Refresh guardian relationships when returning to this screen.
      if (mounted) {
        await _loadGuardians(showLoader: false);
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start ride: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingRide = false;
        });
      }
    }
  }

  Future<void> _openActiveRide(Ride ride) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ActiveRideScreen(ride: ride, ridesApiService: _ridesApiService),
      ),
    );

    if (mounted) {
      await _loadGuardians(showLoader: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Start a Ride',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadGuardians(),
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 350,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  if (_activeRideCheckFailed)
                    _buildErrorState(context)
                  else if (_activeRide case final ride?)
                    _buildActiveRideContent(context, ride)
                  else ...[
                    _buildIntroCard(context),

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choose your guardians',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_guardians.isNotEmpty)
                          Text(
                            '${_selectedGuardianIds.length} selected',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Select who can monitor your ride and receive '
                      'safety alerts. Tap again to deselect.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (_errorMessage != null)
                      _buildErrorState(context)
                    else if (_guardians.isEmpty)
                      _buildEmptyState(context)
                    else
                      ..._guardians.map((relationship) {
                        final isSelected = _selectedGuardianIds.contains(
                          relationship.guardianId,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GuardianSelectionCard(
                            relationship: relationship,
                            isSelected: isSelected,
                            onTap: () =>
                                _toggleGuardian(relationship.guardianId),
                          ),
                        );
                      }),

                    const SizedBox(height: 28),

                    StartRideButton(
                      isLoading: _isStartingRide,
                      isEnabled: _selectedGuardianIds.isNotEmpty,
                      onPressed: _startRide,
                    ),

                    const SizedBox(height: 12),

                    Center(
                      child: Text(
                        'Your ride will be shared with the selected guardians.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildActiveRideContent(BuildContext context, Ride ride) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final startedAtIst = toIndiaStandardTime(ride.startedAt);
    final date =
        '${startedAtIst.day.toString().padLeft(2, '0')}/'
        '${startedAtIst.month.toString().padLeft(2, '0')}/'
        '${startedAtIst.year}';
    final time =
        '${startedAtIst.hour.toString().padLeft(2, '0')}:'
        '${startedAtIst.minute.toString().padLeft(2, '0')} IST';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.radio_button_checked_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Ride in progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'You already have an active ride. Continue to its live safety dashboard.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _openActiveRide(ride),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ride.rideCode,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 9),
                      Text(date, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 9),
                      Text('Started $time', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RideActionButton(
                    onPressed: () => _openActiveRide(ride),
                    label: 'Continue active ride',
                    icon: Icons.radar_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ride with Confidence',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selected guardians can monitor your live location and speed, '
                  'and receive an alert if you exceed your speed limit.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 42,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No connected guardians',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You need at least one accepted guardian '
            'relationship before starting a ride.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 10),
          Text(
            'Unable to check ride status',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _loadGuardians(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
