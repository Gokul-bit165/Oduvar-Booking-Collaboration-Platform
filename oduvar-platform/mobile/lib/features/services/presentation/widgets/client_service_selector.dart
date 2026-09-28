import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../../models/service_model.dart';
import 'price_summary_widget.dart';

class ClientServiceSelector extends StatefulWidget {
  final List<OduvarServiceModel> services;
  final OduvarServiceModel? initialService;
  final PricingModel? initialPricing;
  final void Function(OduvarServiceModel service, PricingModel pricing)? onSelected;

  const ClientServiceSelector({
    super.key,
    required this.services,
    this.initialService,
    this.initialPricing,
    this.onSelected,
  });

  @override
  State<ClientServiceSelector> createState() => _ClientServiceSelectorState();
}

class _ClientServiceSelectorState extends State<ClientServiceSelector> {
  OduvarServiceModel? _selectedService;
  PricingModel? _selectedPricing;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService;
    _selectedPricing = widget.initialPricing;
  }

  void _onServicePicked(OduvarServiceModel service) {
    setState(() {
      _selectedService = service;
      _selectedPricing = null; // Reset duration when service changes
    });
  }

  void _onPricingPicked(PricingModel pricing) {
    setState(() {
      _selectedPricing = pricing;
    });
    if (_selectedService != null && widget.onSelected != null) {
      widget.onSelected!(_selectedService!, pricing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableServices = widget.services.where((s) => s.isActive).toList();

    if (availableServices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sacredBorder),
        ),
        child: const Center(
          child: Text(
            'No services currently available from this Oduvar.',
            style: TextStyle(color: Color(0xFF9B8E84), fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Step 1: Select Service ──────────────────────────────────────────
        const Text(
          'Select Service',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryMaroonDark,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: availableServices.map((service) {
            final isSelected = _selectedService?.id == service.id;
            return ChoiceChip(
              key: Key('service_chip_${service.id}'),
              label: Text(service.name),
              selected: isSelected,
              onSelected: (_) => _onServicePicked(service),
              selectedColor: AppTheme.primaryMaroon,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.primaryMaroonDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryMaroon : AppTheme.sacredBorder,
              ),
            );
          }).toList(),
        ),

        // ─── Step 2: Select Duration ─────────────────────────────────────────
        if (_selectedService != null) ...[
          const SizedBox(height: 20),
          const Text(
            'Select Duration',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryMaroonDark,
            ),
          ),
          const SizedBox(height: 10),
          if (_selectedService!.pricings.isEmpty)
            const Text(
              'No pricing configured for this service.',
              style: TextStyle(color: Color(0xFF9B8E84), fontSize: 13),
            )
          else
            Column(
              children: _selectedService!.pricings.where((p) => p.isActive).map((pricing) {
                final isSelected = _selectedPricing?.id == pricing.id;
                return Container(
                  key: Key('pricing_option_${pricing.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _onPricingPicked(pricing),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryMaroon.withAlpha(12) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryMaroon : AppTheme.sacredBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 20,
                                color: isSelected ? AppTheme.primaryMaroon : const Color(0xFF9B8E84),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                pricing.durationLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: const Color(0xFF1F1B18),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            pricing.formattedAmount,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppTheme.primaryMaroon : const Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],

        // ─── Step 3: Pricing Summary ─────────────────────────────────────────
        if (_selectedService != null && _selectedPricing != null) ...[
          const SizedBox(height: 24),
          PriceSummaryWidget(
            serviceName: _selectedService!.name,
            durationLabel: _selectedPricing!.durationLabel,
            serviceAmount: _selectedPricing!.amount,
            transport: _selectedService!.transport,
            transportFee: _selectedService!.transportFee,
          ),
        ],
      ],
    );
  }
}
