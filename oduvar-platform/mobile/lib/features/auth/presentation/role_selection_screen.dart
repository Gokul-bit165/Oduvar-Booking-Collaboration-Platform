import 'package:flutter/material.dart';
import 'auth_state.dart';
import '../models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';
import 'register_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AuthState authState;

  const RoleSelectionScreen({super.key, required this.authState});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Path'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How will you be using the platform?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C241F),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the role that fits you. You can register as a Devotee/Client or as an Oduvar.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7A6D61),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Role Option 1: Client
              _buildRoleOption(
                key: const Key('role_option_client'),
                role: UserRole.client,
                title: 'Devotee / Temple Client',
                tamilTitle: 'அன்பர் / மெய்யன்பர்',
                description:
                    'Discover skilled Oduvars, check sacred calendar availability, and book devotional singing for your family, temple, or event.',
                icon: Icons.temple_buddhist_rounded,
                selectedColor: AppTheme.primaryMaroon,
              ),

              const SizedBox(height: 16),

              // Role Option 2: Oduvar
              _buildRoleOption(
                key: const Key('role_option_oduvar'),
                role: UserRole.oduvar,
                title: 'Oduvar (Sacred Hymn Singer)',
                tamilTitle: 'ஓதுவார் பெருமக்கள்',
                description:
                    'Offer Thevaram, Thiruvasagam and devotional music. Manage your availability schedule and collaborate with fellow Oduvars.',
                icon: Icons.music_note_rounded,
                selectedColor: AppTheme.sacredGold,
              ),

              const SizedBox(height: 32),

              AppButton(
                customKey: const Key('role_continue_button'),
                label: 'Continue to Registration',
                variant: AppButtonVariant.primary,
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegisterScreen(
                        authState: widget.authState,
                        initialRole: _selectedRole,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption({
    required Key key,
    required UserRole role,
    required String title,
    required String tamilTitle,
    required String description,
    required IconData icon,
    required Color selectedColor,
  }) {
    final isSelected = _selectedRole == role;

    return AppCard(
      backgroundColor: isSelected ? selectedColor.withOpacity(0.04) : Colors.white,
      borderColor: isSelected ? selectedColor : AppTheme.sacredBorder,
      borderWidth: isSelected ? 2.0 : 1.0,
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Row(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : const Color(0xFFF3ECE4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.white : const Color(0xFF7A6D61),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? selectedColor : const Color(0xFF2C241F),
                        ),
                      ),
                    ),
                    Radio<UserRole>(
                      value: role,
                      groupValue: _selectedRole,
                      activeColor: selectedColor,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedRole = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
                Text(
                  tamilTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selectedColor.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B5E53),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
