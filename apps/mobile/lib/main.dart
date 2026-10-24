import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';

Future main() async {
WidgetsFlutterBinding.ensureInitialized();

await Firebase.initializeApp(
options: DefaultFirebaseOptions.currentPlatform,
);

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
home: const WelcomeScreen(),
);
}
}