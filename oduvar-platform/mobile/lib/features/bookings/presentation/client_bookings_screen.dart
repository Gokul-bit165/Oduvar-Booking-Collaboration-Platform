import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../data/booking_repository.dart';
import '../models/booking_model.dart';
import '../widgets/booking_card.dart';
import '../widgets/booking_states.dart';
import 'booking_details_screen.dart';
import 'booking_state.dart';

String todayKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

enum ClientBookingTab { upcoming, pending, completed, cancelled }

/// The client's bookings, grouped: Upcoming / Pending / Completed / Cancelled.
class ClientBookingsScreen extends StatefulWidget {
  final AuthState authState;
  final BookingState? state;
  final BookingRepository? bookingRepository;
  final String? today; // injectable for tests
  final ClientBookingTab initialTab;

  const ClientBookingsScreen({
    super.key,
    required this.authState,
    this.state,
    this.bookingRepository,
    this.today,
    this.initialTab = ClientBookingTab.upcoming,
  });

  @override
  State<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends State<ClientBookingsScreen> {
  late final BookingState _state;
  late final bool _ownsState;
  late ClientBookingTab _tab;

  String get _today => widget.today ?? todayKey();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
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
    await _state.loadForClient(token);
  }

  List<BookingModel> _group(ClientBookingTab t) {
    switch (t) {
      case ClientBookingTab.upcoming:
        return _state.upcoming(_today);
      case ClientBookingTab.pending:
        return _state.pending;
      case ClientBookingTab.completed:
        return _state.completed;
      case ClientBookingTab.cancelled:
        return _state.cancelled;
    }
  }

  static const _labels = {
    ClientBookingTab.upcoming: 'Upcoming',
    ClientBookingTab.pending: 'Pending',
    ClientBookingTab.completed: 'Completed',
    ClientBookingTab.cancelled: 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.sacredCream,
        appBar: AppBar(title: const Text('My Bookings'), backgroundColor: AppTheme.sacredSurface),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_state.isLoading && _state.items.isEmpty) return const BookingLoadingView();
    if (_state.status == BookingListStatus.error && _state.items.isEmpty) {
      return BookingErrorView(message: _state.errorMessage ?? 'Could not load bookings', kind: _state.errorKind, onRetry: _load);
    }
    final items = _group(_tab);
    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          children: [
            for (final t in ClientBookingTab.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('tab_${t.name}'),
                  label: Text('${_labels[t]} (${_group(t).length})'),
                  selected: _tab == t,
                  selectedColor: AppTheme.primaryMaroon.withAlpha(30),
                  onSelected: (_) => setState(() => _tab = t),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: items.isEmpty
              ? LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: c.maxHeight,
                      child: BookingEmptyView(
                        title: 'No ${_labels[_tab]!.toLowerCase()} bookings',
                        subtitle: _tab == ClientBookingTab.upcoming
                            ? 'Find an Oduvar and request a booking to see it here.'
                            : 'Bookings will appear here.',
                      ),
                    ),
                  ),
                )
              : ListView(
                  key: const Key('client_bookings_list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    for (final b in items)
                      BookingCard(
                        booking: b,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BookingDetailsScreen(
                            bookingId: b.id,
                            initial: b,
                            viewer: BookingViewer.client,
                            authState: widget.authState,
                            state: _state,
                          ),
                        )),
                      ),
                  ],
                ),
        ),
      ),
    ]);
  }
}
