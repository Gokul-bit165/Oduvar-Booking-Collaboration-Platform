import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../../models/discovery_model.dart';

/// Reusable Oduvar search-result card. Shows only public-safe data.
class OduvarCard extends StatelessWidget {
  final OduvarDiscoveryModel oduvar;
  final VoidCallback onViewProfile;

  /// How many "Good At" tags to show before collapsing into "+N".
  final int maxSkillTags;

  const OduvarCard({
    super.key,
    required this.oduvar,
    required this.onViewProfile,
    this.maxSkillTags = 3,
  });

  @override
  Widget build(BuildContext context) {
    final o = oduvar;
    final skills = o.skills.map((s) => s.name).toList();
    final shownSkills = skills.take(maxSkillTags).toList();
    final extra = skills.length - shownSkills.length;
    final categories = o.serviceCategories;

    return Container(
      key: Key('oduvar_card_${o.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
                    if (o.location != null && o.location!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF9B8E84)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(o.location!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E55))),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 4),
                    _rating(),
                  ],
                ),
              ),
            ],
          ),
          if (shownSkills.isNotEmpty || o.performanceTypes.isNotEmpty || categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in shownSkills) _chip(s, AppTheme.primaryMaroon),
                if (extra > 0) _chip('+$extra', const Color(0xFF9B8E84)),
                for (final p in o.performanceTypes) _chip(performanceLabel(p), AppTheme.sacredSaffron),
                for (final c in categories) _chip(c, AppTheme.sandalWood, icon: Icons.music_note),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _info(Icons.directions_car_outlined, 'Transport: ${transportLabel(o.transport)}',
                  key: Key('transport_${o.id}')),
              if (o.collaborationEnabled)
                _info(Icons.handshake_outlined, 'Open to collaboration', key: Key('collab_${o.id}')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: Key('view_profile_${o.id}'),
              onPressed: onViewProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryMaroon,
                side: const BorderSide(color: AppTheme.primaryMaroon),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final initial = oduvar.name.isEmpty ? '?' : oduvar.name.trim()[0].toUpperCase();
    final placeholder = Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      color: AppTheme.primaryMaroon.withAlpha(25),
      child: Text(initial,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroon)),
    );
    return ClipRRect(
      key: Key('avatar_${oduvar.id}'),
      borderRadius: BorderRadius.circular(30),
      child: oduvar.profilePhoto == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: oduvar.profilePhoto!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }

  /// Real rating when reviews exist; otherwise "No reviews yet" (never 0 stars).
  Widget _rating() {
    if (oduvar.rating == null || oduvar.reviewCount == 0) {
      return Text('No reviews yet',
          key: Key('rating_${oduvar.id}'),
          style: const TextStyle(fontSize: 12, color: Color(0xFF9B8E84), fontStyle: FontStyle.italic));
    }
    return Row(
      key: Key('rating_${oduvar.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: AppTheme.divineAmber),
        const SizedBox(width: 2),
        Text('${oduvar.rating!.toStringAsFixed(1)} (${oduvar.reviewCount})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B5E55))),
      ],
    );
  }

  Widget _chip(String label, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      );

  Widget _info(IconData icon, String text, {Key? key}) => Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9B8E84)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55))),
        ],
      );
}

/// Placeholder shown while a page of results is loading.
class OduvarCardSkeleton extends StatelessWidget {
  const OduvarCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: const Color(0xFFEFE8DD), borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      key: const Key('oduvar_card_skeleton'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(color: Color(0xFFEFE8DD), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              bar(150, 16),
              const SizedBox(height: 8),
              bar(90, 12),
              const SizedBox(height: 8),
              bar(70, 10),
            ]),
          ]),
          const SizedBox(height: 14),
          Row(children: [bar(70, 22), const SizedBox(width: 6), bar(60, 22), const SizedBox(width: 6), bar(80, 22)]),
          const SizedBox(height: 14),
          bar(double.infinity, 40),
        ],
      ),
    );
  }
}
