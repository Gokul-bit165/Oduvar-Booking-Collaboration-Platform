import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';

class DiscoveryEmptyState extends StatelessWidget {
  final bool hasActiveQuery;
  final VoidCallback? onClearFilters;

  const DiscoveryEmptyState({super.key, this.hasActiveQuery = true, this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('discovery_empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: AppTheme.primaryMaroon.withAlpha(20), shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, size: 40, color: AppTheme.primaryMaroon),
            ),
            const SizedBox(height: 18),
            const Text('No Oduvars found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
            const SizedBox(height: 8),
            Text(
              hasActiveQuery
                  ? 'Try changing your location or filters.'
                  : 'No Oduvars have published a profile yet. Please check back soon.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9B8E84)),
            ),
            if (onClearFilters != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('empty_clear_filters'),
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DiscoveryErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const DiscoveryErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('discovery_error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 12),
            const Text('Something went wrong',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E55))),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('discovery_retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMaroon, foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
