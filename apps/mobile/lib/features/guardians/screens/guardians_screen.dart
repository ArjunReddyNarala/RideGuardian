import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/config/env_config.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/guardian_invitation.dart';
import '../models/guardian_relationship.dart';
import '../models/rider_safety_settings.dart';
import '../services/guardians_api_service.dart';

enum _GuardiansSection {
  myGuardians,
  peopleIMonitor,
  requests,
}

enum _InvitationMode {
  findGuardian,
  becomeGuardian,
}

class GuardiansScreen extends StatefulWidget {
  const GuardiansScreen({super.key});

  @override
  State<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends State<GuardiansScreen> {
  late final GuardiansApiService _api = GuardiansApiService(
    ApiClient(),
  );

  _GuardiansSection _section = _GuardiansSection.myGuardians;

  bool _isLoading = true;
  String? _errorMessage;

  List<GuardianRelationship> _relationships = [];
  List<GuardianInvitation> _invitations = [];
  List<RiderSafetySettings> _settings = [];

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _currentEmail =>
      _currentUser?.email?.trim().toLowerCase() ?? '';

  String get _currentPhone =>
      _currentUser?.phoneNumber?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _api.getRelationships(),
        _api.getInvitations(),
        _api.getSafetySettings(),
      ]);

      if (!mounted) return;

      setState(() {
        _relationships =
            results[0] as List<GuardianRelationship>;
        _invitations =
            results[1] as List<GuardianInvitation>;
        _settings =
            results[2] as List<RiderSafetySettings>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _errorText(error);
      });
    }
  }

  String _errorText(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  List<GuardianRelationship> get _acceptedRelationships =>
      _relationships.where((item) => item.isAccepted).toList();

  List<GuardianRelationship> get _myGuardians {
    return _acceptedRelationships
        .where((relationship) => _isCurrentRider(relationship))
        .toList();
  }

  List<GuardianRelationship> get _peopleIMonitor {
    return _acceptedRelationships
        .where((relationship) => _isCurrentGuardian(relationship))
        .toList();
  }

  bool _isCurrentRider(GuardianRelationship relationship) {
    return _matchesCurrentUser(relationship.rider);
  }

  bool _isCurrentGuardian(GuardianRelationship relationship) {
    return _matchesCurrentUser(relationship.guardian);
  }

  bool _matchesCurrentUser(RelationshipUser? user) {
    if (user == null) return false;

    if (_currentEmail.isNotEmpty &&
        user.email?.trim().toLowerCase() == _currentEmail) {
      return true;
    }

    if (_currentPhone.isNotEmpty &&
        user.phone?.trim() == _currentPhone) {
      return true;
    }

    return false;
  }

  List<GuardianInvitation> get _receivedInvitations {
    return _invitations.where((invitation) {
      final email = invitation.inviteeEmail?.trim().toLowerCase();
      final phone = invitation.inviteePhone?.trim();

      return (_currentEmail.isNotEmpty &&
              email == _currentEmail) ||
          (_currentPhone.isNotEmpty && phone == _currentPhone);
    }).toList();
  }

  List<GuardianInvitation> get _sentInvitations {
    return _invitations.where((invitation) {
      return !_receivedInvitations.any(
        (received) => received.id == invitation.id,
      );
    }).toList();
  }

  int get _pendingReceivedCount =>
      _receivedInvitations.where((item) => item.isPending).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildHeader(context),
                      const SizedBox(height: 22),
                      _buildSummary(context),
                      const SizedBox(height: 24),
                      _buildInviteActions(context),
                      const SizedBox(height: 28),
                      _buildSectionSelector(context),
                      const SizedBox(height: 18),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_errorMessage != null)
                        _buildErrorState(context)
                      else
                        _buildSelectedSection(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR SAFETY CIRCLE',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Guardians',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Stay connected. Ride with confidence.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: AppColors.primary,
            size: 27,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF18372B),
            colors.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your trusted circle',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_pendingReceivedCount > 0)
                _countBadge(_pendingReceivedCount),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  context,
                  value: '${_myGuardians.length}',
                  label: 'My guardians',
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
              Expanded(
                child: _summaryMetric(
                  context,
                  value: '${_peopleIMonitor.length}',
                  label: 'People I monitor',
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
              Expanded(
                child: _summaryMetric(
                  context,
                  value: '$_pendingReceivedCount',
                  label: 'Requests',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count new',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInviteActions(BuildContext context) {

    return Row(
      children: [
        Expanded(
          child: _inviteActionCard(
            context,
            title: 'Find a Guardian',
            subtitle: 'Someone watches over you',
            icon: Icons.shield_outlined,
            onTap: () => _showInvitationForm(
              context,
              _InvitationMode.findGuardian,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _inviteActionCard(
            context,
            title: 'Become a Guardian',
            subtitle: 'Watch over a rider',
            icon: Icons.health_and_safety_outlined,
            onTap: () => _showInvitationForm(
              context,
              _InvitationMode.becomeGuardian,
            ),
          ),
        ),
      ],
    );
  }

  Widget _inviteActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Text(
                    'Invite',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSelector(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _sectionButton(
            context,
            section: _GuardiansSection.myGuardians,
            label: 'My Guardians',
          ),
          _sectionButton(
            context,
            section: _GuardiansSection.peopleIMonitor,
            label: 'Monitoring',
          ),
          _sectionButton(
            context,
            section: _GuardiansSection.requests,
            label: 'Requests',
            badge: _pendingReceivedCount,
          ),
        ],
      ),
    );
  }

  Widget _sectionButton(
    BuildContext context, {
    required _GuardiansSection section,
    required String label,
    int badge = 0,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _section == section;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _section = section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 12,
          ),
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
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (badge > 0 && section == _GuardiansSection.requests) ...[
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

  Widget _buildSelectedSection(BuildContext context) {
    switch (_section) {
      case _GuardiansSection.myGuardians:
        return _buildRelationshipsList(
          context,
          relationships: _myGuardians,
          emptyTitle: 'No guardians yet',
          emptyDescription:
              'Invite someone you trust to monitor your rides.',
          emptyIcon: Icons.shield_outlined,
          currentUserIsGuardian: false,
        );

      case _GuardiansSection.peopleIMonitor:
        return _buildRelationshipsList(
          context,
          relationships: _peopleIMonitor,
          emptyTitle: 'Nobody here yet',
          emptyDescription:
              'Invite a rider to start looking out for them.',
          emptyIcon: Icons.health_and_safety_outlined,
          currentUserIsGuardian: true,
        );

      case _GuardiansSection.requests:
        return _buildRequestsSection(context);
    }
  }

  Widget _buildRelationshipsList(
    BuildContext context, {
    required List<GuardianRelationship> relationships,
    required String emptyTitle,
    required String emptyDescription,
    required IconData emptyIcon,
    required bool currentUserIsGuardian,
  }) {
    if (relationships.isEmpty) {
      return _buildEmptyState(
        context,
        icon: emptyIcon,
        title: emptyTitle,
        description: emptyDescription,
      );
    }

    return Column(
      children: relationships
          .map(
            (relationship) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _relationshipCard(
                context,
                relationship: relationship,
                currentUserIsGuardian: currentUserIsGuardian,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _relationshipCard(
    BuildContext context, {
    required GuardianRelationship relationship,
    required bool currentUserIsGuardian,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final person = currentUserIsGuardian
        ? relationship.rider
        : relationship.guardian;

    final settings = _settings.where(
      (setting) =>
          setting.guardianId == relationship.guardianId &&
          setting.riderId == relationship.riderId,
    );

    final setting = settings.isEmpty ? null : settings.first;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _personAvatar(context, person),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person?.name ?? 'RideGuardian user',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      person?.email ??
                          person?.phone ??
                          'Contact details unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _statusLabel('Connected'),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Relationship options',
                onSelected: (value) {
                  if (value == 'settings') {
                    _showSafetySettings(
                      context,
                      relationship,
                      setting,
                    );
                  } else if (value == 'remove') {
                    _confirmRevoke(context, relationship);
                  }
                },
                itemBuilder: (_) => [
                  if (currentUserIsGuardian)
                    const PopupMenuItem(
                      value: 'settings',
                      child: Text('Speed settings'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove connection'),
                  ),
                ],
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.speed_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    setting?.maxSpeedKmh == null
                        ? 'Speed limit not configured'
                        : 'Speed limit: ${setting!.maxSpeedKmh!.toStringAsFixed(0)} km/h',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (currentUserIsGuardian)
                  TextButton(
                    onPressed: () => _showSafetySettings(
                      context,
                      relationship,
                      setting,
                    ),
                    child: const Text(
                      'Configure',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsSection(BuildContext context) {
    final received = _receivedInvitations;
    final sent = _sentInvitations;

    if (received.isEmpty && sent.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.mark_email_unread_outlined,
        title: 'All caught up',
        description:
            'Your received and sent invitations will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (received.isNotEmpty) ...[
          _sectionHeading(context, 'Received'),
          const SizedBox(height: 10),
          ...received.map(
            (invitation) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _invitationCard(
                context,
                invitation,
                received: true,
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
        if (sent.isNotEmpty) ...[
          _sectionHeading(context, 'Sent'),
          const SizedBox(height: 10),
          ...sent.map(
            (invitation) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _invitationCard(
                context,
                invitation,
                received: false,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _invitationCard(
    BuildContext context,
    GuardianInvitation invitation, {
    required bool received,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final target = invitation.inviteeEmail ??
        invitation.inviteePhone ??
        'Recipient';

    final relationshipLabel =
        invitation.relationshipType == 'I_MONITOR_THEM'
            ? 'Guardian invitation'
            : 'Become a guardian';

    return Container(
      padding: const EdgeInsets.all(15),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  received
                      ? Icons.mark_email_unread_outlined
                      : Icons.outgoing_mail,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relationshipLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _statusLabel(invitation.status),
            ],
          ),
          if (invitation.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (received) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineInvitation(invitation),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptInvitation(invitation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () => _cancelInvitation(invitation),
                    child: const Text(
                      'Cancel invitation',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Couldn’t load your safety circle',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 31,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _personAvatar(
    BuildContext context,
    RelationshipUser? person,
  ) {
    final photoUrl = person?.profileImageUrl;

    return CircleAvatar(
      radius: 25,
      backgroundColor:
          AppColors.primary.withValues(alpha: 0.13),
      backgroundImage:
          photoUrl != null && photoUrl.isNotEmpty
              ? NetworkImage(photoUrl)
              : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 27,
            )
          : null,
    );
  }

  Widget _statusLabel(String status) {
    final normalized = status.toUpperCase();

    final Color color;

    if (normalized == 'ACCEPTED' ||
        normalized == 'CONNECTED') {
      color = AppColors.primary;
    } else if (normalized == 'PENDING') {
      color = Colors.orange;
    } else if (normalized == 'DECLINED' ||
        normalized == 'REVOKED' ||
        normalized == 'CANCELLED' ||
        normalized == 'EXPIRED') {
      color = Colors.redAccent;
    } else {
      color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _showInvitationForm(
    BuildContext context,
    _InvitationMode mode,
  ) async {
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    bool usePhone = false;
    bool submitting = false;
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      mode == _InvitationMode.findGuardian
                          ? 'Find a Guardian'
                          : 'Become a Guardian',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      mode == _InvitationMode.findGuardian
                          ? 'Invite someone you trust to monitor your rides and help keep you safe.'
                          : 'Invite a rider whose safety you want to look out for.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Email'),
                          icon: Icon(Icons.mail_outline_rounded),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Phone'),
                          icon: Icon(Icons.phone_outlined),
                        ),
                      ],
                      selected: {usePhone},
                      onSelectionChanged: (selection) {
                        setSheetState(() {
                          usePhone = selection.first;
                          formError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller:
                          usePhone ? phoneController : emailController,
                      keyboardType: usePhone
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText:
                            usePhone ? 'Phone number' : 'Email address',
                        hintText: usePhone
                            ? '+91 98765 43210'
                            : 'name@example.com',
                        prefixIcon: Icon(
                          usePhone
                              ? Icons.phone_outlined
                              : Icons.mail_outline_rounded,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final email =
                                    emailController.text.trim();
                                final phone =
                                    phoneController.text.trim();

                                if (usePhone && phone.isEmpty) {
                                  setSheetState(() {
                                    formError =
                                        'Enter a phone number.';
                                  });
                                  return;
                                }

                                if (!usePhone && email.isEmpty) {
                                  setSheetState(() {
                                    formError =
                                        'Enter an email address.';
                                  });
                                  return;
                                }

                                if (!usePhone &&
                                    !RegExp(
                                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                    ).hasMatch(email)) {
                                  setSheetState(() {
                                    formError =
                                        'Enter a valid email address.';
                                  });
                                  return;
                                }

                                setSheetState(() {
                                  submitting = true;
                                  formError = null;
                                });

                                try {
                                  await _api.createInvitation(
                                    email: usePhone ? null : email,
                                    phone: usePhone ? phone : null,
                                    relationshipType:
                                        mode ==
                                                _InvitationMode
                                                    .findGuardian
                                            ? 'THEY_MONITOR_ME'
                                            : 'I_MONITOR_THEM',
                                  );

                                  if (!context.mounted) return;

                                  Navigator.of(context).pop();

                                  _showMessage(
                                    mode ==
                                            _InvitationMode.findGuardian
                                        ? 'Guardian invitation sent.'
                                        : 'Invitation sent to the rider.',
                                  );

                                  await _loadData();
                                } catch (error) {
                                  setSheetState(() {
                                    submitting = false;
                                    formError = _errorText(error);
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: submitting
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Send Invitation',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );


    // Allow the bottom-sheet closing animation to finish before
    // disposing controllers attached to its TextFields.
    await Future<void>.delayed(
      const Duration(milliseconds: 350),
    );

    emailController.dispose();
    phoneController.dispose();
  }

  Future<void> _showSafetySettings(
    BuildContext context,
    GuardianRelationship relationship,
    RiderSafetySettings? existing,
  ) async {
    final riderId = relationship.riderId;

    final speedController = TextEditingController(
      text: existing?.maxSpeedKmh?.toStringAsFixed(0) ?? '',
    );

    bool enabled = existing?.speedAlertEnabled ?? true;
    int cooldown = existing?.speedAlertCooldownSeconds ?? 60;
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colors = theme.colorScheme;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rider safety settings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These settings apply to this guardian–rider connection.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: speedController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Maximum speed (km/h)',
                        hintText: 'e.g. 80',
                        helperText:
                            'Leave empty to remove the configured limit.',
                        prefixIcon: const Icon(Icons.speed_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      activeThumbColor: AppColors.primary,
                      title: const Text(
                        'Speed alerts enabled',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Enable alerts when the rider exceeds the limit.',
                      ),
                      onChanged: (value) {
                        setSheetState(() => enabled = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Alert cooldown',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: cooldown,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 30,
                          child: Text('30 seconds'),
                        ),
                        DropdownMenuItem(
                          value: 60,
                          child: Text('1 minute'),
                        ),
                        DropdownMenuItem(
                          value: 120,
                          child: Text('2 minutes'),
                        ),
                        DropdownMenuItem(
                          value: 300,
                          child: Text('5 minutes'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => cooldown = value);
                        }
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final text =
                                    speedController.text.trim();

                                final double? speed;

                                if (text.isEmpty) {
                                  speed = null;
                                } else {
                                  speed = double.tryParse(text);
                                }

                                if (text.isNotEmpty &&
                                    (speed == null ||
                                        speed <= 0 ||
                                        speed > 999.99)) {
                                  setSheetState(() {
                                    error =
                                        'Enter a speed greater than 0 and no more than 999.99 km/h.';
                                  });
                                  return;
                                }

                                setSheetState(() {
                                  saving = true;
                                  error = null;
                                });

                                try {
                                  await _api.updateSafetySettings(
                                    riderId: riderId,
                                    maxSpeedKmh: speed,
                                    speedAlertEnabled: enabled,
                                    speedAlertCooldownSeconds: cooldown,
                                  );

                                  if (!context.mounted) return;

                                  Navigator.of(context).pop();

                                  _showMessage(
                                    'Safety settings updated.',
                                  );

                                  await _loadData();
                                } catch (exception) {
                                  setSheetState(() {
                                    saving = false;
                                    error = _errorText(exception);
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                height: 21,
                                width: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Allow the bottom-sheet closing animation to finish before
    // disposing the controller attached to its TextField.
    await Future<void>.delayed(
      const Duration(milliseconds: 350),
    );

    speedController.dispose();
  }

  Future<void> _acceptInvitation(
    GuardianInvitation invitation,
  ) async {
    final token = invitation.token;

    if (token == null || token.isEmpty) {
      _showMessage(
        'This invitation response does not contain an acceptance token. Check the backend invitation-list response.',
      );
      return;
    }

    await _performAction(
      () => _api.acceptInvitation(token),
      'Invitation accepted.',
    );
  }

  Future<void> _declineInvitation(
    GuardianInvitation invitation,
  ) async {
    final token = invitation.token;

    if (token == null || token.isEmpty) {
      _showMessage(
        'This invitation response does not contain a decline token. Check the backend invitation-list response.',
      );
      return;
    }

    await _performAction(
      () => _api.declineInvitation(token),
      'Invitation declined.',
    );
  }

  Future<void> _cancelInvitation(
    GuardianInvitation invitation,
  ) async {
    final confirmed = await _confirm(
      title: 'Cancel invitation?',
      message: 'The pending invitation will be cancelled.',
      confirmLabel: 'Cancel invitation',
    );

    if (!confirmed) return;

    await _performAction(
      () => _api.cancelInvitation(invitation.id),
      'Invitation cancelled.',
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    GuardianRelationship relationship,
  ) async {
    final confirmed = await _confirm(
      title: 'Remove connection?',
      message:
          'This will end the guardian–rider relationship. You can invite the person again later.',
      confirmLabel: 'Remove',
    );

    if (!confirmed) return;

    await _performAction(
      () => _api.revokeRelationship(relationship.id),
      'Connection removed.',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: Text(
                confirmLabel,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _performAction(
    Future<dynamic> Function() action,
    String successMessage,
  ) async {
    try {
      await action();

      if (!mounted) return;

      _showMessage(successMessage);

      await _loadData();
    } catch (error) {
      if (!mounted) return;

      _showMessage(_errorText(error));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}