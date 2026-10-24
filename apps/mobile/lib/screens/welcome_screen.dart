import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/authentication/screens/phone_sign_in_screen.dart';
import '../features/authentication/services/auth_service.dart';
import '../features/home/screens/home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final isDarkMode = theme.brightness == Brightness.dark;

    final googleLogoAsset = isDarkMode
        ? 'lib/assets/icons/google_sign_in/google_logo_dark.png'
        : 'lib/assets/icons/google_sign_in/google_logo_light.png';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Brand name and tagline.
                      Center(
                        child: Column(
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Ride',
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.2,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Guardian',
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'SAFETY FOR EVERY JOURNEY',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 52),

                      // Main welcome message.
                      Text(
                        'Your journey\nYour safety\nOur priority',
                        style: textTheme.headlineLarge?.copyWith(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          height: 1.25,
                          letterSpacing: -0.8,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 22),

                      // Supporting description.
                      Text(
                        'Your loved ones care about every mile. '
                        'Ride confidently while staying connected.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 17,
                          height: 1.7,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Flexible space pushes the buttons toward the bottom.
                      const Spacer(flex: 2),

                      // Google sign-in button.
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () => _signInWithGoogle(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            side: BorderSide(
                              color: colorScheme.outlineVariant,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                googleLogoAsset,
                                width: 30,
                                height: 30,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 30,
                                    color: colorScheme.onSurface,
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Continue with Google',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Phone sign-in button.
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PhoneSignInScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.phone_iphone_rounded,
                                size: 21,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Continue with Phone Number',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Space between buttons and legal text.
                      const SizedBox(height: 40),

                      // Legal information.
                      Text.rich(
                        TextSpan(
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.8,
                            fontSize: 13,
                          ),
                          children: [
                            const TextSpan(
                              text: 'By continuing, you agree to our ',
                            ),
                            const TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            const TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      await AuthService.instance.signInWithGoogle();

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-in failed. Please try again.'),
        ),
      );
    }
  }
}
