import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../models/booking_model.dart';
import 'booking_status_badge.dart';

/// Booking list card. [showClient] switches the headline from the Oduvar to the client (Oduvar view).
/// Amounts come from the booking's price snapshot.
class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool showClient;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool busy;

  const BookingCard({
    super.key,
    required this.booking,
    this.showClient = false,
    this.onTap,
    this.onAccept,
    this.onReject,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      key: Key('booking_card_${b.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Column(
        children: [
          InkWell(
            key: Key('booking_open_${b.id}'),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(showClient ? b.clientName : b.oduvarName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroonDark)),
                    ),
                    BookingStatusBadge(status: b.status),
                  ]),
                  const SizedBox(height: 6),
                  Text(b.serviceName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.sandalWood)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    _info(Icons.calendar_today_outlined, formatBookingDate(b.date)),
                    _info(Icons.schedule, formatBookingTime(b.startTime)),
                    _info(Icons.timelapse, bookingDurationLabel(b.durationMinutes)),
                    if (showClient) _info(Icons.temple_hindu_outlined, eventTypeLabel(b.eventType)),
                  ]),
                  if (showClient && b.eventLocation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _info(Icons.location_on_outlined, b.eventLocation),
                  ],
                  const SizedBox(height: 8),
                  Text(b.price.totalLabel,
                      key: Key('booking_amount_${b.id}'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroon)),
                ],
              ),
            ),
          ),
          if (onAccept != null || onReject != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('reject_${b.id}'),
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed, side: const BorderSide(color: AppTheme.errorRed)),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    key: Key('accept_${b.id}'),
                    onPressed: busy ? null : onAccept,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
                    child: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Accept'),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: const Color(0xFF9B8E84)),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55)))),
      ]);
}
