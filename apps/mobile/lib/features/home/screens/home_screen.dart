import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../guardians/screens/guardians_screen.dart';
import '../../rides/models/ride.dart';
import '../../rides/screens/active_ride_screen.dart';
import '../../rides/screens/ride_start_screen.dart';
import '../../rides/screens/rides_screen.dart';
import '../../rides/services/rides_api_service.dart';
import '../widgets/live_map_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.ridesApiService,
  });

  final RidesApiService ridesApiService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late Future<List<Ride>> _recentRidesFuture;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _firstName {
    final displayName = _currentUser?.displayName?.trim();

    if (displayName == null || displayName.isEmpty) {
      return 'there';
    }

    return displayName.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';

    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    _recentRidesFuture = _loadRecentRides();
  }

  Future<List<Ride>> _loadRecentRides() async {
    final rides = await widget.ridesApiService.getRides();

    rides.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return rides;
  }

  Future<void> _refreshRecentRides() async {
    final future = _loadRecentRides();

    setState(() {
      _recentRidesFuture = future;
    });

    await future;
  }

  void _navigateToTab(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _buildPages() {
    return [
      _buildDashboard(context),
      RidesScreen(
        ridesApiService: widget.ridesApiService,
      ),
      const RideStartScreen(),
      const GuardiansScreen(),
      const _PlaceholderPage(
        icon: Icons.person_outline_rounded,
        title: 'Your Profile',
        description: 'Manage your account and app preferences here.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _buildPages(),
        ),
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
      onRefresh: _refreshRecentRides,
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

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context: context,
                    title: 'My Guardians',
                    value: '0',
                    icon: Icons.people_alt_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildStatCard(
                    context: context,
                    title: 'Rides I Covered',
                    value: '0',
                    icon: Icons.route_outlined,
                  ),
                ),
              ],
            ),

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
                  onPressed: () => _navigateToTab(1),
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
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications will be available here.'),
              ),
            );
          },
          tooltip: 'Notifications',
          icon: Icon(
            Icons.notifications_none_rounded,
            size: 28,
            color: colorScheme.onSurface,
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
            ? Icon(
                Icons.person_rounded,
                color: colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Start ride button
  // ---------------------------------------------------------------------------

  Widget _buildStartRideButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: () => _navigateToTab(2),
        icon: const Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: 23,
        ),
        label: const Text(
          'Start Ride',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------------

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 27,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
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

  Widget _buildRecentRideCard(BuildContext context, Ride ride) {
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
            ? () => _openActiveRide(ride)
            : () => _navigateToTab(1),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
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
                child: const Icon(
                  Icons.route_rounded,
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
                      ride.rideCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 26,
      ),
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

    if (!mounted) return;

    await _refreshRecentRides();
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _formatRideDate(BuildContext context, DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    final localizations = MaterialLocalizations.of(context);

    final date = localizations.formatMediumDate(localDateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localDateTime),
    );

    return '$date • $time';
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
      border: Border.all(
        color: colorScheme.outlineVariant,
      ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 7,
        ),
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
                alpha: colorScheme.brightness == Brightness.dark
                    ? 0.22
                    : 0.08,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 5,
              ),
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

// -----------------------------------------------------------------------------
// Temporary Profile placeholder
// -----------------------------------------------------------------------------

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
