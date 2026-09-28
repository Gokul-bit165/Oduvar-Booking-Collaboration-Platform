import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_state.dart';
import '../presentation/oduvar_profile_state.dart';
import '../presentation/edit_oduvar_profile_screen.dart';
import '../presentation/oduvar_profile_view_screen.dart';
import '../models/oduvar_profile_model.dart';
import '../../services/presentation/oduvar_service_state.dart';
import '../../services/presentation/my_services_screen.dart';
import 'widgets/profile_widgets.dart';

class OduvarDashboardScreen extends StatefulWidget {
  final AuthState authState;

  const OduvarDashboardScreen({super.key, required this.authState});

  @override
  State<OduvarDashboardScreen> createState() => _OduvarDashboardScreenState();
}

class _OduvarDashboardScreenState extends State<OduvarDashboardScreen> {
  late final OduvarProfileState _profileState;

  @override
  void initState() {
    super.initState();
    _profileState = OduvarProfileState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final token = await widget.authState.getAccessToken();
    if (token != null) {
      await _profileState.loadMyProfile(token);
    }
  }

  @override
  void dispose() {
    _profileState.dispose();
    super.dispose();
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditOduvarProfileScreen(
          profileState: _profileState,
          authState: widget.authState,
        ),
      ),
    );
    // Refresh after returning from edit
    await _loadProfile();
  }

  Future<void> _logout() async {
    await widget.authState.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.authState, _profileState]),
      builder: (context, _) {
        final user = widget.authState.currentUser;

        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(
            title: const Text('Oduvar Portal'),
            backgroundColor: AppTheme.sacredSurface,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, size: 22),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadProfile,
            color: AppTheme.primaryMaroon,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Welcome Header ──────────────────────────────────────────
                _buildWelcomeCard(user?.name ?? 'Oduvar'),
                const SizedBox(height: 20),

                // ── Profile Completion / Setup ──────────────────────────────
                _buildProfileSection(),
                const SizedBox(height: 20),

                // ── Quick Actions ───────────────────────────────────────────
                _buildQuickActions(),
                const SizedBox(height: 20),

                // ── Future Phase Placeholders ───────────────────────────────
                _buildFuturePhasePlaceholders(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryMaroon, AppTheme.primaryMaroonLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryMaroon.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(30),
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'வணக்கம், $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Devotional Artist',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final profile = _profileState.profile;
    final status = _profileState.status;

    if (status == ProfileStatus.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppTheme.primaryMaroon),
        ),
      );
    }

    if (profile == null) {
      return _buildNoProfileCard();
    }

    return _buildProfileCard(profile);
  }

  Widget _buildNoProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.sacredSaffron.withAlpha(100), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.sacredSaffron.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_outlined,
                size: 36, color: AppTheme.sacredSaffron),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create Your Oduvar Profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryMaroonDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share your sacred music skills, instruments, and availability so clients can find and book you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF7A6A5E), height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('create_profile_button'),
              onPressed: _openEditProfile,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(OduvarProfileModel profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryMaroonDark,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: profile.isPublished
                      ? AppTheme.successGreen.withAlpha(20)
                      : const Color(0xFF9B8E84).withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  profile.isPublished ? '● Published' : '● Draft',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: profile.isPublished
                        ? AppTheme.successGreen
                        : const Color(0xFF9B8E84),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProfileCompletionBar(percentage: profile.completionPercentage),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('edit_profile_button'),
                  onPressed: _openEditProfile,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('view_profile_button'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OduvarProfileViewScreen(
                        profile: profile,
                        isPreviewMode: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.sacredSaffron,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _quickActionTile(
          icon: Icons.person_outlined,
          title: 'Manage Profile',
          subtitle: 'Update your details and availability',
          onTap: _openEditProfile,
        ),
        const SizedBox(height: 8),
        _quickActionTile(
          icon: Icons.photo_library_outlined,
          title: 'Gallery Photos',
          subtitle: 'Add or manage up to 5 gallery photos',
          onTap: _openEditProfile,
        ),
        const SizedBox(height: 8),
        _quickActionTile(
          icon: Icons.receipt_long_outlined,
          title: 'My Services & Pricing',
          subtitle: 'Define devotional services, durations and honorarium',
          onTap: _openMyServices,
        ),
      ],
    );
  }

  Future<void> _openMyServices() async {
    final serviceState = OduvarServiceState();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyServicesScreen(
          serviceState: serviceState,
          authState: widget.authState,
        ),
      ),
    );
  }

  Widget _buildFuturePhasePlaceholders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMING SOON',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9B8E84),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _placeholderTile(
            icon: Icons.calendar_month_outlined,
            title: 'Booking Requests',
            subtitle: 'View and manage booking requests'),
        const SizedBox(height: 8),
        _placeholderTile(
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            subtitle: 'Chat with clients and collaborators'),
        const SizedBox(height: 8),
        _placeholderTile(
            icon: Icons.handshake_outlined,
            title: 'Collaborations',
            subtitle: 'Collaborate with other Oduvars'),
        const SizedBox(height: 8),
        _placeholderTile(
            icon: Icons.star_outline,
            title: 'Reviews',
            subtitle: 'See what clients say about you'),
      ],
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.sacredBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryMaroon.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppTheme.primaryMaroon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9B8E84))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppTheme.sacredBorder),
          ],
        ),
      ),
    );
  }

  Widget _placeholderTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sacredBorder.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF9B8E84).withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFBBAEA4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFFBBAEA4))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFCDC5BC))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF9B8E84).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Phase 3+',
                style: TextStyle(fontSize: 10, color: Color(0xFFBBAEA4))),
          ),
        ],
      ),
    );
  }
}
