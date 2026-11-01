import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/india_time.dart';
import '../models/paginated_rides.dart';
import '../models/ride.dart';
import '../services/rides_api_service.dart';
import '../widgets/ride_action_button.dart';
import 'active_ride_screen.dart';
import 'ride_start_screen.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({
    super.key,
    required this.ridesApiService,
    this.isVisible = true,
  });

  final RidesApiService ridesApiService;
  final bool isVisible;

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  static const _pageSize = 20;

  int _selectedTab = 0;
  final List<Ride> _myRides = [];
  final List<Ride> _monitoredRides = [];
  int _myPage = 0;
  int _monitoredPage = 0;
  int _myTotal = 0;
  int _monitoredTotal = 0;
  bool _myLoading = true;
  bool _monitoredLoading = false;
  bool _myLoadingMore = false;
  bool _monitoredLoadingMore = false;
  bool _monitoredLoaded = false;
  bool _hasLoadedMyRides = false;
  bool _myRidesStale = false;
  bool _monitoredRidesStale = false;
  String? _myError;
  String? _monitoredError;
  int _myRequestId = 0;
  int _monitoredRequestId = 0;

  bool get _isLoading => _selectedTab == 0 ? _myLoading : _monitoredLoading;
  bool get _isLoadingMore =>
      _selectedTab == 0 ? _myLoadingMore : _monitoredLoadingMore;
  String? get _error => _selectedTab == 0 ? _myError : _monitoredError;
  List<Ride> get _rides => _selectedTab == 0 ? _myRides : _monitoredRides;
  int get _page => _selectedTab == 0 ? _myPage : _monitoredPage;
  int get _total => _selectedTab == 0 ? _myTotal : _monitoredTotal;
  bool get _hasMore => _page * _pageSize < _total;

  @override
  void initState() {
    super.initState();
    widget.ridesApiService.addListener(_handleRideLifecycleChange);
    if (widget.isVisible) _loadPage(reset: true, tab: 0);
  }

  @override
  void didUpdateWidget(covariant RidesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isVisible && widget.isVisible) {
      if (_needsRefresh(_selectedTab)) {
        _loadPage(reset: true, tab: _selectedTab);
      }
    }
  }

  @override
  void dispose() {
    widget.ridesApiService.removeListener(_handleRideLifecycleChange);
    super.dispose();
  }

  void _handleRideLifecycleChange() {
    if (!mounted) return;

    _myRidesStale = true;
    if (widget.isVisible) {
      _loadPage(reset: true, tab: 0);
    }
  }

  bool _needsRefresh(int tab) {
    return tab == 0
        ? !_hasLoadedMyRides || _myRidesStale
        : !_monitoredLoaded || _monitoredRidesStale;
  }

  Future<void> _loadPage({required bool reset, int? tab}) async {
    final targetTab = tab ?? _selectedTab;
    final requestId = targetTab == 0 ? ++_myRequestId : ++_monitoredRequestId;
    final currentPage = targetTab == 0 ? _myPage : _monitoredPage;
    final page = reset ? 1 : currentPage + 1;

    setState(() {
      if (targetTab == 0) {
        if (reset) _myLoading = _myRides.isEmpty;
        _myLoadingMore = !reset;
        _myError = null;
      } else {
        if (reset) _monitoredLoading = _monitoredRides.isEmpty;
        _monitoredLoadingMore = !reset;
        _monitoredError = null;
      }
    });

    try {
      final PaginatedRides result = targetTab == 0
          ? await widget.ridesApiService.getRides(page: page, limit: _pageSize)
          : await widget.ridesApiService.getGuardianRideHistory(
              page: page,
              limit: _pageSize,
            );
      if (!mounted) return;
      final latestRequestId = targetTab == 0
          ? _myRequestId
          : _monitoredRequestId;
      if (requestId != latestRequestId) return;

      setState(() {
        final list = targetTab == 0 ? _myRides : _monitoredRides;
        if (reset) {
          list
            ..clear()
            ..addAll(result.rides);
        } else {
          list.addAll(result.rides);
        }
        if (targetTab == 0) {
          _myPage = result.page;
          _myTotal = result.total;
          _myLoading = false;
          _myLoadingMore = false;
          _hasLoadedMyRides = true;
          _myRidesStale = false;
        } else {
          _monitoredPage = result.page;
          _monitoredTotal = result.total;
          _monitoredLoaded = true;
          _monitoredLoading = false;
          _monitoredLoadingMore = false;
          _monitoredRidesStale = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      final latestRequestId = targetTab == 0
          ? _myRequestId
          : _monitoredRequestId;
      if (requestId != latestRequestId) return;
      setState(() {
        if (targetTab == 0) {
          _myError = error.toString();
          _myLoading = false;
          _myLoadingMore = false;
          _myRidesStale = true;
        } else {
          _monitoredError = error.toString();
          _monitoredLoading = false;
          _monitoredLoadingMore = false;
          _monitoredLoaded = true;
          _monitoredRidesStale = true;
        }
      });
    }
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    if (_needsRefresh(index)) {
      _loadPage(reset: true, tab: index);
    }
  }

  Future<void> _refreshSelected() => _loadPage(reset: true, tab: _selectedTab);

  Future<void> _openRide(Ride ride, {required bool monitored}) async {
    if (!ride.isActive) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveRideScreen(
          ride: ride,
          ridesApiService: widget.ridesApiService,
          isGuardian: monitored,
        ),
      ),
    );
  }

  void _startNewRide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RideStartScreen(ridesApiService: widget.ridesApiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'My Rides',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _refreshSelected,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh rides',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: _buildTabs(),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _tabButton('My rides', 0),
          _tabButton('Rides I monitored', 1),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    final count = index == 0 ? _myTotal : _monitoredTotal;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectTab(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.24))
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
                    style: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 7),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rides.isEmpty) return _buildErrorState();

    return RefreshIndicator(
      onRefresh: _refreshSelected,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          if (_selectedTab == 0)
            ..._buildMyRides()
          else
            ..._buildMonitoredRides(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Could not load more rides. Pull to refresh and try again.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_hasMore) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoadingMore ? null : () => _loadPage(reset: false),
              icon: _isLoadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_isLoadingMore ? 'Loading…' : 'Load more rides'),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Showing ${_rides.length} of $_total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMyRides() {
    final activeRides = _myRides.where((ride) => ride.isActive).toList();
    final active = activeRides.isEmpty ? null : activeRides.first;
    final history = _myRides.where((ride) => !ride.isActive).toList();
    return [
      _buildSectionHeading('Current ride'),
      const SizedBox(height: 12),
      if (active != null)
        _buildActiveRideCard(active, monitored: false)
      else
        _buildNoActiveRideCard(),
      const SizedBox(height: 24),
      _buildSectionHeading(
        'Ride history',
        count: _myTotal - activeRides.length,
      ),
      const SizedBox(height: 12),
      if (history.isEmpty)
        _buildEmptyCard(
          'Completed rides will appear here.',
          Icons.history_rounded,
        )
      else
        ...history.map((ride) => _buildHistoryRideCard(ride, monitored: false)),
    ];
  }

  List<Widget> _buildMonitoredRides() {
    return [
      _buildSectionHeading('Rides shared with you', count: _monitoredTotal),
      const SizedBox(height: 6),
      Text(
        'Ride history appears here only when another rider selected you as a guardian.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 14),
      if (_monitoredRides.isEmpty)
        _buildEmptyCard(
          'Rides shared with you will appear here.',
          Icons.shield_outlined,
        )
      else
        ..._monitoredRides.map(
          (ride) => ride.isActive
              ? _buildActiveRideCard(ride, monitored: true)
              : _buildHistoryRideCard(ride, monitored: true),
        ),
    ];
  }

  Widget _buildSectionHeading(String title, {int? count}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoActiveRideCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No active ride',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your next ride will appear here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RideActionButton(
            onPressed: _startNewRide,
            label: 'Start a Ride',
            icon: Icons.add_road_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message, IconData icon) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideCard(Ride ride, {required bool monitored}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openRide(ride, monitored: monitored),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statusBadge('ACTIVE', AppColors.primary),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (monitored && ride.riderName != null) ...[
                  Text(
                    'Rider: ${ride.riderName}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  ride.rideCode,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
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
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          monitored
                              ? 'View live rider tracking'
                              : 'Continue tracking your ride',
                          style: const TextStyle(
                            color: AppColors.primary,
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
      ),
    );
  }

  Widget _buildHistoryRideCard(Ride ride, {required bool monitored}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusBadge(ride.status.toUpperCase(), colors.onSurfaceVariant),
              const Spacer(),
              Text(
                _formatDate(ride.startedAt),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          if (monitored && ride.riderName != null) ...[
            const SizedBox(height: 12),
            Text(
              'Rider: ${ride.riderName}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            ride.rideCode,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _detailItem(
            Icons.play_circle_outline_rounded,
            'Started: ${_formatTime(ride.startedAt)}',
          ),
          if (ride.endedAt != null) ...[
            const SizedBox(height: 8),
            _detailItem(
              Icons.stop_circle_outlined,
              'Ended: ${_formatTime(ride.endedAt!)}',
            ),
            const SizedBox(height: 8),
            _detailItem(
              Icons.timer_outlined,
              'Duration: ${_formatDuration(ride.startedAt, ride.endedAt!)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
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

  Widget _detailItem(IconData icon, String text) => Row(
    children: [
      Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 55),
          const SizedBox(height: 16),
          const Text(
            'Unable to load rides',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(_error ?? '', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshSelected,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  String _formatDate(DateTime date) {
    final value = toIndiaStandardTime(date);
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _formatTime(DateTime date) {
    final value = toIndiaStandardTime(date);
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} IST';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}
