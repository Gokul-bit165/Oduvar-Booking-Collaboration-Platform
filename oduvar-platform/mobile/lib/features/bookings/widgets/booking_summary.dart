import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../models/booking_model.dart';

/// Price lines for a booking summary.
///
/// For a DRAFT (before submit) these are derived from the Oduvar's published service + price purely for
/// display; the server recomputes them when the request is submitted. For a SAVED booking they come from
/// the stored snapshot. Rules (same as the server):
///   INCLUDED / NOT_INCLUDED -> total = service amount
///   ADDITIONAL_FEE          -> total = service amount + fee
///   TO_BE_DISCUSSED         -> total "To Be Discussed" (no number is invented)
class BookingPriceLines {
  final String serviceAmount;
  final String transport;
  final String total;

  const BookingPriceLines({required this.serviceAmount, required this.transport, required this.total});

  factory BookingPriceLines.draft({required double serviceAmount, required String transport, double? transportFee}) {
    switch (transport) {
      case 'INCLUDED':
        return BookingPriceLines(serviceAmount: formatMoney(serviceAmount), transport: 'Included', total: formatMoney(serviceAmount));
      case 'NOT_INCLUDED':
        return BookingPriceLines(serviceAmount: formatMoney(serviceAmount), transport: 'Not Included', total: formatMoney(serviceAmount));
      case 'ADDITIONAL_FEE':
        if (transportFee != null) {
          return BookingPriceLines(
            serviceAmount: formatMoney(serviceAmount),
            transport: formatMoney(transportFee),
            total: formatMoney(serviceAmount + transportFee),
          );
        }
        return BookingPriceLines(serviceAmount: formatMoney(serviceAmount), transport: 'Additional Fee', total: 'To Be Discussed');
      default:
        return BookingPriceLines(serviceAmount: formatMoney(serviceAmount), transport: 'To Be Discussed', total: 'To Be Discussed');
    }
  }

  factory BookingPriceLines.fromBooking(BookingModel b) {
    final p = b.price;
    final serviceAmount = p.serviceAmount == null ? '-' : formatMoney(p.serviceAmount!);
    String transport;
    switch (b.transportOption) {
      case 'INCLUDED':
        transport = 'Included';
        break;
      case 'NOT_INCLUDED':
        transport = 'Not Included';
        break;
      case 'ADDITIONAL_FEE':
        transport = p.transportFee != null ? formatMoney(p.transportFee!) : 'Additional Fee';
        break;
      default:
        transport = 'To Be Discussed';
    }
    return BookingPriceLines(serviceAmount: serviceAmount, transport: transport, total: p.totalLabel);
  }
}

/// Reusable "Booking Summary" card used on the review step and (with [status]) on the confirmation screen.
class BookingSummary extends StatelessWidget {
  final String oduvarName;
  final String serviceName;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final int durationMinutes;
  final String eventType; // key
  final String location;
  final BookingPriceLines price;
  final String statusText;
  final String? timezoneNote;

  const BookingSummary({
    super.key,
    required this.oduvarName,
    required this.serviceName,
    required this.date,
    required this.startTime,
    required this.durationMinutes,
    required this.eventType,
    required this.location,
    required this.price,
    this.statusText = 'Ready to Send',
    this.timezoneNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('booking_summary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking Summary',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroonDark)),
          const SizedBox(height: 12),
          _row('Oduvar', oduvarName),
          _row('Service', serviceName),
          _row('Date', formatBookingDate(date)),
          _row('Time', formatBookingTime(startTime)),
          _row('Duration', bookingDurationLabel(durationMinutes)),
          _row('Event', eventTypeLabel(eventType)),
          _row('Location', location),
          if (timezoneNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(timezoneNote!, style: const TextStyle(fontSize: 11, color: Color(0xFF9B8E84))),
            ),
          const Divider(height: 24, color: AppTheme.sacredBorder),
          _row('Service Amount', price.serviceAmount, key: const Key('sum_service_amount')),
          _row('Transport', price.transport, key: const Key('sum_transport')),
          const Divider(height: 24, color: AppTheme.sacredBorder),
          _row('Total', price.total, key: const Key('sum_total'), bold: true),
          const SizedBox(height: 8),
          _row('Status', statusText, key: const Key('sum_status')),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Key? key, bool bold = false}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF9B8E84)))),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: bold ? 16 : 14,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: AppTheme.primaryMaroonDark,
                  )),
            ),
          ],
        ),
      );
}
