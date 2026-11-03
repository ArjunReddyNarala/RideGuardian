import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/home/screens/home_screen.dart';
import 'features/rides/services/rides_api_service.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const RideGuardianApp());
}

class RideGuardianApp extends StatelessWidget {
  const RideGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideGuardian',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<User?> _initialUser = FirebaseAuth.instance
      .authStateChanges()
      .first;
  late final RidesApiService _ridesApiService = RidesApiService(ApiClient());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _initialUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != null) {
          return HomeScreen(ridesApiService: _ridesApiService);
        }

        return const WelcomeScreen();
      },
    );
  }
}
