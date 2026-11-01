import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../guardians/models/guardian_relationship.dart';
import '../../guardians/services/guardians_api_service.dart';
import '../models/start_ride_request.dart';
import '../services/rides_api_service.dart';
import '../widgets/guardian_selection_card.dart';
import '../widgets/start_ride_button.dart';
import 'active_ride_screen.dart';

class RideStartScreen extends StatefulWidget {
  const RideStartScreen({super.key});

  @override
  State<RideStartScreen> createState() => _RideStartScreenState();
}

class _RideStartScreenState extends State<RideStartScreen>
    with WidgetsBindingObserver {
  late final ApiClient _apiClient;
  late final GuardiansApiService _guardiansApiService;
  late final RidesApiService _ridesApiService;

  Timer? _guardianRefreshTimer;

  List<GuardianRelationship> _guardians = [];
  final Set<String> _selectedGuardianIds = {};

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isStartingRide = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _apiClient = ApiClient();
    _guardiansApiService = GuardiansApiService(_apiClient);
    _ridesApiService = RidesApiService(_apiClient);

    _loadGuardians();

    // Refresh guardian relationships periodically.
    // This is useful because IndexedStack keeps this screen mounted
    // when the user switches between bottom navigation tabs.
    _guardianRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted && !_isStartingRide) {
          _loadGuardians(showLoader: false);
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadGuardians(showLoader: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _guardianRefreshTimer?.cancel();

    _apiClient.close();

    super.dispose();
  }

  String get _currentEmail {
    return FirebaseAuth.instance.currentUser?.email
            ?.trim()
            .toLowerCase() ??
        '';
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

  Future<void> _loadGuardians({
    bool showLoader = true,
  }) async {
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
      final relationships =
          await _guardiansApiService.getRelationships();

      final acceptedGuardians = relationships.where((relationship) {
        return relationship.isAccepted &&
            !relationship.isRevoked &&
            _isCurrentRider(relationship) &&
            relationship.guardian != null;
      }).toList();

      if (!mounted) return;

      setState(() {
        _guardians = acceptedGuardians;

        // Keep only selections that still have an accepted relationship.
        final availableIds =
            acceptedGuardians.map((item) => item.guardianId).toSet();

        _selectedGuardianIds.removeWhere(
          (id) => !availableIds.contains(id),
        );

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
      final request = StartRideRequest(
        guardianIds: _selectedGuardianIds.toList(),
      );

      final ride = await _ridesApiService.createRide(request);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActiveRideScreen(
            ride: ride,
            ridesApiService: _ridesApiService,
          ),
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
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
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
                      final isSelected = _selectedGuardianIds
                          .contains(relationship.guardianId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GuardianSelectionCard(
                          relationship: relationship,
                          isSelected: isSelected,
                          onTap: () => _toggleGuardian(
                            relationship.guardianId,
                          ),
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
              ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ride with confidence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Keep your trusted people informed '
                  'while you are on the road.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 48,
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
            'Unable to load guardians',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
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