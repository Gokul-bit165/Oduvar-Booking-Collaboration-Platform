import 'package:flutter/material.dart';
import '../../auth/presentation/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../availability/data/availability_repository.dart';
import '../../discovery/data/discovery_repository.dart';
import '../../discovery/models/discovery_model.dart';
import '../../discovery/presentation/discovery_state.dart';
import '../../discovery/presentation/oduvar_discovery_screen.dart';
import '../../discovery/presentation/widgets/discovery_states.dart';
import '../../discovery/presentation/widgets/oduvar_card.dart';
import '../../bookings/data/booking_repository.dart';
import '../../bookings/presentation/booking_state.dart';
import '../../bookings/presentation/client_bookings_screen.dart';
import '../../bookings/widgets/booking_card.dart';
import '../../notifications/notification_feature.dart';
import '../../oduvar/data/oduvar_profile_repository.dart';
import '../../services/data/oduvar_service_repository.dart';

/// Client home: search, popular services, event types and a preview of published Oduvars.
/// Repositories are injectable for tests; by default the real APIs are used.
class ClientHomeScreen extends StatefulWidget {
  final AuthState authState;
  final OduvarDiscoveryRepository? discoveryRepository;
  final OduvarProfileRepository? profileRepository;
  final OduvarServiceRepository? serviceRepository;
  final AvailabilityRepository? availabilityRepository;
  final BookingRepository? bookingRepository;
  final NotificationRepository? notificationRepository;

