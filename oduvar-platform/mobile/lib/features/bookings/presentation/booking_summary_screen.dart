import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../data/booking_repository.dart';
import '../models/booking_model.dart';
import '../widgets/booking_summary.dart';
import 'booking_details_screen.dart';

/// Shown right after a request is sent: the booking is PENDING until the Oduvar responds.
class BookingSummaryScreen extends StatelessWidget {
  final BookingModel booking;
  final AuthState authState;
  final BookingRepository? bookingRepository;

  const BookingSummaryScreen({super.key, required this.booking, required this.authState, this.bookingRepository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sacredCream,
      appBar: AppBar(
        title: const Text('Request Sent'),
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.sacredSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            key: const Key('request_sent_banner'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.warningOrange.withAlpha(90)),
            ),
            child: Row(children: [
              const Icon(Icons.hourglass_top_rounded, color: AppTheme.warningOrange, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Booking request sent',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroonDark)),
                  const SizedBox(height: 4),
                  Text('Waiting for ${booking.oduvarName} to accept. You will be notified. Nothing is charged online.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E55))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          BookingSummary(
            oduvarName: booking.oduvarName,
            serviceName: booking.serviceName,
            date: booking.date,
            startTime: booking.startTime,
            durationMinutes: booking.durationMinutes,
            eventType: booking.eventType,
            location: booking.eventLocation,
            price: BookingPriceLines.fromBooking(booking),
            statusText: booking.status.label,
            timezoneNote: 'Times are in the Oduvar\'s local time (${booking.timezone}).',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('view_booking_button'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BookingDetailsScreen(
                bookingId: booking.id,
                initial: booking,
                viewer: BookingViewer.client,
                authState: authState,
                bookingRepository: bookingRepository,
              ),
            )),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMaroon, foregroundColor: Colors.white),
            child: const Text('View Booking'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('booking_done_button'),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}
