import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/api_urls.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../authentication/services/auth_service.dart';
import '../../../screens/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _loading = true;
  bool _savingDnd = false;
  bool _doNotDisturb = false;
  String? _name;
  String? _email;
  String? _photoUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _apiClient.get(ApiUrls.currentUser);
      final data = response is Map<String, dynamic> && response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid profile response.');
      }
      if (!mounted) return;
      final firebaseUser = FirebaseAuth.instance.currentUser;
      setState(() {
        _name = data['name'] as String? ?? firebaseUser?.displayName;
        _email = data['email'] as String? ?? firebaseUser?.email;
        _photoUrl =
            data['profileImageUrl'] as String? ?? firebaseUser?.photoURL;
        _doNotDisturb = data['doNotDisturb'] == true;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _name = user?.displayName;
        _email = user?.email;
        _photoUrl = user?.photoURL;
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _setDoNotDisturb(bool enabled) async {
    final previous = _doNotDisturb;
    setState(() {
      _doNotDisturb = enabled;
      _savingDnd = true;
    });
    try {
      await _apiClient.patch(
        ApiUrls.currentUser,
        body: {'doNotDisturb': enabled},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Do Not Disturb is on. Riders cannot select you for new rides.'
                  : 'Do Not Disturb is off. Riders can select you again.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _doNotDisturb = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update this setting: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingDnd = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to use Ride Guardian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed. Please try again. ($error)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Text(
            'Profile',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primary.withValues(alpha: .14),
                    backgroundImage: _photoUrl == null
                        ? null
                        : NetworkImage(_photoUrl!),
                    child: _photoUrl == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 34,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_name?.trim().isNotEmpty ?? false)
                              ? _name!
                              : 'Ride Guardian user',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email ?? 'No email address',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Profile details could not fully load. Pull to refresh.',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          const SizedBox(height: 18),
          Card(
            child: SwitchListTile.adaptive(
              value: _doNotDisturb,
              onChanged: _savingDnd ? null : _setDoNotDisturb,
              secondary: const Icon(
                Icons.do_not_disturb_on_outlined,
                color: Color(0xFF8B5CF6),
              ),
              title: const Text(
                'Do Not Disturb',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _doNotDisturb
                    ? 'You cannot be selected as a guardian for new rides.'
                    : 'Allow riders to select you as a guardian.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(context, 'Help & support'),
          Card(
            child: Column(
              children: [
                const ExpansionTile(
                  leading: Icon(Icons.help_outline_rounded),
                  title: Text('FAQs'),
                  childrenPadding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                  children: [
                    _FaqItem(
                      question: 'How do I share a ride?',
                      answer: 'Open Start Ride, choose at least one connected guardian, then start your ride.',
                    ),
                    _FaqItem(
                      question: 'Can I stop sharing my location?',
                      answer: 'End your active ride from the active ride screen. Location sharing stops when the ride ends.',
                    ),
                    _FaqItem(
                      question: 'What does Do Not Disturb do?',
                      answer: 'When enabled, riders cannot add you to new rides as a guardian.',
                    ),
                  ],
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('Contact support'),
                  subtitle: const Text(
                    'Temporary support contacts\nsupport@rideguardian.app  ·  +91 80000 00000',
                  ),
                  isThreeLine: true,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _PrivacyPolicyScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('App version'),
                  trailing: Text('0.1.0 (1)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(answer, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy policy')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Text(
        'Ride Guardian uses your account information to provide and secure the service. When a rider starts a ride, their live location and ride details are shared with the guardians they select. Ride and location records may be retained to show ride history and support safety features.\n\nYou can stop live sharing by ending the active ride. Do Not Disturb prevents you from being selected as a guardian for new rides. You may contact support with questions about your account or personal information.',
        style: TextStyle(height: 1.6),
      ),
    ),
  );
}
