import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/services/models/service_model.dart';
import 'package:oduvar_mobile/features/services/presentation/widgets/public_services_section.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/bookings/data/booking_repository.dart';
import 'package:oduvar_mobile/features/bookings/presentation/booking_flow_screen.dart';
import 'package:oduvar_mobile/features/availability/presentation/availability_state.dart';
import 'package:oduvar_mobile/features/availability/presentation/public_availability_screen.dart';
import '../models/oduvar_profile_model.dart';
import 'widgets/profile_widgets.dart';

/// Public Oduvar profile view — shown to Clients and in preview mode.
class OduvarProfileViewScreen extends StatelessWidget {
  final OduvarProfileModel profile;
  final bool isPreviewMode;
  final List<OduvarServiceModel>? services;

  /// User id of the Oduvar (public availability is keyed by it). Enables the availability button.
  final String? oduvarUserId;

  /// Injectable for tests; defaults to the real API.
  final AvailabilityRepository? availabilityRepository;

  /// Needed to start a booking (the signed-in client). Without it the booking button explains why it is unavailable.
  final AuthState? authState;
  final BookingRepository? bookingRepository;

  const OduvarProfileViewScreen({
    super.key,
    required this.profile,
    this.isPreviewMode = false,
    this.services,
    this.oduvarUserId,
    this.availabilityRepository,
    this.authState,
    this.bookingRepository,
  });

  static String _eventLabel(String key) => key
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');

