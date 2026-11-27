import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/screens/home_screen.dart';
import '../../rides/services/rides_api_service.dart';
import '../services/auth_service.dart';
import '../widgets/auth_action_button.dart';
import 'otp_verification_screen.dart';

class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String _countryCode = '+91';
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phoneNumber = '$_countryCode${_phoneController.text.trim()}';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.sendPhoneOtp(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OtpVerificationScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
              ),
            ),
          );
        },
        onError: (message) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
            _errorMessage = message;
          });
        },
        onAutoVerified: _onAutoVerified,
        onTimeout: () {},
      );
    } catch (error, stackTrace) {
      debugPrint('Phone sign-in request failed.');
      debugPrint('Error type: ${error.runtimeType}');
      debugPrint('Error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to send the verification code. '
            'Please try again.';
      });
    }
  }

  void _onAutoVerified(PhoneAuthCredential credential) {
    unawaited(_completeAutoVerification(credential));
  }

  Future<void> _completeAutoVerification(PhoneAuthCredential credential) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signInWithPhoneCredential(credential);
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              HomeScreen(ridesApiService: RidesApiService(ApiClient())),
        ),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Phone sign-in could not be completed. Please retry.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    color: AppColors.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Enter your phone number',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We’ll send you a verification code to confirm '
                  'your phone number.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Phone number',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: DropdownButtonFormField<String>(
                        initialValue: _countryCode,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 18,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: '+91', child: Text('+91')),
                          DropdownMenuItem(value: '+1', child: Text('+1')),
                          DropdownMenuItem(value: '+44', child: Text('+44')),
                          DropdownMenuItem(value: '+61', child: Text('+61')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _countryCode = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(15),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Phone number',
                        ),
                        validator: (value) {
                          final digits = value?.trim() ?? '';

                          if (digits.isEmpty) {
                            return 'Enter your phone number';
                          }

                          if (digits.length < 7 || digits.length > 15) {
                            return 'Enter a valid phone number';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                AuthActionButton(
                  label: 'Send verification code',
                  loadingLabel: 'Sending code…',
                  leading: Icon(
                    Icons.sms_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  isLoading: _isLoading,
                  onPressed: _continue,
                ),
                const SizedBox(height: 20),
                Text(
                  'By continuing, you agree to our Terms of Service '
                  'and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.scrim.withValues(alpha: 0.38),
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Sending verification code',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Sending verification code…',
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
