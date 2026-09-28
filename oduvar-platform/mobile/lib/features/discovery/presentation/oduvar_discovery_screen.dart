import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/bookings/data/booking_repository.dart';
import 'package:oduvar_mobile/features/oduvar/data/oduvar_profile_repository.dart';
import 'package:oduvar_mobile/features/services/data/oduvar_service_repository.dart';
import '../models/discovery_model.dart';
import 'discovery_state.dart';
import 'oduvar_public_profile_screen.dart';
import 'widgets/discovery_states.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/oduvar_card.dart';

/// Opens the public profile of a discovered Oduvar.
void openOduvarProfile(
  BuildContext context,
  OduvarDiscoveryModel oduvar, {
  OduvarProfileRepository? profileRepository,
  OduvarServiceRepository? serviceRepository,
  AvailabilityRepository? availabilityRepository,
  AuthState? authState,
  BookingRepository? bookingRepository,
}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => OduvarPublicProfileScreen(
      oduvarId: oduvar.id,
      nameHint: oduvar.name,
      profileRepository: profileRepository,
      serviceRepository: serviceRepository,
      availabilityRepository: availabilityRepository,
      authState: authState,
      bookingRepository: bookingRepository,
    ),
  ));
}

/// Search results: server-side search (debounced), filters, sorting, infinite
/// scroll / "Load more", pull-to-refresh, empty and error states.
class OduvarDiscoveryScreen extends StatefulWidget {
  final DiscoveryState state;
  final OduvarProfileRepository? profileRepository;
  final OduvarServiceRepository? serviceRepository;
  final AvailabilityRepository? availabilityRepository;
  final AuthState? authState;
  final BookingRepository? bookingRepository;

  const OduvarDiscoveryScreen({
    super.key,
    required this.state,
    this.profileRepository,
    this.serviceRepository,
    this.availabilityRepository,
    this.authState,
    this.bookingRepository,
  });

  @override
  State<OduvarDiscoveryScreen> createState() => _OduvarDiscoveryScreenState();
}

class _OduvarDiscoveryScreenState extends State<OduvarDiscoveryScreen> {
  late final TextEditingController _search;
  final ScrollController _scroll = ScrollController();

  DiscoveryState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: _state.searchText);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _state.loadOptions();
      _state.ensureLoaded();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _state.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final count = _state.activeFilterCount;
        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(title: const Text('Find an Oduvar'), backgroundColor: AppTheme.sacredSurface),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  key: const Key('discovery_search_field'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: _state.setSearchText,
                  onSubmitted: (_) => _state.submitSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search Oduvar name or location',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('discovery_search_clear'),
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _state.setSearchText('');
                              setState(() {});
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(children: [
                  OutlinedButton.icon(
                    key: const Key('filter_button'),
                    onPressed: () => showDiscoveryFilterSheet(context, _state),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(count > 0 ? 'Filters ($count)' : 'Filters'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: count > 0 ? Colors.white : AppTheme.primaryMaroon,
                      backgroundColor: count > 0 ? AppTheme.primaryMaroon : null,
                      side: const BorderSide(color: AppTheme.primaryMaroon),
                    ),
                  ),
                  if (count > 0)
                    TextButton(
                        key: const Key('clear_filters_button'),
                        onPressed: _state.clearFilters,
                        child: const Text('Clear')),
                  const Spacer(),
                  PopupMenuButton<DiscoverySort>(
                    key: const Key('sort_button'),
                    tooltip: 'Sort',
                    initialValue: _state.sort,
                    onSelected: _state.setSort,
                    itemBuilder: (_) => [
                      for (final s in DiscoverySort.values)
                        PopupMenuItem(value: s, key: Key('sort_${s.name}'), child: Text(s.label)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.sort, size: 18, color: AppTheme.primaryMaroon),
                        const SizedBox(width: 4),
                        Text(_state.sort.label,
                            key: const Key('sort_label'),
                            style: const TextStyle(fontSize: 13, color: AppTheme.primaryMaroon)),
                      ]),
                    ),
                  ),
                ]),
              ),
              Expanded(child: _results()),
            ],
          ),
        );
      },
    );
  }

  Widget _results() {
    final s = _state;
    if (s.status == DiscoveryStatus.initial || s.isLoading) return _skeletons();
    if (s.status == DiscoveryStatus.error && s.items.isEmpty) {
      return DiscoveryErrorState(message: s.errorMessage ?? 'Could not load Oduvars', onRetry: s.reload);
    }
    if (s.items.isEmpty) {
      final hasQuery = s.activeFilterCount > 0 || s.searchText.trim().isNotEmpty;
      return RefreshIndicator(
        onRefresh: s.refresh,
        color: AppTheme.primaryMaroon,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: c.maxHeight,
              child: DiscoveryEmptyState(
                hasActiveQuery: hasQuery,
                onClearFilters: s.activeFilterCount > 0 ? s.clearFilters : null,
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: s.refresh,
      color: AppTheme.primaryMaroon,
      child: ListView(
        key: const Key('discovery_list'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${s.total} ${s.total == 1 ? 'Oduvar' : 'Oduvars'}',
                key: const Key('result_count'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF9B8E84))),
          ),
          for (final o in s.items)
            OduvarCard(
              oduvar: o,
              onViewProfile: () => openOduvarProfile(
                context,
                o,
                profileRepository: widget.profileRepository,
                serviceRepository: widget.serviceRepository,
                availabilityRepository: widget.availabilityRepository,
                authState: widget.authState,
                bookingRepository: widget.bookingRepository,
              ),
            ),
          if (s.isLoadingMore)
            const Padding(padding: EdgeInsets.only(bottom: 14), child: OduvarCardSkeleton())
          else if (s.loadMoreFailed)
            Center(
              child: TextButton.icon(
                key: const Key('load_more_retry'),
                onPressed: s.loadMore,
                icon: const Icon(Icons.refresh),
                label: Text('${s.errorMessage ?? 'Could not load more'} - Retry'),
              ),
            )
          else if (s.hasNext)
            Center(
              child: OutlinedButton(
                key: const Key('load_more_button'),
                onPressed: s.loadMore,
                child: const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _skeletons() => ListView(
        key: const Key('discovery_loading'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: const [OduvarCardSkeleton(), OduvarCardSkeleton(), OduvarCardSkeleton()],
      );
}
