import 'package:flutter/material.dart';
import '../../auth/presentation/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';

class OduvarDashboardScreen extends StatelessWidget {
  final AuthState authState;

  const OduvarDashboardScreen({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    final user = authState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oduvar Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Oduvar Sacred Profile Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF78350F), AppTheme.sacredGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3DB45309),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded, color: Colors.white, size: 26),
                        const SizedBox(width: 8),
                        const Text(
                          'தென்னாடுடைய சிவனே போற்றி',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? 'Oduvar Peruman',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        color: Color(0xFFFEF3C7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ROLE: ODUVAR (HYMN SINGER)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: AppTheme.successGreen,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Active',
                                style: TextStyle(
                                  color: AppTheme.successGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Phase 1 Foundation Card
              AppCard(
                borderColor: AppTheme.sacredGold.withOpacity(0.3),
                backgroundColor: const Color(0xFFFFFDF9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.sacredSaffron.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppTheme.sacredGold, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Oduvar Access Verified',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryMaroonDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your Oduvar credentials are authenticated. Profile builder, audio gallery, and availability calendars will be activated in Phase 2.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B5E53), height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Sacred Schedule & Requests (Upcoming)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C241F),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildOduvarMetric(
                      title: 'Pending Requests',
                      count: '0',
                      icon: Icons.notifications_active_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOduvarMetric(
                      title: 'Collaborations',
                      count: '0',
                      icon: Icons.handshake_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              AppButton(
                label: 'Sign Out',
                variant: AppButtonVariant.outlined,
                icon: Icons.logout_rounded,
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOduvarMetric({
    required String title,
    required String count,
    required IconData icon,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.sacredGold, size: 26),
          const SizedBox(height: 12),
          Text(
            count,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C241F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A7D71),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to end your current session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              authState.logout();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
