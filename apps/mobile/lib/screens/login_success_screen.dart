import 'package:flutter/material.dart';

import '../services/user_api.dart';

class LoginSuccessScreen extends StatefulWidget {
  const LoginSuccessScreen({super.key});

  @override
  State<LoginSuccessScreen> createState() => _LoginSuccessScreenState();
}

class _LoginSuccessScreenState extends State<LoginSuccessScreen> {
  bool _isLoading = false;
  String? _result;

  Future<void> _testProfileApi() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final user = await UserApi.instance.getMe();

      if (!mounted) return;

      setState(() {
        _result =
            '''
API Successful!

Name: ${user['name']}
Email: ${user['email']}
User ID: ${user['id']}
Firebase UID: ${user['firebaseUid']}
''';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _result = 'API Failed:\n$e';
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 90),

                const SizedBox(height: 24),

                const Text(
                  'Login Successful',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Welcome to RideGuardian!',
                  style: TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isLoading ? null : _testProfileApi,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('Test My Profile API'),
                ),

                if (_result != null) ...[
                  const SizedBox(height: 24),
                  Text(_result!, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
