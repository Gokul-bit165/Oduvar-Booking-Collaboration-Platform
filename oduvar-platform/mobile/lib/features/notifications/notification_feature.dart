import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/constants/api_constants.dart';
import 'package:oduvar_mobile/core/network/api_client.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';

// Persistent in-app notifications. There is no push provider configured yet, so nothing here
// pretends to deliver a push: the list is what the server has stored for this user.

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        isRead: j['isRead'] as bool? ?? false,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}

class NotificationPage {
  final List<AppNotification> items;
  final int unreadCount;
  const NotificationPage({required this.items, required this.unreadCount});
}

class NotificationRepository {
  final ApiClient _client;
  NotificationRepository({ApiClient? client}) : _client = client ?? ApiClient();

  Future<NotificationPage> list(String token) async {
    final data = await _client.get(ApiConstants.notifications, token: token);
    return NotificationPage(
      items: (data['items'] as List? ?? []).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList(),
      unreadCount: data['unreadCount'] as int? ?? 0,
    );
  }

  Future<void> markRead(String token, String id) => _client.post(ApiConstants.notificationRead(id), token: token, body: {});
  Future<void> markAllRead(String token) => _client.post(ApiConstants.notificationsReadAll, token: token, body: {});
}

/// App-bar bell with an unread badge; opens [NotificationsScreen].
class NotificationBell extends StatefulWidget {
  final AuthState authState;
  final NotificationRepository? repository;

  const NotificationBell({super.key, required this.authState, this.repository});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final NotificationRepository _repo = widget.repository ?? NotificationRepository();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final token = await widget.authState.getAccessToken();
      if (token == null) return;
      final page = await _repo.list(token);
      if (mounted) setState(() => _unread = page.unreadCount);
    } catch (_) {
      // The bell is a convenience; failures are surfaced on the notifications screen itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('notification_bell'),
      tooltip: _unread > 0 ? 'Notifications ($_unread unread)' : 'Notifications',
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NotificationsScreen(authState: widget.authState, repository: _repo),
        ));
        _refresh();
      },
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text('$_unread', key: const Key('notification_badge')),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  final AuthState authState;
  final NotificationRepository? repository;

  const NotificationsScreen({super.key, required this.authState, this.repository});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationRepository _repo = widget.repository ?? NotificationRepository();
  bool _loading = true;
  String? _error;
  List<AppNotification> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await widget.authState.getAccessToken();
      if (token == null) throw Exception('Please sign in again.');
      final page = await _repo.list(token);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markAll() async {
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await _repo.markAllRead(token);
    _load();
  }

  Future<void> _open(AppNotification n) async {
    final token = await widget.authState.getAccessToken();
    if (token == null || n.isRead) return;
    await _repo.markRead(token, n.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sacredCream,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.sacredSurface,
        actions: [
          TextButton(key: const Key('mark_all_read'), onPressed: _items.any((n) => !n.isRead) ? _markAll : null, child: const Text('Mark all read')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(key: Key('notifications_loading'), color: AppTheme.primaryMaroon))
          : _error != null
              ? Center(
                  key: const Key('notifications_error'),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : _items.isEmpty
                  ? const Center(key: Key('notifications_empty'), child: Text('No notifications yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final n = _items[i];
                          return ListTile(
                            key: Key('notification_${n.id}'),
                            onTap: () => _open(n),
                            leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active, color: n.isRead ? const Color(0xFF9B8E84) : AppTheme.primaryMaroon),
                            title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
                            subtitle: Text(n.body),
                          );
                        },
                      ),
                    ),
    );
  }
}
