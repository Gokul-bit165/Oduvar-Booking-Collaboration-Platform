import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../models/availability_model.dart';
import 'availability_state.dart';
import 'block_date_screen.dart';
import 'widgets/availability_calendar.dart';
import 'widgets/availability_status_views.dart';

/// Blocked Dates & Times: date-specific overrides of the weekly schedule.
class BlockedDatesScreen extends StatefulWidget {
  final AvailabilityState availabilityState;
  final AuthState authState;

  const BlockedDatesScreen({
    super.key,
    required this.availabilityState,
    required this.authState,
  });

  @override
  State<BlockedDatesScreen> createState() => _BlockedDatesScreenState();
}

class _BlockedDatesScreenState extends State<BlockedDatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Overrides are already part of the loaded availability; only fetch if we have nothing yet.
      if (widget.availabilityState.status == AvailabilityStatus.initial) _load();
    });
  }

  Future<void> _load() async {
    final token = await widget.authState.getAccessToken();
    if (token != null) await widget.availabilityState.load(token: token);
  }

  Future<void> _openForm([AvailabilityOverrideModel? existing]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlockDateScreen(
          availabilityState: widget.availabilityState,
          authState: widget.authState,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _delete(AvailabilityOverrideModel o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove entry'),
        content: Text('Remove the entry for ${formatDateLong(o.date)}?'),
        actions: [
          TextButton(
              key: const Key('confirm_cancel'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            key: const Key('confirm_delete'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final token = await widget.authState.getAccessToken();
    if (token != null) await widget.availabilityState.deleteOverride(token, o.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.availabilityState,
      builder: (context, _) {
        final state = widget.availabilityState;
        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(
            title: const Text('Blocked Dates & Times'),
            backgroundColor: AppTheme.sacredSurface,
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_override_fab'),
            onPressed: () => _openForm(),
            backgroundColor: AppTheme.primaryMaroon,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Block Date/Time'),
          ),
          body: _body(state),
        );
      },
    );
  }

  Widget _body(AvailabilityState state) {
    final items = state.overrides;
    if (state.isLoading && items.isEmpty) return const AvailabilityLoadingView();
    if (state.status == AvailabilityStatus.error && items.isEmpty) {
      return AvailabilityErrorView(
        message: state.errorMessage ?? 'Failed to load',
        kind: state.errorKind,
        onRetry: _load,
      );
    }
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No blocked dates or special hours.\nYour weekly schedule applies every week.',
            key: Key('overrides_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF9B8E84)),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [for (final o in items) _card(o)],
    );
  }

  Widget _card(AvailabilityOverrideModel o) {
    final color = o.isAvailable ? AppTheme.successGreen : AppTheme.errorRed;
    final range = o.isAllDay ? 'all day' : '${formatTime12(o.startTime!)} – ${formatTime12(o.endTime!)}';
    final label = o.isAvailable ? 'Available $range' : 'Unavailable $range';
    return Container(
      key: Key('override_card_${o.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Row(
        children: [
          Icon(o.isAvailable ? Icons.check_circle_outline : Icons.block, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDateShort(o.date),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
                Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
                if (o.reason != null && o.reason!.isNotEmpty)
                  Text(o.reason!, style: const TextStyle(fontSize: 12, color: Color(0xFF9B8E84))),
              ],
            ),
          ),
          IconButton(
            key: Key('edit_override_${o.id}'),
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _openForm(o),
          ),
          IconButton(
            key: Key('delete_override_${o.id}'),
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
            onPressed: () => _delete(o),
          ),
        ],
      ),
    );
  }
}
