import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

import '../models/ride.dart';
import '../services/rides_api_service.dart';

import 'active_ride_screen.dart';
import 'ride_start_screen.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({
    super.key,
    required this.ridesApiService,
  });

  final RidesApiService ridesApiService;

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Ride> _rides = [];

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _loadRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final rides = await widget.ridesApiService.getRides();

      if (!mounted) return;

      rides.sort(
        (a, b) => b.startedAt.compareTo(a.startedAt),
      );

      setState(() {
        _rides = rides;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  List<Ride> get _activeRides {
    return _rides.where((ride) => ride.isActive).toList();
  }

  List<Ride> get _completedRides {
    return _rides.where((ride) => ride.isCompleted).toList();
  }

  Future<void> _openRide(Ride ride) async {
    if (ride.isActive) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveRideScreen(
            ride: ride,
            ridesApiService: widget.ridesApiService,
          ),
        ),
      );

      if (mounted) {
        _loadRides();
      }
    }
  }

  void _startNewRide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RideStartScreen(),
      ),
    ).then((_) {
      if (mounted) {
        _loadRides();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'My Rides',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadRides,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh rides',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Active'),
                  const SizedBox(width: 8),
                  _countBadge(_activeRides.length),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('History'),
                  const SizedBox(width: 8),
                  _countBadge(_completedRides.length),
                ],
              ),
            ),
          ],
        ),
      ),

      body: _buildBody(),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewRide,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_road_rounded),
        label: const Text(
          'Start Ride',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadRides,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveRides(),
          _buildRideHistory(),
        ],
      ),
    );
  }

  Widget _buildActiveRides() {
    final rides = _activeRides;

    if (rides.isEmpty) {
      return _buildEmptyState(
        icon: Icons.motorcycle_outlined,
        title: 'No active rides',
        description:
            'Your currently running rides will appear here.',
        showStartButton: true,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        Text(
          'Currently running',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),

        const SizedBox(height: 6),

        Text(
          'Tap a ride to continue tracking it.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
        ),

        const SizedBox(height: 18),

        ...rides.map(
          (ride) => _buildActiveRideCard(ride),
        ),
      ],
    );
  }

  Widget _buildRideHistory() {
    final rides = _completedRides;

    if (rides.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'No ride history',
        description:
            'Your completed rides will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: rides.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildHistoryRideCard(rides[index]);
      },
    );
  }

  Widget _buildActiveRideCard(Ride ride) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.green.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openRide(ride),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statusBadge(
                    'ACTIVE',
                    Colors.green,
                  ),

                  const Spacer(),

                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                ride.rideCode,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),

              const SizedBox(height: 8),

              _detailItem(
                Icons.calendar_today_outlined,
                _formatDate(ride.startedAt),
              ),

              const SizedBox(height: 8),

              _detailItem(
                Icons.access_time_rounded,
                'Started ${_formatTime(ride.startedAt)}',
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.green,
                      size: 19,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Continue tracking your ride',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryRideCard(Ride ride) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusBadge(
                  'COMPLETED',
                  Colors.blue,
                ),

                const Spacer(),

                Text(
                  _formatDate(ride.startedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              ride.rideCode,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),

            const SizedBox(height: 12),

            _detailItem(
              Icons.play_circle_outline_rounded,
              'Started: ${_formatTime(ride.startedAt)}',
            ),

            const SizedBox(height: 8),

            if (ride.endedAt != null)
              _detailItem(
                Icons.stop_circle_outlined,
                'Ended: ${_formatTime(ride.endedAt!)}',
              ),

            if (ride.endedAt != null) ...[
              const SizedBox(height: 8),
              _detailItem(
                Icons.timer_outlined,
                'Duration: ${_formatDuration(ride.startedAt, ride.endedAt!)}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    bool showStartButton = false,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 75),

        Icon(
          icon,
          size: 75,
          color: Theme.of(context).colorScheme.onSurfaceVariant
              .withValues(alpha: 0.5),
        ),

        const SizedBox(height: 22),

        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),

        const SizedBox(height: 10),

        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),

        if (showStartButton) ...[
          const SizedBox(height: 24),

          Center(
            child: ElevatedButton.icon(
              onPressed: _startNewRide,
              icon: const Icon(Icons.add_road_rounded),
              label: const Text('Start a ride'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 55,
            ),

            const SizedBox(height: 16),

            const Text(
              'Unable to load rides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _loadRides,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();

    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }
}
