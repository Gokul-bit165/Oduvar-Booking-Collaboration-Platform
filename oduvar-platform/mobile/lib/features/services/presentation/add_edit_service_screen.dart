import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../models/service_model.dart';
import 'oduvar_service_state.dart';

class DurationRowItem {
  int durationMinutes;
  final TextEditingController amountController;

  DurationRowItem({
    required this.durationMinutes,
    required this.amountController,
  });
}

class AddEditServiceScreen extends StatefulWidget {
  final OduvarServiceState serviceState;
  final AuthState authState;
  final OduvarServiceModel? serviceToEdit;

  const AddEditServiceScreen({
    super.key,
    required this.serviceState,
    required this.authState,
    this.serviceToEdit,
  });

  @override
  State<AddEditServiceScreen> createState() => _AddEditServiceScreenState();
}

class _AddEditServiceScreenState extends State<AddEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _transportFeeController = TextEditingController();

  ServiceModel? _selectedBaseService;
  String _transport = 'TO_BE_DISCUSSED';
  bool _isActive = true;
  final List<DurationRowItem> _durationRows = [];

  final List<(int, String)> _durationChoices = [
    (30, '30 minutes'),
    (45, '45 minutes'),
    (60, '1 hour'),
    (90, '1.5 hours'),
    (120, '2 hours'),
    (150, '2.5 hours'),
    (180, '3 hours'),
    (240, '4 hours'),
  ];

  final _transportOptions = [
    ('INCLUDED', 'Included'),
    ('NOT_INCLUDED', 'Not Included'),
    ('ADDITIONAL_FEE', 'Additional Fee'),
    ('TO_BE_DISCUSSED', 'To Be Discussed'),
  ];

  @override
  void initState() {
    super.initState();
    _initFromService();
  }

  void _initFromService() {
    final s = widget.serviceToEdit;
    if (s != null) {
      _descriptionController.text = s.customDescription ?? '';
      _transport = s.transport;
      if (s.transportFee != null && s.transportFee! > 0) {
        final isInt = s.transportFee == s.transportFee!.roundToDouble();
        _transportFeeController.text =
            isInt ? s.transportFee!.toInt().toString() : s.transportFee!.toStringAsFixed(2);
      }
      _isActive = s.isActive;

      for (final p in s.pricings) {
        final isInt = p.amount == p.amount.roundToDouble();
        final amountText = isInt ? p.amount.toInt().toString() : p.amount.toStringAsFixed(2);
        _durationRows.add(DurationRowItem(
          durationMinutes: p.durationMinutes,
          amountController: TextEditingController(text: amountText),
        ));
      }
    } else {
      // Default: 1 duration row (60 min)
      _durationRows.add(DurationRowItem(
        durationMinutes: 60,
        amountController: TextEditingController(text: '900'),
      ));
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _transportFeeController.dispose();
    for (final row in _durationRows) {
      row.amountController.dispose();
    }
    super.dispose();
  }

  void _addDurationRow() {
    setState(() {
      // Pick next available duration choice if possible
      final existingDurations = _durationRows.map((r) => r.durationMinutes).toSet();
      int nextDuration = 60;
      for (final choice in _durationChoices) {
        if (!existingDurations.contains(choice.$1)) {
          nextDuration = choice.$1;
          break;
        }
      }
      _durationRows.add(DurationRowItem(
        durationMinutes: nextDuration,
        amountController: TextEditingController(),
      ));
    });
  }

  void _removeDurationRow(int index) {
    if (_durationRows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one duration option is required')),
      );
      return;
    }
    setState(() {
      _durationRows[index].amountController.dispose();
      _durationRows.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.serviceToEdit == null && _selectedBaseService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service')),
      );
      return;
    }

    // Check duplicate durations
    final seenDurations = <int>{};
    for (final r in _durationRows) {
      if (seenDurations.contains(r.durationMinutes)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duplicate duration of ${r.durationMinutes} minutes found')),
        );
        return;
      }
      seenDurations.add(r.durationMinutes);
    }

    final token = await widget.authState.getAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication session expired')),
      );
      return;
    }

    double? transportFee;
    if (_transport == 'ADDITIONAL_FEE') {
      transportFee = double.tryParse(_transportFeeController.text.trim());
      if (transportFee == null || transportFee <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid transport fee greater than zero')),
        );
        return;
      }
    }

    final pricingsPayload = _durationRows.map((r) {
      final amount = double.tryParse(r.amountController.text.trim()) ?? 0;
      return {
        'durationMinutes': r.durationMinutes,
        'amount': amount,
        'currency': 'INR',
      };
    }).toList();

    bool success;
    if (widget.serviceToEdit == null) {
      // Create new
      success = await widget.serviceState.createService(token, {
        'serviceId': _selectedBaseService!.id,
        'customDescription': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'transport': _transport,
        'transportFee': transportFee,
        'pricings': pricingsPayload,
      });
    } else {
      // Update existing
      success = await widget.serviceState.updateService(token, widget.serviceToEdit!.id, {
        'customDescription': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'transport': _transport,
        'transportFee': transportFee,
        'isActive': _isActive,
      });

      // Update/add any individual pricings if needed
      if (success) {
        for (final p in pricingsPayload) {
          final existingPricing = widget.serviceToEdit!.pricings
              .where((ep) => ep.durationMinutes == p['durationMinutes'])
              .firstOrNull;
          if (existingPricing == null) {
            await widget.serviceState.addPricing(
              token,
              widget.serviceToEdit!.id,
              p['durationMinutes'] as int,
              p['amount'] as double,
            );
          }
        }
      }
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.serviceToEdit == null
                ? 'Service created successfully'
                : 'Service updated successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.serviceState.errorMessage ?? 'Failed to save service'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.serviceToEdit != null;
    final availableBaseServices = widget.serviceState.availableBaseServices;

    return Scaffold(
      backgroundColor: AppTheme.sacredCream,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Service' : 'Add Service'),
        backgroundColor: AppTheme.sacredSurface,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Service Selection ──────────────────────────────────────────
            _sectionCard(
              title: 'Service Offering',
              subtitle: 'Select from standardized devotional services',
              children: [
                if (isEditing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.sacredCream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.sacredBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.serviceToEdit!.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.serviceToEdit!.category,
                          style: const TextStyle(fontSize: 12, color: AppTheme.sacredGold),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<ServiceModel>(
                    key: const Key('service_dropdown'),
                    decoration: InputDecoration(
                      labelText: 'Select Service *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    value: _selectedBaseService,
                    items: availableBaseServices.map((svc) {
                      return DropdownMenuItem<ServiceModel>(
                        value: svc,
                        child: Text('${svc.name} (${svc.category})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBaseService = val;
                      });
                    },
                    validator: (val) => val == null ? 'Please select a service' : null,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Description ────────────────────────────────────────────────
            _sectionCard(
              title: 'Description',
              subtitle: 'Specific details about your performance offering',
              children: [
                TextFormField(
                  key: const Key('service_description_input'),
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'e.g. Traditional Thirumurai pann recital with rhythm support...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Duration & Pricing ─────────────────────────────────────────
            _sectionCard(
              title: 'Duration & Pricing',
              subtitle: 'Configure your duration options and fees (Min 30 mins)',
              trailing: TextButton.icon(
                key: const Key('add_duration_button'),
                onPressed: _addDurationRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Duration'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryMaroon),
              ),
              children: [
                ..._durationRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.sacredCream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.sacredBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Duration dropdown
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            key: Key('duration_dropdown_$index'),
                            decoration: InputDecoration(
                              labelText: 'Duration',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            value: row.durationMinutes,
                            items: _durationChoices.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.$1,
                                child: Text(c.$2, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => row.durationMinutes = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Amount input
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            key: Key('amount_input_$index'),
                            controller: row.amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Fee (₹)',
                              prefixText: '₹ ',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Required';
                              }
                              final num = double.tryParse(val.trim());
                              if (num == null || num <= 0) {
                                return 'Must be > 0';
                              }
                              return null;
                            },
                          ),
                        ),

                        // Delete row button
                        IconButton(
                          key: Key('delete_duration_$index'),
                          icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
                          onPressed: () => _removeDurationRow(index),
                          tooltip: 'Remove duration option',
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 16),

            // ── Transport Policy ───────────────────────────────────────────
            _sectionCard(
              title: 'Transport Configuration',
              subtitle: 'Specify how your travel is arranged',
              children: [
                ..._transportOptions.map((opt) {
                  return RadioListTile<String>(
                    key: Key('transport_option_${opt.$1}'),
                    title: Text(opt.$2, style: const TextStyle(fontSize: 14)),
                    value: opt.$1,
                    groupValue: _transport,
                    onChanged: (v) => setState(() => _transport = v!),
                    activeColor: AppTheme.primaryMaroon,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }),
                if (_transport == 'ADDITIONAL_FEE') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('transport_fee_input'),
                    controller: _transportFeeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Transport Fee (₹) *',
                      prefixText: '₹ ',
                      hintText: 'e.g. 300',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (_transport == 'ADDITIONAL_FEE') {
                        if (val == null || val.trim().isEmpty) {
                          return 'Transport fee is required';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) {
                          return 'Transport fee must be greater than zero';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),

            if (isEditing) ...[
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Service Status',
                subtitle: 'Active services are visible to clients',
                children: [
                  SwitchListTile(
                    key: const Key('active_toggle_switch'),
                    title: const Text('Active Service', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      _isActive ? 'Clients can book this service' : 'Temporarily deactivated',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeColor: AppTheme.primaryMaroon,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // ── Save Button ────────────────────────────────────────────────
            ElevatedButton(
              key: const Key('save_service_button'),
              onPressed: widget.serviceState.isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryMaroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: widget.serviceState.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isEditing ? 'Save Changes' : 'Save Service',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.sacredBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryMaroonDark,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9B8E84)),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
