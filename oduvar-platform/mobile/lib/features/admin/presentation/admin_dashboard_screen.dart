import 'package:flutter/material.dart';
import '../../auth/presentation/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';

class AdminDashboardScreen extends StatelessWidget {
  final AuthState authState;

  const AdminDashboardScreen({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    final user = authState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
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
              // Admin Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, color: AppTheme.sacredSaffron, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'PLATFORM ADMINISTRATION',
                          style: TextStyle(
                            color: AppTheme.sacredSaffron,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? 'Platform Administrator',
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
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.2),
                        border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ROLE: ADMIN (PRIVILEGED ACCESS)',
                        style: TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Phase 1 System Notice
              AppCard(
                borderColor: const Color(0xFFCBD5E1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security_rounded, color: Color(0xFF0F172A), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Phase 1: Admin Protection Active',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Admin accounts are strictly protected from public registration and can only authenticate via secured credentials. Moderation, audit logs, and user management queues will unlock in Phase 10.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Platform Overview (Phase 1 Baseline)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildAdminMetric('Clients', 'Active', Icons.people_outline_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAdminMetric('Oduvars', 'Active', Icons.library_music_outlined),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              AppButton(
                label: 'Sign Out Admin',
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

  Widget _buildAdminMetric(String title, String status, IconData icon) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF334155), size: 26),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: const TextStyle(fontSize: 12, color: AppTheme.successGreen, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Sign Out'),
        content: const Text('Are you sure you want to end your administrative session?'),
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
