import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/india_time.dart';
import '../../guardians/screens/guardians_screen.dart';
import '../../rides/models/favorite_guardian.dart';
import '../../rides/models/ride.dart';
import '../../rides/screens/active_ride_screen.dart';
import '../../rides/screens/ride_start_screen.dart';
import '../../rides/screens/rides_screen.dart';
import '../../rides/services/rides_api_service.dart';
import '../../rides/widgets/ride_action_button.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../notifications/services/notifications_api_service.dart';
import '../widgets/live_map_card.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.ridesApiService});

  final RidesApiService ridesApiService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _ridesInitialTab = 0;
  int _ridesNavigationRequest = 0;

  late Future<List<Ride>> _recentRidesFuture;
  late Future<List<Ride>> _recentMonitoredRidesFuture;
  late final ApiClient _notificationsApiClient = ApiClient();
  late final NotificationsApiService _notificationsApiService =
      NotificationsApiService(_notificationsApiClient);
  Timer? _notificationsRefreshTimer;
  int _unreadNotifications = 0;
  Future<List<FavoriteGuardian>>? _favoriteGuardiansFuture;

  Future<List<FavoriteGuardian>> get _favoriteGuardians =>
      _favoriteGuardiansFuture ??= _loadFavoriteGuardians();

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _firstName {
    final displayName = _currentUser?.displayName?.trim();

    if (displayName == null || displayName.isEmpty) {
      return 'there';
    }

    return displayName.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final hour = indiaStandardNow().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';

    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ridesApiService.addListener(_handleRideLifecycleChange);
    _recentRidesFuture = _loadRecentRides();
    _recentMonitoredRidesFuture = _loadRecentMonitoredRides();
    _favoriteGuardiansFuture = _loadFavoriteGuardians();
    _refreshUnreadNotifications();
    _notificationsRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refreshUnreadNotifications();
      }
    });
  }

  @override
  void dispose() {
    widget.ridesApiService.removeListener(_handleRideLifecycleChange);
    WidgetsBinding.instance.removeObserver(this);
    _notificationsRefreshTimer?.cancel();
    _notificationsApiClient.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshUnreadNotifications();
  }

  Future<void> _refreshUnreadNotifications() async {
    try {
      final count = await _notificationsApiService.getUnreadCount();
      if (mounted && count != _unreadNotifications) {
        setState(() => _unreadNotifications = count);
      }
    } catch (_) {
      // Keep the dashboard usable when the notification endpoint is offline.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          notificationsApiService: _notificationsApiService,
          onUnreadCountChanged: (count) {
            if (mounted) setState(() => _unreadNotifications = count);
          },
        ),
      ),
    );
    if (mounted) _refreshUnreadNotifications();
  }

  Future<List<Ride>> _loadRecentRides() async {
    final result = await widget.ridesApiService.getRides(page: 1, limit: 3);
    return result.rides;
  }

  Future<List<Ride>> _loadRecentMonitoredRides() async {
    final result = await widget.ridesApiService.getGuardianRideHistory(
      page: 1,
      limit: 3,
    );
    return result.rides;
  }

  Future<List<FavoriteGuardian>> _loadFavoriteGuardians() {
    return widget.ridesApiService.getFavoriteGuardians();
  }

  void _handleRideLifecycleChange() {
    if (!mounted) return;

    final change = widget.ridesApiService.lastLifecycleChange;
    final recentRides = _loadRecentRides();
    final favoriteGuardians = change == RideLifecycleChange.started
        ? _loadFavoriteGuardians()
        : null;

    setState(() {
      _recentRidesFuture = recentRides;
      if (favoriteGuardians != null) {
        _favoriteGuardiansFuture = favoriteGuardians;
      }
    });
  }

  Future<void> _refreshRecentRides() async {
    final future = _loadRecentRides();

    setState(() {
      _recentRidesFuture = future;
    });

    await future;
  }

  Future<void> _refreshDashboard() async {
    final recentRides = _loadRecentRides();
    final recentMonitoredRides = _loadRecentMonitoredRides();
    final favoriteGuardians = _loadFavoriteGuardians();

    setState(() {
      _recentRidesFuture = recentRides;
      _recentMonitoredRidesFuture = recentMonitoredRides;
      _favoriteGuardiansFuture = favoriteGuardians;
    });

    await Future.wait<void>([
      recentRides.then((_) {}).catchError((Object _) {}),
      recentMonitoredRides.then((_) {}).catchError((Object _) {}),
      favoriteGuardians.then((_) {}).catchError((Object _) {}),
    ]);
  }

  void _navigateToTab(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() => _selectedIndex = index);
  }

  void _navigateToRidesTab(int tab) {
    setState(() {
      _ridesInitialTab = tab;
      _ridesNavigationRequest++;
      _selectedIndex = 1;
    });
  }

  List<Widget> _buildPages() {
    return [
      _buildDashboard(context),
      RidesScreen(
        ridesApiService: widget.ridesApiService,
        isVisible: _selectedIndex == 1,
        initialSelectedTab: _ridesInitialTab,
        selectionRequestId: _ridesNavigationRequest,
      ),
      RideStartScreen(
        isVisible: _selectedIndex == 2,
        ridesApiService: widget.ridesApiService,
      ),
      const GuardiansScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _buildPages()),
      ),
      bottomNavigationBar: _buildFloatingBottomNavigationBar(context),
    );
  }

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  Widget _buildDashboard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),

            const SizedBox(height: 26),

            const LiveMapCard(),

            const SizedBox(height: 18),

            _buildStartRideButton(),

            const SizedBox(height: 22),

            _buildFavoriteGuardiansSection(context),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Rides',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToRidesTab(0),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            _buildRecentRidesSection(context),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Monitored Rides',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToRidesTab(1),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            _buildRecentMonitoredRidesSection(context),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dashboard header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$_firstName!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Badge(
          offset: const Offset(-4, 4),
          isLabelVisible: _unreadNotifications > 0,
          label: Text(
            _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
          ),
          child: IconButton(
            onPressed: _openNotifications,
            tooltip: 'Notifications',
            icon: Icon(
              Icons.notifications_none_rounded,
              size: 28,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildProfileAvatar(colorScheme),
      ],
    );
  }

  Widget _buildProfileAvatar(ColorScheme colorScheme) {
    final photoUrl = _currentUser?.photoURL;

    return GestureDetector(
      onTap: () => _navigateToTab(4),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
            ? NetworkImage(photoUrl)
            : null,
        child: photoUrl == null || photoUrl.isEmpty
            ? Icon(Icons.person_rounded, color: colorScheme.onSurfaceVariant)
            : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Start ride button
  // ---------------------------------------------------------------------------

  Widget _buildStartRideButton() {
    return FutureBuilder<List<Ride>>(
      future: _recentRidesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const RideActionButton(
            onPressed: null,
            label: 'Checking ride status…',
            icon: Icons.sync_rounded,
            isEnabled: false,
          );
        }

        final activeRides = (snapshot.data ?? const <Ride>[]).where(
          (ride) => ride.isActive,
        );
        final activeRide = activeRides.isEmpty ? null : activeRides.first;

        if (activeRide != null) {
          return RideActionButton(
            onPressed: () => _openActiveRide(activeRide),
            label: 'Continue Active Ride',
            icon: Icons.play_arrow_rounded,
          );
        }

        return RideActionButton(
          onPressed: () => _navigateToTab(2),
          label: 'Start Ride',
          icon: Icons.navigation_rounded,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Favorite guardians
  // ---------------------------------------------------------------------------

  Widget _buildFavoriteGuardiansSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return FutureBuilder<List<FavoriteGuardian>>(
      future: _favoriteGuardians,
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Favorite Guardians',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'The people you choose most often to watch over your rides.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              _buildFavoriteGuardiansLoading(colorScheme)
            else if (snapshot.hasError)
              _buildFavoriteGuardiansMessage(
                context,
                icon: Icons.cloud_off_outlined,
                title: 'Favorites are unavailable',
                description: 'Pull to refresh and try again.',
                onTap: _refreshDashboard,
              )
            else if ((snapshot.data ?? []).isEmpty)
              _buildFavoriteGuardiansMessage(
                context,
                icon: Icons.people_outline_rounded,
                title: 'Your go-to guardians will appear here',
                description: 'Choose guardians when you start a ride to build your favorites.',
                onTap: () => _navigateToTab(2),
              )
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry
                        in (snapshot.data ?? []).take(2).indexed) ...[
                      if (entry.$1 > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _buildFavoriteGuardianCard(
                          entry.$2,
                          rank: entry.$1 + 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFavoriteGuardiansLoading(ColorScheme colorScheme) {
    return Container(
      height: 128,
      decoration: _cardDecoration(colorScheme),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildFavoriteGuardiansMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(colors),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 25),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteGuardianCard(
    FavoriteGuardian guardian, {
    required int rank,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final photoUrl = guardian.profileImageUrl;
    final avatarRingColor = guardian.doNotDisturb
        ? const Color(0xFF8B5CF6)
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: avatarRingColor.withValues(alpha: 0.82),
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.trim().isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _guardianAvatarFallback(guardian.name),
                        )
                      : _guardianAvatarFallback(guardian.name),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            guardian.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _guardianAvatarFallback(String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      color: AppColors.primary.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 23,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recent rides
  // ---------------------------------------------------------------------------

  Widget _buildRecentRidesSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<Ride>>(
      future: _recentRidesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: _cardDecoration(colorScheme),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildRecentRidesError(context);
        }

        final rides = snapshot.data ?? [];

        if (rides.isEmpty) {
          return _buildEmptyRidesCard(context);
        }

        final recentRides = rides.take(3).toList();

        return Column(
          children: [
            ...recentRides.map(
              (ride) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildRecentRideCard(context, ride),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentMonitoredRidesSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return FutureBuilder<List<Ride>>(
      future: _recentMonitoredRidesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: _cardDecoration(colors),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(colors),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined, color: colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not load monitored rides.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _recentMonitoredRidesFuture =
                        _loadRecentMonitoredRides(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final rides = snapshot.data ?? const <Ride>[];
        if (rides.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: _cardDecoration(colors),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rides shared with you will appear here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: rides
              .take(3)
              .map(
                (ride) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildRecentRideCard(context, ride, monitored: true),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildRecentRideCard(
    BuildContext context,
    Ride ride, {
    bool monitored = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isActive = ride.isActive;

    final statusColor = isActive
        ? Colors.green
        : ride.status.toUpperCase() == 'COMPLETED'
        ? Colors.blue
        : colorScheme.onSurfaceVariant;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isActive
            ? () => monitored ? _openMonitoredRide(ride) : _openActiveRide(ride)
            : () => _navigateToRidesTab(monitored ? 1 : 0),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  monitored ? Icons.shield_outlined : Icons.route_rounded,
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
                      monitored && ride.riderName != null
                          ? ride.riderName!
                          : ride.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (monitored) ...[
                      Text(
                        ride.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      _formatRideDate(context, ride.startedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatStatus(ride.status),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRidesCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: _cardDecoration(colorScheme),
      child: Column(
        children: [
          Icon(
            Icons.route_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'No rides yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Your active and completed rides will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => _navigateToTab(2),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Start your first ride'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRidesError(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(colorScheme),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 36,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'Unable to load rides',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _refreshRecentRides,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active ride navigation
  // ---------------------------------------------------------------------------

  Future<void> _openActiveRide(Ride ride) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveRideScreen(
          ride: ride,
          ridesApiService: widget.ridesApiService,
        ),
      ),
    );
  }

  Future<void> _openMonitoredRide(Ride ride) async {
    if (!ride.isActive) {
      _navigateToRidesTab(1);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveRideScreen(
          ride: ride,
          ridesApiService: widget.ridesApiService,
          isGuardian: true,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _formatRideDate(BuildContext context, DateTime dateTime) {
    final indiaDateTime = toIndiaStandardTime(dateTime);
    final localizations = MaterialLocalizations.of(context);

    final date = localizations.formatMediumDate(indiaDateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(indiaDateTime),
    );

    return '$date • $time IST';
  }

  String _formatStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return 'Active';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  BoxDecoration _cardDecoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: colorScheme.outlineVariant),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating bottom navigation
  // ---------------------------------------------------------------------------

  Widget _buildFloatingBottomNavigationBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: colorScheme.brightness == Brightness.dark ? 0.22 : 0.08,
              ),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildFloatingNavItem(
              context: context,
              index: 0,
              icon: Icons.home_rounded,
              label: 'Home',
            ),
            _buildFloatingNavItem(
              context: context,
              index: 1,
              icon: Icons.route_outlined,
              label: 'Rides',
            ),

            Expanded(
              child: Center(
                child: Tooltip(
                  message: 'Start Ride',
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _navigateToTab(2),
                      child: const SizedBox(
                        width: 54,
                        height: 54,
                        child: Icon(
                          Icons.add_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            _buildFloatingNavItem(
              context: context,
              index: 3,
              icon: Icons.people_alt_outlined,
              label: 'Guardians',
            ),
            _buildFloatingNavItem(
              context: context,
              index: 4,
              icon: Icons.person_outline_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => _navigateToTab(index),
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    icon,
                    size: 23,
                    color: isSelected
                        ? AppColors.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