  const ClientHomeScreen({
    super.key,
    required this.authState,
    this.discoveryRepository,
    this.profileRepository,
    this.serviceRepository,
    this.availabilityRepository,
    this.bookingRepository,
    this.notificationRepository,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  /// Full discovery session (search text + filters persist while this screen lives).
  late final DiscoveryState _discovery;

  /// Small unfiltered preview list for the home page.
  late final DiscoveryState _preview;
  late final BookingState _bookings;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _discovery = DiscoveryState(repository: widget.discoveryRepository);
    _preview = DiscoveryState(repository: widget.discoveryRepository, pageSize: 5);
    _bookings = BookingState(repository: widget.bookingRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _discovery.loadOptions();
      _preview.ensureLoaded();
      _loadBookings();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _discovery.dispose();
    _preview.dispose();
    _bookings.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    final token = await widget.authState.getAccessToken();
    if (token != null) await _bookings.loadForClient(token);
  }

  Future<void> _openBookings([ClientBookingTab tab = ClientBookingTab.upcoming]) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientBookingsScreen(
        authState: widget.authState,
        state: _bookings,
        initialTab: tab,
      ),
    ));
    _loadBookings();
  }

  Future<void> _openDiscovery() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OduvarDiscoveryScreen(
        state: _discovery,
        profileRepository: widget.profileRepository,
        serviceRepository: widget.serviceRepository,
        availabilityRepository: widget.availabilityRepository,
        authState: widget.authState,
        bookingRepository: widget.bookingRepository,
      ),
    ));
  }

  void _searchFromHome(String text) {
    _discovery.setSearchText(text.trim());
    _discovery.submitSearch();
    _openDiscovery();
  }

  void _openWithFilters(OduvarSearchFilters filters) {
    _discovery.applyFilters(filters);
    _openDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devotee Sanctuary'),
        actions: [
          NotificationBell(authState: widget.authState, repository: widget.notificationRepository),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryMaroon,
          onRefresh: () async {
            await Future.wait([_preview.refresh(), _discovery.loadOptions(force: true), _loadBookings()]);
          },
          child: ListView(
            key: const Key('client_home_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _header(user?.name),
              const SizedBox(height: 22),
              ListenableBuilder(listenable: _bookings, builder: (context, _) => _bookingsSection()),
              const SizedBox(height: 22),
              const Text('Find an Oduvar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroonDark)),
              const SizedBox(height: 10),
              TextField(
                key: const Key('home_search_field'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _searchFromHome,
                decoration: InputDecoration(
                  hintText: 'Search Oduvar...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    key: const Key('home_search_button'),
                    tooltip: 'Search',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _searchFromHome(_search.text),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ListenableBuilder(
                listenable: _discovery,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),
                    _chipSection(
                      title: 'Popular Services',
                      keyPrefix: 'home_service',
                      items: _discovery.options.services,
                      onTap: (o) => _openWithFilters(OduvarSearchFilters.empty.copyWith(service: o.key)),
                    ),
                    _chipSection(
                      title: 'Event Types',
                      keyPrefix: 'home_event',
                      items: _discovery.options.eventTypes,
                      onTap: (o) => _openWithFilters(OduvarSearchFilters.empty.copyWith(eventType: o.key)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(children: [
                const Expanded(
                  child: Text('Discover Oduvars',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
                ),
                TextButton(
                  key: const Key('see_all_button'),
                  onPressed: () {
                    _discovery.clearFilters();
                    _openDiscovery();
                  },
                  child: const Text('See all'),
                ),
              ]),
              const SizedBox(height: 6),
              ListenableBuilder(listenable: _preview, builder: (context, _) => _previewList()),
              const SizedBox(height: 24),
              AppButton(
                label: 'Sign Out',
                variant: AppButtonVariant.outlined,
                icon: Icons.logout_rounded,
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingsSection() {
    final today = todayKey();
    final counts = {
      ClientBookingTab.upcoming: _bookings.upcoming(today).length,
      ClientBookingTab.pending: _bookings.pending.length,
      ClientBookingTab.completed: _bookings.completed.length,
      ClientBookingTab.cancelled: _bookings.cancelled.length,
    };
    const labels = {
      ClientBookingTab.upcoming: 'Upcoming',
      ClientBookingTab.pending: 'Pending',
      ClientBookingTab.completed: 'Completed',
      ClientBookingTab.cancelled: 'Cancelled',
    };
    final upcomingList = _bookings.upcoming(today);
    final next = upcomingList.isNotEmpty ? upcomingList.first : (_bookings.pending.isNotEmpty ? _bookings.pending.first : null);
    return Column(
      key: const Key('home_bookings_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(
            child: Text('My Bookings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
          ),
          TextButton(key: const Key('my_bookings_button'), onPressed: _openBookings, child: const Text('View all')),
        ]),
        const SizedBox(height: 6),
        if (_bookings.status == BookingListStatus.error)
          Row(children: [
            Expanded(
              child: Text(_bookings.errorMessage ?? 'Could not load bookings',
                  key: const Key('home_bookings_error'), style: const TextStyle(fontSize: 12, color: AppTheme.errorRed)),
            ),
            TextButton(key: const Key('home_bookings_retry'), onPressed: _loadBookings, child: const Text('Retry')),
          ])
        else ...[
          Row(children: [
            for (final t in ClientBookingTab.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    key: Key('home_count_${t.name}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openBookings(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.sacredBorder),
                      ),
                      child: Column(children: [
                        Text('${counts[t]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryMaroon)),
                        Text(labels[t]!, style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E55))),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          if (next != null) ...[
            const SizedBox(height: 12),
            BookingCard(booking: next, onTap: _openBookings),
          ],
        ],
      ],
    );
  }

  Widget _header(String? name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryMaroonDark, AppTheme.primaryMaroon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x298D1B1B), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.temple_hindu_rounded, color: AppTheme.sacredSaffron, size: 26),
            SizedBox(width: 10),
            Text('திருச்சிற்றம்பலம்',
                style: TextStyle(
                    color: AppTheme.sacredSaffron, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 10),
          Text('Vanakkam, ${name ?? 'Devotee'}',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _chipSection({
    required String title,
    required String keyPrefix,
    required List<OptionItem> items,
    required ValueChanged<OptionItem> onTap,
  }) {
    if (items.isEmpty) {
      // Options load from the backend; while loading show placeholders, on failure show nothing (search still works).
      if (!_discovery.optionsLoading) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          key: Key('${keyPrefix}_loading'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(title),
            Row(children: [
              for (var i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 84,
                  height: 32,
                  decoration: BoxDecoration(color: const Color(0xFFEFE8DD), borderRadius: BorderRadius.circular(16)),
                ),
            ]),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in items)
              ActionChip(
                key: Key('${keyPrefix}_${o.key}'),
                label: Text(o.label),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.sacredBorder),
                labelStyle: const TextStyle(color: AppTheme.primaryMaroon, fontWeight: FontWeight.w600),
                onPressed: () => onTap(o),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2C241F))),
      );

  Widget _previewList() {
    final s = _preview;
    if (s.status == DiscoveryStatus.initial || s.isLoading) {
      return const Column(key: Key('home_loading'), children: [OduvarCardSkeleton(), OduvarCardSkeleton()]);
    }
    if (s.status == DiscoveryStatus.error && s.items.isEmpty) {
      return SizedBox(
        height: 300,
        child: DiscoveryErrorState(message: s.errorMessage ?? 'Could not load Oduvars', onRetry: s.reload),
      );
    }
    if (s.items.isEmpty) {
      return const SizedBox(height: 300, child: DiscoveryEmptyState(hasActiveQuery: false));
    }
    return Column(
      children: [
        for (final o in s.items)
          OduvarCard(
            oduvar: o,
            onViewProfile: () => openOduvarProfile(
              context,
              o,
              profileRepository: widget.profileRepository,
              serviceRepository: widget.serviceRepository,
              availabilityRepository: widget.availabilityRepository,
            ),
          ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to end your current session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.authState.logout();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
