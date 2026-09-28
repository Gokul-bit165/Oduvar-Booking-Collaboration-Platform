import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oduvar_mobile/core/network/api_exceptions.dart';
import '../models/discovery_model.dart';
import '../data/discovery_repository.dart';

enum DiscoveryStatus { initial, loading, loaded, error }

/// Query state for discovery. It owns: search text, filters, sort, current page,
/// hasNext, results, and loading / error state. Any change to text, filters or sort
/// resets to page 1; [loadMore] appends the next page.
class DiscoveryState extends ChangeNotifier {
  final OduvarDiscoveryRepository _repository;
  final Duration debounce;
  final int pageSize;

  DiscoveryState({
    OduvarDiscoveryRepository? repository,
    this.debounce = const Duration(milliseconds: 400),
    this.pageSize = 20,
  }) : _repository = repository ?? OduvarDiscoveryRepository();

  String _searchText = '';
  OduvarSearchFilters _filters = OduvarSearchFilters.empty;
  DiscoverySort _sort = DiscoverySort.relevance;

  DiscoveryStatus _status = DiscoveryStatus.initial;
  List<OduvarDiscoveryModel> _items = [];
  int _page = 0;
  int _total = 0;
  bool _hasNext = false;
  bool _loadingMore = false;
  bool _refreshing = false;
  String? _errorMessage;
  bool _loadMoreFailed = false;

  DiscoveryFilterOptions _options = const DiscoveryFilterOptions();
  bool _optionsLoading = false;
  bool _optionsFailed = false;

  Timer? _debounceTimer;
  int _requestSeq = 0; // guards against stale responses overwriting newer ones
  bool _disposed = false;

  String get searchText => _searchText;
  OduvarSearchFilters get filters => _filters;
  DiscoverySort get sort => _sort;
  DiscoveryStatus get status => _status;
  bool get isLoading => _status == DiscoveryStatus.loading;
  bool get isLoadingMore => _loadingMore;
  bool get isRefreshing => _refreshing;
  List<OduvarDiscoveryModel> get items => List.unmodifiable(_items);
  int get page => _page;
  int get total => _total;
  bool get hasNext => _hasNext;
  String? get errorMessage => _errorMessage;
  bool get loadMoreFailed => _loadMoreFailed;
  int get activeFilterCount => _filters.activeCount;
  DiscoveryFilterOptions get options => _options;
  bool get optionsLoading => _optionsLoading;
  bool get optionsFailed => _optionsFailed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ─── Reference options ───────────────────────────────────────────────────

  Future<void> loadOptions({bool force = false}) async {
    if (_optionsLoading || (!force && !_options.isEmpty)) return;
    _optionsLoading = true;
    _optionsFailed = false;
    notifyListeners();
    try {
      _options = await _repository.getFilterOptions();
    } catch (_) {
      _optionsFailed = true;
    }
    _optionsLoading = false;
    notifyListeners();
  }

  // ─── Query changes (all reset pagination) ────────────────────────────────

  /// Called on every keystroke; only the last value within [debounce] triggers a request.
  void setSearchText(String text) {
    if (text == _searchText) return;
    _searchText = text;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, reload);
    notifyListeners();
  }

  /// Keyboard "search" action: skip the debounce.
  void submitSearch() {
    _debounceTimer?.cancel();
    reload();
  }

  void applyFilters(OduvarSearchFilters filters) {
    if (filters == _filters) return;
    _filters = filters;
    _debounceTimer?.cancel();
    reload();
  }

  void clearFilters() => applyFilters(OduvarSearchFilters.empty);

  void setSort(DiscoverySort sort) {
    if (sort == _sort) return;
    _sort = sort;
    _debounceTimer?.cancel();
    reload();
  }

  // ─── Loading ─────────────────────────────────────────────────────────────

  /// Loads the first page if nothing has been requested yet.
  Future<void> ensureLoaded() async {
    if (_status == DiscoveryStatus.initial) await reload();
  }

  /// Page 1 with the current text/filters/sort. Shows the loading (skeleton) state.
  Future<void> reload() async {
    final seq = ++_requestSeq;
    _debounceTimer?.cancel();
    _status = DiscoveryStatus.loading;
    _errorMessage = null;
    _loadMoreFailed = false;
    _loadingMore = false;
    _items = [];
    _page = 0;
    _hasNext = false;
    _total = 0;
    notifyListeners();
    await _fetch(seq, 1, replace: true);
  }

  /// Pull-to-refresh: keeps the current results on screen until page 1 arrives.
  Future<void> refresh() async {
    final seq = ++_requestSeq;
    _debounceTimer?.cancel();
    _refreshing = true;
    _loadMoreFailed = false;
    notifyListeners();
    await _fetch(seq, 1, replace: true);
    _refreshing = false;
    notifyListeners();
  }

  /// Appends the next page (no-op while loading or when there is no next page).
  Future<void> loadMore() async {
    if (!_hasNext || _loadingMore || isLoading || _refreshing) return;
    final seq = ++_requestSeq;
    _loadingMore = true;
    _loadMoreFailed = false;
    notifyListeners();
    await _fetch(seq, _page + 1, replace: false);
  }

  Future<void> _fetch(int seq, int page, {required bool replace}) async {
    try {
      final result = await _repository.search(
        search: _searchText,
        filters: _filters,
        sort: _sort,
        page: page,
        pageSize: pageSize,
      );
      if (seq != _requestSeq || _disposed) return; // superseded by a newer query
      _items = replace ? result.items : [..._items, ...result.items];
      _page = result.page;
      _total = result.total;
      _hasNext = result.hasNext;
      _status = DiscoveryStatus.loaded;
      _errorMessage = null;
    } catch (e) {
      if (seq != _requestSeq || _disposed) return;
      _errorMessage = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');
      if (replace && _items.isEmpty) {
        _status = DiscoveryStatus.error;
      } else if (!replace) {
        _loadMoreFailed = true;
      }
    } finally {
      if (seq == _requestSeq) _loadingMore = false;
    }
    notifyListeners();
  }
}
