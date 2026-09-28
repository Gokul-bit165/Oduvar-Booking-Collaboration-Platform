import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../availability_state.dart';

class AvailabilityLoadingView extends StatelessWidget {
  const AvailabilityLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(key: Key('availability_loading'), color: AppTheme.primaryMaroon),
      );
}

class AvailabilityErrorView extends StatelessWidget {
  final String message;
  final AvailabilityErrorKind kind;
  final VoidCallback onRetry;

  const AvailabilityErrorView({
    super.key,
    required this.message,
    required this.kind,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final icon = kind == AvailabilityErrorKind.network
        ? Icons.wifi_off
        : kind == AvailabilityErrorKind.unauthorized
            ? Icons.lock_outline
            : Icons.error_outline;
    return Center(
      key: const Key('availability_error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B5E55))),
            if (kind != AvailabilityErrorKind.unauthorized) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('availability_retry'),
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryMaroon, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
