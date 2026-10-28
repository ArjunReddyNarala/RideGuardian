import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/guardian_invitation.dart';

class GuardianInvitationCard extends StatelessWidget {
  final GuardianInvitation invitation;
  final bool received;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  const GuardianInvitationCard({
    super.key,
    required this.invitation,
    required this.received,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final target = received
        ? invitation.senderContact
        : invitation.recipientContact;

    final relationshipLabel = invitation.relationshipType == 'I_MONITOR_THEM'
        ? 'Let Me Monitor Your Rides'
        : 'Become My Guardian';

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
              _InvitationStatusLabel(status: invitation.status),
            ],
          ),
          if (invitation.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (received) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
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
                    onPressed: onCancel,
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
}

class _InvitationStatusLabel extends StatelessWidget {
  final String status;

  const _InvitationStatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();

    final Color color;

    if (normalized == 'ACCEPTED' || normalized == 'CONNECTED') {
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
}
