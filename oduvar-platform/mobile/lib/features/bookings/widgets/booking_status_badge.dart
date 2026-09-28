import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../models/booking_model.dart';

/// Status pill: colour + icon + text (never colour alone).
class BookingStatusBadge extends StatelessWidget {
  final BookingStatus status;

  const BookingStatusBadge({super.key, required this.status});

  ({Color color, IconData icon}) get _style {
    switch (status) {
      case BookingStatus.pending:
        return (color: AppTheme.warningOrange, icon: Icons.hourglass_top_rounded);
      case BookingStatus.confirmed:
        return (color: AppTheme.successGreen, icon: Icons.check_circle_outline);
      case BookingStatus.rejected:
        return (color: AppTheme.errorRed, icon: Icons.cancel_outlined);
      case BookingStatus.cancelled:
        return (color: const Color(0xFF6B5E55), icon: Icons.block);
      case BookingStatus.completed:
        return (color: AppTheme.infoBlue, icon: Icons.task_alt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      key: Key('status_badge_${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.color.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.color.withAlpha(90)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: 14, color: s.color),
        const SizedBox(width: 4),
        Text(status.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.color)),
      ]),
    );
  }
}
