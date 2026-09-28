import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/network/api_exceptions.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/oduvar/data/oduvar_profile_repository.dart';
import 'package:oduvar_mobile/features/oduvar/models/oduvar_profile_model.dart';
import 'package:oduvar_mobile/features/oduvar/presentation/oduvar_profile_view_screen.dart';
import 'package:oduvar_mobile/features/services/data/oduvar_service_repository.dart';
import 'package:oduvar_mobile/features/services/models/service_model.dart';

/// Loads a published Oduvar's public profile + active services from the real APIs and
/// shows them with the existing [OduvarProfileViewScreen] (which also hosts the
/// Services & Pricing section and the link to the public availability calendar).
class OduvarPublicProfileScreen extends StatefulWidget {
  final String oduvarId;
  final String? nameHint;
  final OduvarProfileRepository? profileRepository;
  final OduvarServiceRepository? serviceRepository;
  final AvailabilityRepository? availabilityRepository;

  const OduvarPublicProfileScreen({
    super.key,
    required this.oduvarId,
    this.nameHint,
    this.profileRepository,
    this.serviceRepository,
    this.availabilityRepository,
  });

  @override
  State<OduvarPublicProfileScreen> createState() => _OduvarPublicProfileScreenState();
}

class _OduvarPublicProfileScreenState extends State<OduvarPublicProfileScreen> {
  late final OduvarProfileRepository _profiles;
  late final OduvarServiceRepository _services;

  bool _loading = true;
  String? _error;
  OduvarProfileModel? _profile;
  List<OduvarServiceModel> _serviceList = const [];

  @override
  void initState() {
    super.initState();
    _profiles = widget.profileRepository ?? OduvarProfileRepository();
    _services = widget.serviceRepository ?? OduvarServiceRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _profiles.getPublicProfile(widget.oduvarId),
        _services.getPublicOduvarServices(widget.oduvarId).catchError((_) => <OduvarServiceModel>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as OduvarProfileModel;
        _serviceList = results[1] as List<OduvarServiceModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profile != null) {
      return OduvarProfileViewScreen(
        profile: _profile!,
        services: _serviceList,
        oduvarUserId: widget.oduvarId,
        availabilityRepository: widget.availabilityRepository,
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.sacredCream,
      appBar: AppBar(title: Text(widget.nameHint ?? 'Oduvar'), backgroundColor: AppTheme.sacredSurface),
      body: _loading ? _skeleton() : _errorView(),
    );
  }

  Widget _skeleton() {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: const Color(0xFFEFE8DD), borderRadius: BorderRadius.circular(8)),
        );
    return Padding(
      key: const Key('profile_loading'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFEFE8DD), shape: BoxShape.circle)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(160, 18), bar(100, 12)]),
          ]),
          const SizedBox(height: 20),
          bar(double.infinity, 80),
          bar(double.infinity, 120),
          bar(220, 16),
        ],
      ),
    );
  }

  Widget _errorView() => Center(
        key: const Key('profile_error'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 12),
            Text(_error ?? 'Could not load this profile',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF6B5E55))),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('profile_retry'),
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMaroon, foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ]),
        ),
      );
}
