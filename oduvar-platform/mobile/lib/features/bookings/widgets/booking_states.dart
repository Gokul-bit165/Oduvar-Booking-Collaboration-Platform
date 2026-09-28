import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../presentation/booking_state.dart';

/// Loading / error / unauthorized / empty views shared by the booking screens.
class BookingLoadingView extends StatelessWidget {
  const BookingLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(key: Key('bookings_loading'), color: AppTheme.primaryMaroon),
      );
}

class BookingErrorView extends StatelessWidget {
  final String message;
  final BookingErrorKind kind;
  final VoidCallback onRetry;

  const BookingErrorView({super.key, required this.message, required this.kind, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (kind == BookingErrorKind.unauthorized) {
      return Center(
        key: const Key('bookings_unauthorized'),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 12),
            const Text('Not authorised',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E55))),
            const SizedBox(height: 4),
            const Text('Please sign in again with the right account.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF9B8E84))),
          ]),
        ),
      );
    }
    return Center(
      key: const Key('bookings_error'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(kind == BookingErrorKind.network ? Icons.wifi_off : Icons.error_outline, size: 48, color: AppTheme.errorRed),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF6B5E55))),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('bookings_retry'),
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMaroon, foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}

class BookingEmptyView extends StatelessWidget {
  final String title;
  final String subtitle;

  const BookingEmptyView({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        key: const Key('bookings_empty'),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppTheme.primaryMaroon.withAlpha(20), shape: BoxShape.circle),
              child: const Icon(Icons.event_note_outlined, size: 36, color: AppTheme.primaryMaroon),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF9B8E84))),
          ]),
        ),
      );
}

/// Inline banner for action failures (e.g. "This time is no longer available").
class BookingErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const BookingErrorBanner({super.key, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('booking_error_banner'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorRed.withAlpha(80)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 18, color: AppTheme.errorRed),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppTheme.errorRed))),
          if (onDismiss != null)
            IconButton(
                key: const Key('booking_error_dismiss'),
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss),
        ]),
      );
}
