import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';

class PriceSummaryWidget extends StatelessWidget {
  final String serviceName;
  final String durationLabel;
  final double serviceAmount;
  final String transport;
  final double? transportFee;
  final String currency;

  const PriceSummaryWidget({
    super.key,
    required this.serviceName,
    required this.durationLabel,
    required this.serviceAmount,
    required this.transport,
    this.transportFee,
    this.currency = 'INR',
  });

  String _formatCurrency(double val) {
    final isInt = val == val.roundToDouble();
    final valueStr = isInt ? val.toInt().toString() : val.toStringAsFixed(2);
    final parts = valueStr.split('.');
    final whole = parts[0];
    final reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$formattedWhole';
  }

  String get transportText {
    switch (transport) {
      case 'INCLUDED':
        return 'Included';
      case 'NOT_INCLUDED':
        return 'Not Included';
      case 'ADDITIONAL_FEE':
        if (transportFee != null && transportFee! > 0) {
          return _formatCurrency(transportFee!);
        }
        return 'Additional Fee';
      case 'TO_BE_DISCUSSED':
      default:
        return 'To Be Discussed';
    }
  }

  String get totalText {
    if (transport == 'TO_BE_DISCUSSED') {
      return 'To Be Discussed';
    }
    double total = serviceAmount;
    if (transport == 'ADDITIONAL_FEE' && transportFee != null && transportFee! > 0) {
      total += transportFee!;
    }
    return _formatCurrency(total);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryMaroon.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppTheme.primaryMaroon,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryMaroonDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      durationLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF78350F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.sacredBorder),
          const SizedBox(height: 12),

          // Line items
          _buildLineItem('Service Amount', _formatCurrency(serviceAmount)),
          const SizedBox(height: 8),
          _buildLineItem('Transport', transportText),

          const SizedBox(height: 12),
          const Divider(color: AppTheme.sacredBorder),
          const SizedBox(height: 12),

          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryMaroonDark,
                ),
              ),
              Text(
                totalText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: transport == 'TO_BE_DISCUSSED'
                      ? AppTheme.sacredSaffron
                      : AppTheme.primaryMaroon,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B5E55),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F1B18),
          ),
        ),
      ],
    );
  }
}
