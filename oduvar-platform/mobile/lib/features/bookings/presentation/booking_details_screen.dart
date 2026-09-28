import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../data/booking_repository.dart';
import '../models/booking_model.dart';
import '../widgets/booking_states.dart';
import '../widgets/booking_status_badge.dart';
import '../widgets/booking_summary.dart';
import 'booking_state.dart';

enum BookingViewer { client, oduvar }

/// Reusable booking details for both participants.
///
/// Money and service name come from the booking's stored snapshot. Contact numbers are only ever present
/// because the API returns them to the booking's own client / Oduvar. [extraActions] is where a future
/// "Message" action plugs in (messaging is not implemented in this phase).
class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  final BookingModel? initial;
  final BookingViewer viewer;
  final AuthState authState;
  final BookingState? state;
  final BookingRepository? bookingRepository;
  final List<Widget> extraActions;

  const BookingDetailsScreen({
    super.key,
    required this.bookingId,
    this.initial,
    required this.viewer,
    required this.authState,
    this.state,
    this.bookingRepository,
    this.extraActions = const [],
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  late final BookingState _state;
  late final bool _ownsState;
  bool _loaded = false;

  bool get _asOduvar => widget.viewer == BookingViewer.oduvar;

  @override
  void initState() {
    super.initState();
    _ownsState = widget.state == null;
    _state = widget.state ?? BookingState(repository: widget.bookingRepository);
    if (widget.initial != null) _state.seed(widget.initial!); // no notification during initState
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await _state.refreshOne(token, widget.bookingId, asOduvar: _asOduvar);
    if (mounted) setState(() => _loaded = true);
  }

  BookingModel? get _booking {
    for (final b in _state.items) {
      if (b.id == widget.bookingId) return b;
    }
    return widget.initial;
  }

  Future<void> _run(Future<BookingModel?> Function(String token) op) async {
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await op(token);
  }

  Future<String?> _askReason(String title, String hint) async {
    final c = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(key: const Key('reason_field'), controller: c, maxLength: 500, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(key: const Key('dialog_cancel'), onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          TextButton(key: const Key('dialog_confirm'), onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final b = _booking;
        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(title: const Text('Booking Details'), backgroundColor: AppTheme.sacredSurface),
          body: b == null ? _empty() : _content(b),
        );
      },
    );
  }

  Widget _empty() {
    if (_state.errorMessage != null) {
      return BookingErrorView(message: _state.errorMessage!, kind: _state.errorKind, onRetry: _refresh);
    }
    return const BookingLoadingView();
  }

  Widget _content(BookingModel b) {
    final busy = _state.busyId == b.id;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const Key('booking_details_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_state.errorMessage != null && _loaded || (_state.errorMessage != null && _state.errorKind != BookingErrorKind.none && _booking != null))
            BookingErrorBanner(message: _state.errorMessage!, onDismiss: _state.clearError),
          Row(children: [
            Expanded(
              child: Text(b.serviceName,
                  key: const Key('details_service'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroonDark)),
            ),
            BookingStatusBadge(status: b.status),
          ]),
          if (b.statusReason != null && b.statusReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Reason: ${b.statusReason}', key: const Key('details_reason'), style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E55))),
            ),
          const SizedBox(height: 14),
          _section('People', [
            _row('Oduvar', b.oduvarName),
            if (_asOduvar) ...[
              _row('Client', b.clientName),
              _row('Phone', b.phone1, key: const Key('details_phone1')),
              if (b.phone2 != null && b.phone2!.isNotEmpty) _row('Alternate phone', b.phone2!, key: const Key('details_phone2')),
            ] else ...[
              _row('Your phone', b.phone1, key: const Key('details_phone1')),
              if (b.phone2 != null && b.phone2!.isNotEmpty) _row('Alternate phone', b.phone2!, key: const Key('details_phone2')),
            ],
          ]),
          _section('When', [
            _row('Date', formatBookingDate(b.date)),
            _row('Start time', formatBookingTime(b.startTime)),
            if (b.endTime != null) _row('End time', formatBookingTime(b.endTime!)),
            _row('Duration', bookingDurationLabel(b.durationMinutes)),
            _row('Timezone', b.timezone),
          ]),
          _section('Event', [
            _row('Event type', eventTypeLabel(b.eventType)),
            if (b.songType.isNotEmpty) _row('Song / service', b.songType),
            _row('Location', b.eventLocation, key: const Key('details_location')),
            _row('Details', b.description, key: const Key('details_description')),
          ]),
          _section('Price', [
            ..._priceRows(b),
          ]),
          const SizedBox(height: 4),
          ..._actions(b, busy),
          ...widget.extraActions, // future: Message
        ],
      ),
    );
  }

  List<Widget> _priceRows(BookingModel b) {
    final lines = BookingPriceLines.fromBooking(b);
    return [
      _row('Service Amount', lines.serviceAmount, key: const Key('details_service_amount')),
      _row('Transport', lines.transport, key: const Key('details_transport')),
      _row('Total', lines.total, key: const Key('details_total'), bold: true),
    ];
  }

  List<Widget> _actions(BookingModel b, bool busy) {
    final widgets = <Widget>[];
    if (_asOduvar) {
      if (b.status == BookingStatus.pending) {
        widgets.add(Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('details_reject'),
              onPressed: busy ? null : () async {
                final reason = await _askReason('Reject this request?', 'Reason (optional)');
                if (reason == null) return;
                await _run((t) => _state.reject(t, b.id, reason: reason));
              },
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed, side: const BorderSide(color: AppTheme.errorRed)),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              key: const Key('details_accept'),
              onPressed: busy ? null : () => _run((t) => _state.accept(t, b.id)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
              child: const Text('Accept'),
            ),
          ),
        ]));
      } else if (b.status == BookingStatus.confirmed) {
        widgets.add(ElevatedButton(
          key: const Key('details_complete'),
          onPressed: busy ? null : () => _run((t) => _state.complete(t, b.id)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.infoBlue, foregroundColor: Colors.white),
          child: const Text('Mark as Completed'),
        ));
      }
    } else if (b.canBeCancelledByClient) {
      widgets.add(OutlinedButton(
        key: const Key('details_cancel'),
        onPressed: busy ? null : () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cancel this booking?'),
              content: Text(b.status == BookingStatus.confirmed
                  ? 'A confirmed booking can only be cancelled more than 24 hours before it starts.'
                  : 'Your request will be withdrawn.'),
              actions: [
                TextButton(key: const Key('cancel_no'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep booking')),
                TextButton(key: const Key('cancel_yes'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel booking')),
              ],
            ),
          );
          if (ok == true) await _run((t) => _state.cancel(t, b.id));
        },
        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed, side: const BorderSide(color: AppTheme.errorRed)),
        child: const Text('Cancel Booking'),
      ));
    }
    if (busy) widgets.add(const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()));
    return widgets;
  }

  Widget _section(String title, List<Widget> rows) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.sacredBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.sacredSaffron, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          ...rows,
        ]),
      );

  Widget _row(String label, String value, {Key? key, bool bold = false}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 118, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF9B8E84)))),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: AppTheme.primaryMaroonDark)),
          ),
        ]),
      );
}
