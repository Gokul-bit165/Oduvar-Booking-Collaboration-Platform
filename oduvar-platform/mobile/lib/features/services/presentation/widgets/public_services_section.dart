import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../../models/service_model.dart';

class PublicServicesSection extends StatelessWidget {
  final List<OduvarServiceModel> services;

  const PublicServicesSection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final activeList = services.where((s) => s.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryMaroon.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.temple_hindu_outlined,
                color: AppTheme.primaryMaroon,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Services & Pricing',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryMaroonDark,
                  ),
                ),
                Text(
                  'Offerings and devotional recital options',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9B8E84)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (activeList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.sacredBorder),
            ),
            child: const Center(
              child: Text(
                'Services are currently being configured.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9B8E84)),
              ),
            ),
          )
        else
          ...activeList.map((service) => _buildServiceCard(service)),
      ],
    );
  }

  Widget _buildServiceCard(OduvarServiceModel service) {
    final activePricings = service.pricings.where((p) => p.isActive).toList();

    return Container(
      key: Key('public_service_card_${service.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name and Category badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryMaroonDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.sacredSaffron.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  service.category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.sacredGold,
                  ),
                ),
              ),
            ],
          ),

          // Description
          if ((service.customDescription ?? service.baseDescription) != null) ...[
            const SizedBox(height: 8),
            Text(
              service.customDescription ?? service.baseDescription!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E55)),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(color: AppTheme.sacredBorder, height: 1),
          const SizedBox(height: 12),

          // Duration & Pricing list
          const Text(
            'Duration & Honorarium',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 8),
          if (activePricings.isEmpty)
            const Text(
              'Pricing details available upon request.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9B8E84)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activePricings.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.sacredCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.sacredBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: AppTheme.primaryMaroon.withAlpha(180)),
                      const SizedBox(width: 6),
                      Text(
                        p.durationLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p.formattedAmount,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryMaroonDark,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 12),

          // Transport information
          Row(
            children: [
              const Icon(Icons.directions_car_outlined, size: 14, color: Color(0xFF9B8E84)),
              const SizedBox(width: 6),
              Text(
                'Transport: ${service.transportDisplay}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B5E55),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