  void _startBooking(BuildContext context) {
    if (authState == null || oduvarUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in as a client to request a booking.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          oduvarId: oduvarUserId!,
          oduvarName: profile.owner.name,
          services: services ?? const [],
          authState: authState!,
          bookingRepository: bookingRepository,
          availabilityRepository: availabilityRepository,
        ),
      ),
    );
  }

  Widget _buildAvailabilityButton(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('view_availability_button'),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicAvailabilityScreen(
            oduvarId: oduvarUserId!,
            availabilityState: AvailabilityState(repository: availabilityRepository),
          ),
        ),
      ),
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: const Text('View Availability Calendar'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sacredCream,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPreviewMode) _buildPreviewBanner(context),
                  _buildOwnerHeader(),
                  const SizedBox(height: 20),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    _buildSection('About', _buildBio()),
                    const SizedBox(height: 20),
                  ],
                  if (profile.skills.isNotEmpty) ...[
                    _buildSection('Good At', _buildChips(
                      profile.skills.map((s) => s.name).toList(),
                      AppTheme.primaryMaroon,
                    )),
                    const SizedBox(height: 20),
                  ],
                  if (profile.performanceTypes.isNotEmpty) ...[
                    _buildSection('Performance', _buildChips(
                      profile.performanceTypes
                          .map((p) => p[0] + p.substring(1).toLowerCase())
                          .toList(),
                      AppTheme.sacredSaffron,
                    )),
                    const SizedBox(height: 20),
                  ],
                  if (profile.songCategories.isNotEmpty) ...[
                    _buildSection('Sacred Songs', _buildChips(
                      profile.songCategories
                          .map((s) => _songLabel(s))
                          .toList(),
                      AppTheme.sandalWood,
                    )),
                    const SizedBox(height: 20),
                  ],
                  if (profile.instruments.isNotEmpty) ...[
                    _buildSection('Instruments', _buildChips(
                      profile.instruments.map((i) => i.name).toList(),
                      const Color(0xFF1B6B5A),
                    )),
                    const SizedBox(height: 20),
                  ],
                  if (profile.photos.isNotEmpty) ...[
                    _buildSection('Gallery', _buildGallery()),
                    const SizedBox(height: 20),
                  ],
                  if (profile.eventTypes.isNotEmpty) ...[
                    _buildSection('Events Served', _buildChips(
                      profile.eventTypes.map(_eventLabel).toList(),
                      const Color(0xFF7C3AED),
                    )),
                    const SizedBox(height: 20),
                  ],
                  _buildSection('Transport', _buildTransportInfo()),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Collaboration',
                    _buildCollaborationInfo(),
                  ),
                  const SizedBox(height: 20),
                  if (services != null && services!.isNotEmpty) ...[
                    PublicServicesSection(services: services!),
                    const SizedBox(height: 20),
                  ],
                  if (oduvarUserId != null) ...[
                    _buildSection('Availability', _buildAvailabilityButton(context)),
                    const SizedBox(height: 20),
                  ],
                  const SizedBox(height: 12),
                  if (!isPreviewMode) _buildActionButtons(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.sacredSurface,
      foregroundColor: AppTheme.primaryMaroon,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFAF0E8),
                    Color(0xFFF3E5D0),
                  ],
                ),
              ),
            ),
            // Decorative pattern
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryMaroon.withAlpha(12),
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: 20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.sacredSaffron.withAlpha(20),
                ),
              ),
            ),
            // Profile photo
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  _buildProfilePhotoLarge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoLarge() {
    final photoUrl = profile.owner.profilePhoto;
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryMaroon.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl != null
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _avatarPlaceholder(),
                errorWidget: (_, __, ___) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    final initials = profile.owner.name.isNotEmpty
        ? profile.owner.name[0].toUpperCase()
        : 'O';
    return Container(
      color: AppTheme.primaryMaroon,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.sacredSaffron.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sacredSaffron.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              size: 18, color: AppTheme.sacredSaffron),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Preview Mode — This is how your profile appears publicly',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.sandalWood,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.owner.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryMaroonDark,
            letterSpacing: -0.3,
          ),
        ),
        if (profile.location != null && profile.location!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppTheme.sacredSaffron),
              const SizedBox(width: 4),
              Text(
                profile.location!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7A6A5E),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBio() {
    return Text(
      profile.bio!,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF4A3F38),
        height: 1.6,
      ),
    );
  }

  Widget _buildChips(List<String> items, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildGallery() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profile.photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final photo = profile.photos[index];
          return GestureDetector(
            onTap: () => _showPhotoDialog(context, photo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: photo.imageUrl,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 120,
                  height: 120,
                  color: AppTheme.sacredBorder,
                  child: const Icon(Icons.image_outlined,
                      color: AppTheme.sacredSaffron),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  color: AppTheme.sacredBorder,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppTheme.sacredBorder),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPhotoDialog(BuildContext context, OduvarPhotoModel photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CachedNetworkImage(
            imageUrl: photo.imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const AspectRatio(
              aspectRatio: 1,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportInfo() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryMaroon.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.directions_car_outlined,
              size: 18, color: AppTheme.primaryMaroon),
        ),
        const SizedBox(width: 12),
        Text(
          transportLabel(profile.transport),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4A3F38),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCollaborationInfo() {
    final available = profile.collaborationEnabled;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (available ? AppTheme.successGreen : const Color(0xFF9B8E84))
                .withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            available ? Icons.handshake_outlined : Icons.block_outlined,
            size: 18,
            color: available
                ? AppTheme.successGreen
                : const Color(0xFF9B8E84),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          available
              ? 'Open to Collaboration'
              : 'Not Available for Collaboration',
          style: TextStyle(
            fontSize: 14,
            color: available
                ? AppTheme.successGreen
                : const Color(0xFF9B8E84),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: AppTheme.sacredBorder),
        const SizedBox(height: 16),
        const Text(
          'Take Action',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B8E84),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          key: const Key('request_to_book_btn'),
          onPressed: () => _startBooking(context),
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('Request to Book'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PlaceholderActionButton(
                label: 'Message',
                icon: Icons.chat_bubble_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PlaceholderActionButton(
                label: 'Invite to Collaborate',
                icon: Icons.handshake_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.sacredSaffron,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  String _songLabel(String key) {
    switch (key) {
      case 'THEVARAM':
        return 'Thevaram';
      case 'THIRUVASAGAM':
        return 'Thiruvasagam';
      case 'THIRUPUGAZH':
        return 'Thirupugazh';
      default:
        return 'Other';
    }
  }
}
