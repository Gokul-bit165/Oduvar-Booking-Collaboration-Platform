import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../models/service_model.dart';
import 'oduvar_service_state.dart';
import 'add_edit_service_screen.dart';

class MyServicesScreen extends StatefulWidget {
  final OduvarServiceState serviceState;
  final AuthState authState;

  const MyServicesScreen({
    super.key,
    required this.serviceState,
    required this.authState,
  });

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final token = await widget.authState.getAccessToken();
    if (token != null) {
      await widget.serviceState.loadMyServices(token);
    }
  }

  Future<void> _openAddService() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditServiceScreen(
          serviceState: widget.serviceState,
          authState: widget.authState,
        ),
      ),
    );
    _loadData();
  }

  Future<void> _openEditService(OduvarServiceModel service) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditServiceScreen(
          serviceState: widget.serviceState,
          authState: widget.authState,
          serviceToEdit: service,
        ),
      ),
    );
    _loadData();
  }

  Future<void> _toggleStatus(OduvarServiceModel service) async {
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await widget.serviceState.toggleServiceActive(token, service);
  }

  Future<void> _deleteService(OduvarServiceModel service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "${service.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final token = await widget.authState.getAccessToken();
      if (token != null) {
        await widget.serviceState.deleteService(token, service.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.serviceState,
      builder: (context, _) {
        final state = widget.serviceState;
        final services = state.services;

        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(
            title: const Text('My Services & Pricing'),
            backgroundColor: AppTheme.sacredSurface,
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_service_fab'),
            onPressed: _openAddService,
            backgroundColor: AppTheme.primaryMaroon,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
          ),
          body: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primaryMaroon,
            child: _buildBody(state, services),
          ),
        );
      },
    );
  }

  Widget _buildBody(OduvarServiceState state, List<OduvarServiceModel> services) {
    if (state.isLoading && services.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryMaroon),
      );
    }

    if (state.status == ServiceStateStatus.error && services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'Failed to load services',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B5E55)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryMaroon,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryMaroon.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppTheme.primaryMaroon,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Services Configured',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryMaroonDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Define the sacred services, duration options, and honorarium you offer to devotees.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF9B8E84)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const Key('empty_add_service_button'),
                onPressed: _openAddService,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Your First Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryMaroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(service);
      },
    );
  }

  Widget _buildServiceCard(OduvarServiceModel service) {
    return Container(
      key: Key('service_card_${service.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: service.isActive ? AppTheme.sacredBorder : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name and status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  service.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: service.isActive ? AppTheme.primaryMaroonDark : Colors.grey.shade600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: service.isActive
                      ? AppTheme.successGreen.withAlpha(25)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  service.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: service.isActive ? AppTheme.successGreen : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),

          if ((service.customDescription ?? service.baseDescription) != null) ...[
            const SizedBox(height: 6),
            Text(
              service.customDescription ?? service.baseDescription!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55)),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(color: AppTheme.sacredBorder, height: 1),
          const SizedBox(height: 10),

          // Duration & Pricing Rows
          ...service.pricings.map((p) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        p.durationLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Text(
                    p.formattedAmount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryMaroon,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          // Transport policy
          Row(
            children: [
              Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Transport: ${service.transportDisplay}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55)),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: AppTheme.sacredBorder, height: 1),
          const SizedBox(height: 8),

          // Action Buttons: Edit, Disable/Enable, Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: Key('edit_button_${service.id}'),
                onPressed: () => _openEditService(service),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryMaroon,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: Key('toggle_button_${service.id}'),
                onPressed: () => _toggleStatus(service),
                style: OutlinedButton.styleFrom(
                  foregroundColor: service.isActive ? Colors.grey.shade700 : AppTheme.successGreen,
                  side: BorderSide(
                    color: service.isActive ? Colors.grey.shade400 : AppTheme.successGreen,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  service.isActive ? 'Disable' : 'Enable',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: Key('delete_button_${service.id}'),
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                onPressed: () => _deleteService(service),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
