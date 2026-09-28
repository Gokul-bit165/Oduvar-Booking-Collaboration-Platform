import 'package:flutter/material.dart';
import 'auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final AuthState authState;

  const WelcomeScreen({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top sacred art hero
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5A0E0E), AppTheme.primaryMaroon],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.sacredSaffron.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.temple_hindu_rounded,
                        size: 64,
                        color: AppTheme.sacredSaffron,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'தென்னாடுடைய சிவனே போற்றி',
                      style: TextStyle(
                        color: AppTheme.sacredSaffron,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Online Oduvar Booking & Collaboration',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Connecting devotees and temples with venerable Oduvars for Thevaram, Thiruvasagam and sacred events.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFDE8E8),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom actions
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppButton(
                      customKey: const Key('welcome_login_button'),
                      label: 'Sign In to Your Account',
                      variant: AppButtonVariant.primary,
                      icon: Icons.login_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LoginScreen(authState: authState),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      customKey: const Key('welcome_register_button'),
                      label: 'Create an Account',
                      variant: AppButtonVariant.outlined,
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RoleSelectionScreen(authState: authState),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Respectful • Authentic • Trustworthy',
                      style: TextStyle(
                        color: Color(0xFF8C7E72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
