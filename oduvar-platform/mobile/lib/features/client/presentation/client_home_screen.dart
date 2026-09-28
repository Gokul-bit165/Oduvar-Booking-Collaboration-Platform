import 'package:flutter/material.dart';
import '../../auth/presentation/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';

class ClientHomeScreen extends StatelessWidget {
  final AuthState authState;

  const ClientHomeScreen({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    final user = authState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devotee Sanctuary'),
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
              // Devotional Greeting Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryMaroonDark, AppTheme.primaryMaroon],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x298D1B1B),
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
                        const Icon(Icons.temple_hindu_rounded, color: AppTheme.sacredSaffron, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          'திருச்சிற்றம்பலம்',
                          style: TextStyle(
                            color: AppTheme.sacredSaffron,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vanakkam, ${user?.name ?? 'Devotee'}',
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
                        color: Color(0xFFFEE2E2),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ROLE: DEVOTEE / CLIENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Phase 1 Foundation Notice
              AppCard(
                borderColor: AppTheme.sacredGold.withOpacity(0.4),
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
                          child: const Icon(Icons.check_circle_rounded, color: AppTheme.sacredGold, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Phase 1: Auth Active',
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
                      'Your client session is securely authenticated via JWT. Booking discovery and calendar requests will arrive in Phase 2 & 3.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B5E53), height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Sacred Services (Upcoming)',
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
                    child: _buildServicePlaceholderCard(
                      icon: Icons.search_rounded,
                      title: 'Browse Oduvars',
                      subtitle: 'Find Thevaram & Thiruvasagam singers',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildServicePlaceholderCard(
                      icon: Icons.calendar_month_rounded,
                      title: 'My Bookings',
                      subtitle: 'Upcoming & completed events',
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

  Widget _buildServicePlaceholderCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryMaroon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryMaroon, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C241F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8A7D71),
              height: 1.3,
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
