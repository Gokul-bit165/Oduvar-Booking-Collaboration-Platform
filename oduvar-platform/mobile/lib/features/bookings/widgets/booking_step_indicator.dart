import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../presentation/booking_flow_state.dart';

/// "Step 3 of 8 - Date" with a progress bar. Compact so it works on small screens.
class BookingStepIndicator extends StatelessWidget {
  final BookingStep current;

  const BookingStepIndicator({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final index = BookingStep.values.indexOf(current);
    final total = BookingStep.values.length;
    return Semantics(
      label: 'Step ${index + 1} of $total, ${bookingStepLabels[current]}',
      child: Column(
        key: const Key('booking_step_indicator'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Step ${index + 1} of $total',
                key: const Key('step_counter'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF9B8E84), fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(bookingStepLabels[current]!,
                  key: const Key('step_title'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroonDark)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: i <= index ? AppTheme.primaryMaroon : AppTheme.sacredBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}
