import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../data/booking_repository.dart';
import '../models/booking_model.dart';
import '../widgets/booking_card.dart';
import '../widgets/booking_states.dart';
import 'booking_details_screen.dart';
import 'booking_state.dart';
import 'client_bookings_screen.dart' show todayKey;

/// Oduvar view: Pending Requests (accept / reject), Today's Bookings, Upcoming Confirmed.
class OduvarBookingRequestsScreen extends StatefulWidget {
  final AuthState authState;
  final BookingState? state;
  final BookingRepository? bookingRepository;
  final String? today;

  const OduvarBookingRequestsScreen({super.key, required this.authState, this.state, this.bookingRepository, this.today});

  @override
  State<OduvarBookingRequestsScreen> createState() => _OduvarBookingRequestsScreenState();
}

class _OduvarBookingRequestsScreenState extends State<OduvarBookingRequestsScreen> {
  late final BookingState _state;
  late final bool _ownsState;

  String get _today => widget.today ?? todayKey();

  @override
  void initState() {
    super.initState();
    _ownsState = widget.state == null;
    _state = widget.state ?? BookingState(repository: widget.bookingRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await _state.loadForOduvar(token);
  }

  Future<void> _accept(BookingModel b) async {
    final token = await widget.authState.getAccessToken();
    if (token != null) await _state.accept(token, b.id);
  }

  Future<void> _reject(BookingModel b) async {
    final token = await widget.authState.getAccessToken();
    if (token != null) await _state.reject(token, b.id);
  }

  void _open(BookingModel b) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(
          bookingId: b.id,
          initial: b,
          viewer: BookingViewer.oduvar,
          authState: widget.authState,
          state: _state,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.sacredCream,
        appBar: AppBar(title: const Text('Booking Requests'), backgroundColor: AppTheme.sacredSurface),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_state.isLoading && _state.items.isEmpty) return const BookingLoadingView();
    if (_state.status == BookingListStatus.error && _state.items.isEmpty) {
      return BookingErrorView(message: _state.errorMessage ?? 'Could not load bookings', kind: _state.errorKind, onRetry: _load);
    }
    final pending = _state.pending;
    final today = _state.todays(_today);
    final upcoming = _state.upcomingConfirmed(_today);
    if (pending.isEmpty && today.isEmpty && upcoming.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: c.maxHeight,
              child: const BookingEmptyView(title: 'No booking requests yet', subtitle: 'New requests from clients will appear here.'),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('oduvar_requests_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_state.errorMessage != null && _state.errorKind != BookingErrorKind.none)
            BookingErrorBanner(message: _state.errorMessage!, onDismiss: _state.clearError),
          _header('Pending Requests', pending.length, const Key('header_pending')),
          if (pending.isEmpty) _none('No pending requests'),
          for (final b in pending)
            BookingCard(
              booking: b,
              showClient: true,
              busy: _state.busyId == b.id,
              onTap: () => _open(b),
              onAccept: () => _accept(b),
              onReject: () => _reject(b),
            ),
          _header("Today's Bookings", today.length, const Key('header_today')),
          if (today.isEmpty) _none('Nothing scheduled today'),
          for (final b in today) BookingCard(booking: b, showClient: true, onTap: () => _open(b)),
          _header('Upcoming Confirmed', upcoming.length, const Key('header_upcoming')),
          if (upcoming.isEmpty) _none('No upcoming confirmed bookings'),
          for (final b in upcoming) BookingCard(booking: b, showClient: true, onTap: () => _open(b)),
        ],
      ),
    );
  }

  Widget _header(String t, int n, Key key) => Padding(
        key: key,
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text('$t ($n)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroonDark)),
      );

  Widget _none(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t, style: const TextStyle(fontSize: 13, color: Color(0xFF9B8E84))),
      );
}
