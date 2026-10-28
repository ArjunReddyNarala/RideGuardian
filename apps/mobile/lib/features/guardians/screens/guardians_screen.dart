import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/guardian_invitation.dart';
import '../models/guardian_relationship.dart';
import '../models/rider_safety_settings.dart';
import '../services/guardians_api_service.dart';
import '../widgets/guardian_invitation_card.dart';
import '../widgets/guardian_relationship_card.dart';
import '../widgets/guardians_empty_state.dart';
import '../widgets/guardians_error_state.dart';
import '../widgets/guardians_header.dart';
import '../widgets/guardians_invite_actions.dart';
import '../widgets/guardians_section_selector.dart';
import '../widgets/guardians_summary_card.dart';
enum _GuardiansSection {
  myGuardians,
  peopleIMonitor,
  requests
}
enum _InvitationMode {
  findGuardian,
  becomeGuardian
}
class GuardiansScreen extends StatefulWidget {
  const GuardiansScreen({super.key});
  @override
  State<GuardiansScreen> createState() => _GuardiansScreenState();
}
class _GuardiansScreenState extends State<GuardiansScreen> {
  late final GuardiansApiService _api = GuardiansApiService(ApiClient());
  _GuardiansSection _section = _GuardiansSection.myGuardians;
  bool _isLoading = true;
  String? _errorMessage;
  List<GuardianRelationship> _relationships = [];
  List<GuardianInvitation> _invitations = [];
  List<RiderSafetySettings> _settings = [];
  User? get _currentUser => FirebaseAuth.instance.currentUser;
  String get _currentEmail =>
  _currentUser?.email?.trim().toLowerCase() ?? '';
  String get _currentPhone => _currentUser?.phoneNumber?.trim() ?? '';
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _api.getRelationships(),
        _api.getInvitations(),
        _api.getSafetySettings()
      ]);
      if (!mounted) return;
      setState(() {
        _relationships = results[0] as List<GuardianRelationship>;
        _invitations = results[1] as List<GuardianInvitation>;
        _settings = results[2] as List<RiderSafetySettings>;
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
  // ---------------------------------------------------------------------------
  // Relationship and invitation filtering
  // ---------------------------------------------------------------------------
  List<GuardianRelationship> get _acceptedRelationships =>
  _relationships.where((item) => item.isAccepted).toList();
  List<GuardianRelationship> get _myGuardians {
    return _acceptedRelationships
      .where(_isCurrentRider)
      .toList();
  }
  List<GuardianRelationship> get _peopleIMonitor {
    return _acceptedRelationships
      .where(_isCurrentGuardian)
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
      return (_currentEmail.isNotEmpty && email == _currentEmail) ||
        (_currentPhone.isNotEmpty && phone == _currentPhone);
    }).toList();
  }
  List<GuardianInvitation> get _sentInvitations {
    final receivedIds = _receivedInvitations
      .map((invitation) => invitation.id)
      .toSet();
    return _invitations
      .where((invitation) => !receivedIds.contains(invitation.id))
      .toList();
  }
  int get _pendingReceivedCount =>
  _receivedInvitations.where((item) => item.isPending).length;
  // ---------------------------------------------------------------------------
  // Main screen
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                  delegate: SliverChildListDelegate([
                    const GuardiansHeader(),
                    const SizedBox(height: 22),
                    GuardiansSummaryCard(
                      myGuardiansCount: _myGuardians.length,
                      peopleIMonitorCount: _peopleIMonitor.length,
                      pendingRequestsCount: _pendingReceivedCount
                    ),
                    const SizedBox(height: 24),
                    GuardiansInviteActions(
                      onFindGuardian: () => _showInvitationForm(
                        context,
                        _InvitationMode.findGuardian
                      ),
                      onBecomeGuardian: () => _showInvitationForm(
                        context,
                        _InvitationMode.becomeGuardian
                      )
                    ),
                    const SizedBox(height: 28),
                    GuardiansSectionSelector(
                      selectedIndex: _section.index,
                      pendingRequestsCount: _pendingReceivedCount,
                      onChanged: (index) {
                        if (index < 0 ||
                          index >= _GuardiansSection.values.length) {
                          return;
                        }
                        setState(() {
                          _section = _GuardiansSection.values[index];
                        });
                      }
                    ),
                    const SizedBox(height: 18),
                    if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator()
                      )
                    )
                    else if (_errorMessage != null)
                    GuardiansErrorState(
                      message: _errorMessage!,
                      onRetry: _loadData
                    )
                    else
                    _buildSelectedSection(context)
                  ])
                )
              )
            ]
          )
        )
      )
    );
  }
  // ---------------------------------------------------------------------------
  // Selected section
  // ---------------------------------------------------------------------------
  Widget _buildSelectedSection(BuildContext context) {
    switch (_section) {
      case _GuardiansSection.myGuardians:
        return _buildRelationshipsList(
          relationships: _myGuardians,
          emptyTitle: 'No guardians yet',
          emptyDescription:
          'Invite someone you trust to monitor your rides.',
          emptyIcon: Icons.shield_outlined,
          currentUserIsGuardian: false
        );
      case _GuardiansSection.peopleIMonitor:
        return _buildRelationshipsList(
          relationships: _peopleIMonitor,
          emptyTitle: 'Nobody here yet',
          emptyDescription:
          'Invite a rider to start looking out for them.',
          emptyIcon: Icons.health_and_safety_outlined,
          currentUserIsGuardian: true
        );
      case _GuardiansSection.requests:
        return _buildRequestsSection();
    }
  }
  Widget _buildRelationshipsList({
    required List<GuardianRelationship> relationships,
    required String emptyTitle,
    required String emptyDescription,
    required IconData emptyIcon,
    required bool currentUserIsGuardian
  }) {
    if (relationships.isEmpty) {
      return GuardiansEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        description: emptyDescription
      );
    }
    return Column(
      children: relationships.map((relationship) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _relationshipCard(
            relationship: relationship,
            currentUserIsGuardian: currentUserIsGuardian
          )
        );
      }).toList()
    );
  }
  Widget _relationshipCard({
    required GuardianRelationship relationship,
    required bool currentUserIsGuardian
  }) {
    final matchingSettings = _settings.where(
      (setting) =>
      setting.guardianId == relationship.guardianId &&
        setting.riderId == relationship.riderId
    );
    final setting =
      matchingSettings.isEmpty ? null : matchingSettings.first;
    return GuardianRelationshipCard(
      relationship: relationship,
      setting: setting,
      currentUserIsGuardian: currentUserIsGuardian,
      onConfigure: () => _showSafetySettings(
        context,
        relationship,
        setting
      ),
      onRemove: () => _confirmRevoke(
        context,
        relationship
      )
    );
  }
  // ---------------------------------------------------------------------------
  // Invitation requests
  // ---------------------------------------------------------------------------
  Widget _buildRequestsSection() {
    final received = _receivedInvitations;
    final sent = _sentInvitations;
    if (received.isEmpty && sent.isEmpty) {
      return const GuardiansEmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'All caught up',
        description:
        'Your received and sent invitations will appear here.'
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (received.isNotEmpty) ...[
          _sectionHeading('Received'),
          const SizedBox(height: 10),
          ...received.map(
            (invitation) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _invitationCard(
                invitation,
                received: true
              )
            )
          ),
          const SizedBox(height: 15)
        ],
        if (sent.isNotEmpty) ...[
          _sectionHeading('Sent'),
          const SizedBox(height: 10),
          ...sent.map(
            (invitation) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _invitationCard(
                invitation,
                received: false
              )
            )
          )
        ]
      ]
    );
  }
  Widget _invitationCard(
    GuardianInvitation invitation, {
      required bool received
    }) {
    return GuardianInvitationCard(
      invitation: invitation,
      received: received,
      onAccept: () => _acceptInvitation(invitation),
      onDecline: () => _declineInvitation(invitation),
      onCancel: () => _cancelInvitation(invitation)
    );
  }
  Widget _sectionHeading(String title) {
    return Text(
      title,
      style: Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w800)
    );
  }
  // ---------------------------------------------------------------------------
  // Create invitation
  // ---------------------------------------------------------------------------
  Future<void> _showInvitationForm(
    BuildContext context,
    _InvitationMode mode
  ) async {
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    bool usePhone = false;
    bool submitting = false;
    String? formError;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28)
          )
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
                  MediaQuery.of(context).viewInsets.bottom + 22
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
                            borderRadius: BorderRadius.circular(10)
                          )
                        )
                      ),
                      const SizedBox(height: 22),
                      Text(
                        mode == _InvitationMode.findGuardian
                          ? 'Find a Guardian'
                          : 'Become a Guardian',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800
                        )
                      ),
                      const SizedBox(height: 7),
                      Text(
                        mode == _InvitationMode.findGuardian
                          ? 'Invite someone you trust to monitor your rides and help keep you safe.'
                          : 'Invite a rider whose safety you want to look out for.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45
                        )
                      ),
                      const SizedBox(height: 22),
                      SegmentedButton<bool>(
                        segments: const[
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Email'),
                            icon: Icon(Icons.mail_outline_rounded)
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Phone'),
                            icon: Icon(Icons.phone_outlined)
                          )
                        ],
                        selected: {usePhone},
                        onSelectionChanged: (selection) {
                          setSheetState(() {
                            usePhone = selection.first;
                            formError = null;
                          });
                        }
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
                              : Icons.mail_outline_rounded
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)
                          )
                        )
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          formError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13
                          )
                        )
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
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$'
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
                                    _InvitationMode.findGuardian
                                    ? 'THEY_MONITOR_ME'
                                    : 'I_MONITOR_THEM'
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                _showMessage(
                                  mode ==
                                    _InvitationMode.findGuardian
                                    ? 'Guardian invitation sent.'
                                    : 'Invitation sent to the rider.'
                                );
                                await _loadData();
                              } catch (error) {
                                if (!context.mounted) return;
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
                              borderRadius: BorderRadius.circular(16)
                            )
                          ),
                          child: submitting
                            ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white
                              )
                            )
                            : const Text(
                              'Send Invitation',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15
                              )
                            )
                        )
                      )
                    ]
                  )
                )
              );
            }
          );
        }
      );
    } finally {
      // Let the bottom sheet finish closing before disposing its controllers.
      await Future<void>.delayed(
        const Duration(milliseconds: 350)
      );
      emailController.dispose();
      phoneController.dispose();
    }
  }
  // ---------------------------------------------------------------------------
  // Rider safety settings
  // ---------------------------------------------------------------------------
  Future<void> _showSafetySettings(
    BuildContext context,
    GuardianRelationship relationship,
    RiderSafetySettings? existing
  ) async {
    final riderId = relationship.riderId;
    final speedController = TextEditingController(
      text: existing?.maxSpeedKmh?.toStringAsFixed(0) ?? ''
    );
    bool enabled = existing?.speedAlertEnabled ?? true;
    int cooldown = existing?.speedAlertCooldownSeconds ?? 60;
    bool saving = false;
    String? error;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28)
          )
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
                  MediaQuery.of(context).viewInsets.bottom + 22
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rider safety settings',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800
                        )
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'These settings apply to this guardian–rider connection.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant
                        )
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: speedController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true
                        ),
                        decoration: InputDecoration(
                          labelText: 'Maximum speed (km/h)',
                          hintText: 'e.g. 80',
                          helperText:
                          'Leave empty to remove the configured limit.',
                          prefixIcon: const Icon(Icons.speed_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)
                          )
                        )
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: enabled,
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          'Speed alerts enabled',
                          style: TextStyle(fontWeight: FontWeight.w700)
                        ),
                        subtitle: const Text(
                          'Enable alerts when the rider exceeds the limit.'
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            enabled = value;
                          });
                        }
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Alert cooldown',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800
                        )
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: cooldown,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)
                          )
                        ),
                        items: const[
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 seconds')
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('1 minute')
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text('2 minutes')
                          ),
                          DropdownMenuItem(
                            value: 300,
                            child: Text('5 minutes')
                          )
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() {
                              cooldown = value;
                            });
                          }
                        }
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.redAccent
                          )
                        )
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
                                  speedAlertCooldownSeconds: cooldown
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                _showMessage(
                                  'Safety settings updated.'
                                );
                                await _loadData();
                              } catch (exception) {
                                if (!context.mounted) return;
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
                              borderRadius: BorderRadius.circular(16)
                            )
                          ),
                          child: saving
                            ? const SizedBox(
                              height: 21,
                              width: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white
                              )
                            )
                            : const Text(
                              'Save settings',
                              style: TextStyle(
                                fontWeight: FontWeight.w800
                              )
                            )
                        )
                      )
                    ]
                  )
                )
              );
            }
          );
        }
      );
    } finally {
      // Let the bottom sheet finish closing before disposing its controller.
      await Future<void>.delayed(
        const Duration(milliseconds: 350)
      );
      speedController.dispose();
    }
  }
  // ---------------------------------------------------------------------------
  // Invitation and relationship actions
  // ---------------------------------------------------------------------------
  Future<void> _acceptInvitation(
    GuardianInvitation invitation
  ) async {
    final token = invitation.token;
    if (token == null || token.isEmpty) {
      _showMessage(
        'Unable to accept this invitation because its token is missing. '
        'Refresh the invitations and try again.'
      );
      await _loadData();
      return;
    }
    await _performAction(
      () => _api.acceptInvitation(token),
      'Invitation accepted.'
    );
  }
  Future<void> _declineInvitation(
    GuardianInvitation invitation
  ) async {
    final token = invitation.token;
    if (token == null || token.isEmpty) {
      _showMessage(
        'Unable to decline this invitation because its token is missing. '
        'Refresh the invitations and try again.'
      );
      await _loadData();
      return;
    }
    await _performAction(
      () => _api.declineInvitation(token),
      'Invitation declined.'
    );
  }
  Future<void> _cancelInvitation(
    GuardianInvitation invitation
  ) async {
    final confirmed = await _confirm(
      title: 'Cancel invitation?',
      message: 'The pending invitation will be cancelled.',
      confirmLabel: 'Cancel invitation'
    );
    if (!confirmed) return;
    await _performAction(
      () => _api.cancelInvitation(invitation.id),
      'Invitation cancelled.'
    );
  }
  Future<void> _confirmRevoke(
    BuildContext context,
    GuardianRelationship relationship
  ) async {
    final confirmed = await _confirm(
      title: 'Remove connection?',
      message:
      'This will end the guardian–rider relationship. '
      'You can invite the person again later.',
      confirmLabel: 'Remove'
    );
    if (!confirmed) return;
    await _performAction(
      () => _api.revokeRelationship(relationship.id),
      'Connection removed.'
    );
  }
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Keep')
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  color: Colors.redAccent
                )
              )
            )
          ]
        );
      }
    );
    return result ?? false;
  }
  Future<void> _performAction(
    Future<dynamic> Function() action,
    String successMessage
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
        behavior: SnackBarBehavior.floating
      )
    );
  }
}
