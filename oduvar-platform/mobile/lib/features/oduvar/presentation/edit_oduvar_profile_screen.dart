import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/auth_state.dart';
import '../models/oduvar_profile_model.dart';
import 'oduvar_profile_state.dart';
import 'oduvar_profile_view_screen.dart';
import 'widgets/profile_widgets.dart';

class EditOduvarProfileScreen extends StatefulWidget {
  final OduvarProfileState profileState;
  final AuthState authState;

  const EditOduvarProfileScreen({
    super.key,
    required this.profileState,
    required this.authState,
  });

  @override
  State<EditOduvarProfileScreen> createState() =>
      _EditOduvarProfileScreenState();
}

class _EditOduvarProfileScreenState extends State<EditOduvarProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();

  Set<String> _selectedSkillIds = {};
  Set<String> _selectedInstrumentIds = {};
  Set<String> _selectedPerformanceTypes = {};
  Set<String> _selectedSongCategories = {};
  String _transport = 'TO_BE_DISCUSSED';
  bool _collaborationEnabled = true;
  bool _isPublished = false;
  bool _isInitialized = false;

  final _transportOptions = [
    ('INCLUDED', 'Included'),
    ('NOT_INCLUDED', 'Not Included'),
    ('ADDITIONAL_FEE', 'Additional Fee'),
    ('TO_BE_DISCUSSED', 'To Be Discussed'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeForm();
      widget.profileState.loadReferenceData();
    });
  }

  void _initializeForm({bool callSetState = true}) {
    final p = widget.profileState.profile;
    if (p != null && !_isInitialized) {
      _bioController.text = p.bio ?? '';
      _locationController.text = p.location ?? '';
      _selectedSkillIds = p.skills.map((s) => s.id).toSet();
      _selectedInstrumentIds = p.instruments.map((i) => i.id).toSet();
      _selectedPerformanceTypes = Set.from(p.performanceTypes);
      _selectedSongCategories = Set.from(p.songCategories);
      _transport = p.transport;
      _collaborationEnabled = p.collaborationEnabled;
      _isPublished = p.isPublished;
      _isInitialized = true;
      if (callSetState && mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final token = await widget.authState.getAccessToken();
    if (token == null) return;

    final payload = {
      'bio': _bioController.text.trim(),
      'location': _locationController.text.trim(),
      'skillIds': _selectedSkillIds.toList(),
      'instrumentIds': _selectedInstrumentIds.toList(),
      'performanceTypes': _selectedPerformanceTypes.toList(),
      'songCategories': _selectedSongCategories.toList(),
      'transport': _transport,
      'collaborationEnabled': _collaborationEnabled,
      'isPublished': _isPublished,
    };

    final success = await widget.profileState.saveProfile(token, payload);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.profileState.errorMessage ?? 'Save failed'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final token = await widget.authState.getAccessToken();
    if (token == null) return;

    if (widget.profileState.profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save your profile first before uploading photos'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if ((widget.profileState.profile?.photos.length ?? 0) >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 gallery photos allowed'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    final success = await widget.profileState.uploadPhoto(token, File(picked.path));
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(widget.profileState.errorMessage ?? 'Photo upload failed'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deletePhoto(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Remove this photo from your gallery?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.errorRed))),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await widget.profileState.deletePhoto(token, photoId);
  }

  void _preview() {
    final p = widget.profileState.profile;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save your profile first to see a preview'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OduvarProfileViewScreen(
          profile: p,
          isPreviewMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.profileState,
      builder: (context, _) {
        if (!_isInitialized && widget.profileState.profile != null) {
          _initializeForm(callSetState: false);
        }
        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(
            title: const Text('Edit Profile'),
            backgroundColor: AppTheme.sacredSurface,
            actions: [
              TextButton.icon(
                key: const Key('preview_button'),
                onPressed: _preview,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.sacredSaffron,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Completion bar
                if (widget.profileState.profile != null)
                  ProfileCompletionBar(
                    percentage: widget.profileState.profile!.completionPercentage,
                  ),

                const SizedBox(height: 24),

                // ── Bio ──────────────────────────────────────────────────────
                _sectionCard(
                  'Introduction',
                  'Tell clients and collaborators about yourself',
                  [
                    TextFormField(
                      key: const Key('bio_input'),
                      controller: _bioController,
                      maxLines: 5,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText:
                            'Share your experience, specializations, and what makes your service sacred...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Location ─────────────────────────────────────────────────
                _sectionCard('Location', 'City / Region you serve', [
                  TextFormField(
                    key: const Key('location_input'),
                    controller: _locationController,
                    decoration: const InputDecoration(
                      prefixIcon:
                          Icon(Icons.location_on_outlined, color: AppTheme.sacredSaffron),
                      hintText: 'e.g. Chennai, Tamil Nadu',
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── Skills ───────────────────────────────────────────────────
                _sectionCard(
                  'Good At',
                  'Select all that apply',
                  [_buildSkillSelector()],
                ),

                const SizedBox(height: 16),

                // ── Performance Types ────────────────────────────────────────
                _sectionCard(
                  'Performance Type',
                  'How you perform',
                  [_buildPerformanceSelector()],
                ),

                const SizedBox(height: 16),

                // ── Song Categories ──────────────────────────────────────────
                _sectionCard(
                  'Sacred Songs',
                  'Devotional categories you specialize in',
                  [_buildSongCategorySelector()],
                ),

                const SizedBox(height: 16),

                // ── Instruments ──────────────────────────────────────────────
                _sectionCard(
                  'Instruments',
                  'Select instruments you play',
                  [_buildInstrumentSelector()],
                ),

                const SizedBox(height: 16),

                // ── Transport ────────────────────────────────────────────────
                _sectionCard(
                  'Transport',
                  'Is travel included in your service?',
                  [_buildTransportSelector()],
                ),

                const SizedBox(height: 16),

                // ── Collaboration ────────────────────────────────────────────
                _sectionCard(
                  'Collaboration',
                  'Are you open to performing with other Oduvars?',
                  [
                    SwitchListTile(
                      key: const Key('collaboration_switch'),
                      title: const Text('Available for Collaboration',
                          style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        _collaborationEnabled
                            ? 'Other Oduvars can invite you'
                            : 'You will not receive collaboration invites',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _collaborationEnabled,
                      onChanged: (v) => setState(() => _collaborationEnabled = v),
                      activeColor: AppTheme.primaryMaroon,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Gallery ──────────────────────────────────────────────────
                _sectionCard(
                  'Gallery Photos',
                  'Up to 5 photos showcasing your performances',
                  [_buildGalleryManager()],
                ),

                const SizedBox(height: 16),

                // ── Visibility ───────────────────────────────────────────────
                _sectionCard(
                  'Profile Visibility',
                  'Make your profile visible to clients and collaborators',
                  [
                    SwitchListTile(
                      key: const Key('publish_switch'),
                      title: const Text('Published (Public)',
                          style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        _isPublished
                            ? 'Your profile is visible to everyone'
                            : 'Profile is saved but not publicly visible',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _isPublished,
                      onChanged: (v) => setState(() => _isPublished = v),
                      activeColor: AppTheme.successGreen,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Save Button ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('save_profile_button'),
                    onPressed: widget.profileState.status == ProfileStatus.saving
                        ? null
                        : _save,
                    child: widget.profileState.status == ProfileStatus.saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Profile'),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Skill selector ────────────────────────────────────────────────────────

  Widget _buildSkillSelector() {
    final skills = widget.profileState.availableSkills;
    if (skills.isEmpty) {
      return const Text('Loading skills...',
          style: TextStyle(fontSize: 13, color: Color(0xFF9B8E84)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills
          .map((skill) => SelectableChip(
                key: Key('skill_chip_${skill.slug}'),
                label: skill.name,
                selected: _selectedSkillIds.contains(skill.id),
                onTap: () => setState(() {
                  if (_selectedSkillIds.contains(skill.id)) {
                    _selectedSkillIds.remove(skill.id);
                  } else {
                    _selectedSkillIds.add(skill.id);
                  }
                }),
              ))
          .toList(),
    );
  }

  // ─── Performance type selector ─────────────────────────────────────────────

  Widget _buildPerformanceSelector() {
    final types = widget.profileState.performanceTypes.isNotEmpty
        ? widget.profileState.performanceTypes
        : ['VOCAL', 'INSTRUMENTAL', 'BOTH'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types
          .map((type) => SelectableChip(
                key: Key('perf_chip_$type'),
                label: type[0] + type.substring(1).toLowerCase(),
                selected: _selectedPerformanceTypes.contains(type),
                selectedColor: AppTheme.sacredSaffron,
                onTap: () => setState(() {
                  if (_selectedPerformanceTypes.contains(type)) {
                    _selectedPerformanceTypes.remove(type);
                  } else {
                    _selectedPerformanceTypes.add(type);
                  }
                }),
              ))
          .toList(),
    );
  }

  // ─── Song category selector ────────────────────────────────────────────────

  Widget _buildSongCategorySelector() {
    final categories = widget.profileState.songCategories.isNotEmpty
        ? widget.profileState.songCategories
        : [
            {'key': 'THEVARAM', 'label': 'Thevaram'},
            {'key': 'THIRUVASAGAM', 'label': 'Thiruvasagam'},
            {'key': 'THIRUPUGAZH', 'label': 'Thirupugazh'},
            {'key': 'OTHER', 'label': 'Other'},
          ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories
          .map((cat) => SelectableChip(
                key: Key('song_chip_${cat['key']}'),
                label: cat['label']!,
                selected:
                    _selectedSongCategories.contains(cat['key']),
                selectedColor: AppTheme.sandalWood,
                onTap: () => setState(() {
                  final key = cat['key']!;
                  if (_selectedSongCategories.contains(key)) {
                    _selectedSongCategories.remove(key);
                  } else {
                    _selectedSongCategories.add(key);
                  }
                }),
              ))
          .toList(),
    );
  }

  // ─── Instrument selector ───────────────────────────────────────────────────

  Widget _buildInstrumentSelector() {
    final instruments = widget.profileState.availableInstruments;
    if (instruments.isEmpty) {
      return const Text('Loading instruments...',
          style: TextStyle(fontSize: 13, color: Color(0xFF9B8E84)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: instruments
          .map((inst) => SelectableChip(
                key: Key('inst_chip_${inst.slug}'),
                label: inst.name,
                selected: _selectedInstrumentIds.contains(inst.id),
                selectedColor: const Color(0xFF1B6B5A),
                onTap: () => setState(() {
                  if (_selectedInstrumentIds.contains(inst.id)) {
                    _selectedInstrumentIds.remove(inst.id);
                  } else {
                    _selectedInstrumentIds.add(inst.id);
                  }
                }),
              ))
          .toList(),
    );
  }

  // ─── Transport selector ────────────────────────────────────────────────────

  Widget _buildTransportSelector() {
    return Column(
      children: _transportOptions.map((option) {
        final selected = _transport == option.$1;
        return RadioListTile<String>(
          key: Key('transport_${option.$1}'),
          title: Text(option.$2, style: const TextStyle(fontSize: 14)),
          value: option.$1,
          groupValue: _transport,
          onChanged: (v) => setState(() => _transport = v!),
          activeColor: AppTheme.primaryMaroon,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          selected: selected,
        );
      }).toList(),
    );
  }

  // ─── Gallery manager ───────────────────────────────────────────────────────

  Widget _buildGalleryManager() {
    final photos = widget.profileState.profile?.photos ?? [];
    final canAdd = photos.length < 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = photos[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photo.imageUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.sacredBorder,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _deletePhoto(photo.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (canAdd)
          OutlinedButton.icon(
            key: const Key('add_photo_button'),
            onPressed: _pickAndUploadPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(photos.isEmpty
                ? 'Add Gallery Photo'
                : 'Add Photo (${photos.length}/5)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryMaroon,
              side: const BorderSide(color: AppTheme.primaryMaroon),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.sacredSaffron.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.sacredSaffron.withAlpha(60)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppTheme.sacredSaffron),
                SizedBox(width: 8),
                Text(
                  'Maximum 5 photos reached',
                  style: TextStyle(fontSize: 12, color: AppTheme.sandalWood),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Section card builder ─────────────────────────────────────────────────

  Widget _sectionCard(String title, String subtitle, List<Widget> children) {
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
            ProfileSectionHeading(title: title, subtitle: subtitle),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
