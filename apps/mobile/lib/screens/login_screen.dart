import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential =
          await AuthService.instance.signInWithGoogle();

      final backendUser =
          await AuthService.instance.syncWithBackend();
      
      print('Backend user: $backendUser');

      if (!mounted) {
        return;
      }

      final user = credential.user;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome ${user?.displayName ?? 'to RideGuardian'}!',
          ),
        ),
      );

      debugPrint('Backend user: $backendUser');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'RideGuardian',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your ride. Your guardians. Your safety.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithGoogle,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Continue with Google'),
              ),

              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        // Phone authentication will be added next.
                      },
                child: const Text('Continue with Mobile Number'),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}