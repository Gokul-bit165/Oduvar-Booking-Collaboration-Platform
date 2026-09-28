import 'package:flutter/material.dart';
import 'auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_model.dart';
import 'welcome_screen.dart';
import '../../client/presentation/client_home_screen.dart';
import '../../oduvar/presentation/oduvar_dashboard_screen.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  final AuthState authState;

  const SplashScreen({super.key, required this.authState});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Artificial slight delay for smooth visual transition
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    await widget.authState.initialize();
    if (!mounted) return;

    if (widget.authState.isAuthenticated) {
      _routeByRole(widget.authState.currentUser!.role);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(authState: widget.authState),
        ),
      );
    }
  }

  void _routeByRole(UserRole role) {
    Widget destination;
    switch (role) {
      case UserRole.client:
        destination = ClientHomeScreen(authState: widget.authState);
        break;
      case UserRole.oduvar:
        destination = OduvarDashboardScreen(authState: widget.authState);
        break;
      case UserRole.admin:
        destination = AdminDashboardScreen(authState: widget.authState);
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryMaroonDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [AppTheme.sacredSaffron, AppTheme.sacredGold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.sacredSaffron.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.temple_hindu_rounded,
                  size: 46,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'திருச்சிற்றம்பலம்',
                style: TextStyle(
                  color: AppTheme.sacredSaffron,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Oduvar Booking & Collaboration',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sacred Devotional Services & Hymns',
                style: TextStyle(
                  color: Color(0xFFFDE8E8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.sacredSaffron),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
