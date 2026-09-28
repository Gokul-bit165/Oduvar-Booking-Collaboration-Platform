import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_state.dart';
import 'features/auth/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authState = AuthState();

  runApp(OduvarApp(authState: authState));
}

class OduvarApp extends StatelessWidget {
  final AuthState authState;

  const OduvarApp({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Oduvar Booking & Collaboration',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: SplashScreen(authState: authState),
    );
  }
}
