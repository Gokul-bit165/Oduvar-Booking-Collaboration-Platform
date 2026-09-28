import 'package:flutter/material.dart';
import 'auth_state.dart';
import '../models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import 'login_screen.dart';
import '../../client/presentation/client_home_screen.dart';
import '../../oduvar/presentation/oduvar_dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  final AuthState authState;
  final UserRole initialRole;

  const RegisterScreen({
    super.key,
    required this.authState,
    this.initialRole = UserRole.client,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late UserRole _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole == UserRole.admin ? UserRole.client : widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,24}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\+?[0-9\s\-()]{10,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid phone number (10-15 digits)';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    widget.authState.clearError();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await widget.authState.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success && widget.authState.currentUser != null) {
      AppSnackbar.showSuccess(
        context,
        'Account created successfully! Welcome, ${widget.authState.currentUser!.name}.',
      );
      _routeByRole(widget.authState.currentUser!.role);
    } else {
      final errorMsg = widget.authState.errorMessage ?? 'Registration failed';
      AppSnackbar.showError(context, errorMsg);
    }
  }

  void _routeByRole(UserRole role) {
    Widget destination;
    if (role == UserRole.oduvar) {
      destination = OduvarDashboardScreen(authState: widget.authState);
    } else {
      destination = ClientHomeScreen(authState: widget.authState);
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join the Sacred Platform',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C241F),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Register to book venerable Oduvars or offer your devotional singing services.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7A6D61),
                  ),
                ),
                const SizedBox(height: 24),

                // Role Selector Tabs (Only CLIENT and ODUVAR, NEVER ADMIN)
                const Text(
                  'I am registering as:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF372F29),
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE6DC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildRoleTab(
                          key: const Key('register_role_tab_client'),
                          role: UserRole.client,
                          label: 'Devotee / Client',
                          icon: Icons.temple_buddhist_rounded,
                        ),
                      ),
                      Expanded(
                        child: _buildRoleTab(
                          key: const Key('register_role_tab_oduvar'),
                          role: UserRole.oduvar,
                          label: 'Oduvar Peruman',
                          icon: Icons.music_note_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Full Name
                AppTextField(
                  customKey: const Key('register_name_input'),
                  controller: _nameController,
                  label: 'Full Name',
                  hintText: 'Enter your legal / preferred name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: _validateName,
                ),

                const SizedBox(height: 16),

                // Email
                AppTextField(
                  customKey: const Key('register_email_input'),
                  controller: _emailController,
                  label: 'Email Address',
                  hintText: 'e.g. yourname@domain.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),

                const SizedBox(height: 16),

                // Phone
                AppTextField(
                  customKey: const Key('register_phone_input'),
                  controller: _phoneController,
                  label: 'Phone Number',
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),

                const SizedBox(height: 16),

                // Password
                AppTextField(
                  customKey: const Key('register_password_input'),
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: _validatePassword,
                ),

                const SizedBox(height: 16),

                // Confirm Password
                AppTextField(
                  customKey: const Key('register_confirm_password_input'),
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  prefixIcon: Icons.lock_reset_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmPassword,
                  onFieldSubmitted: (_) => _handleRegister(),
                ),

                const SizedBox(height: 28),

                // Submit Button
                AppButton(
                  customKey: const Key('register_submit_button'),
                  label: 'Create Account',
                  isLoading: _isLoading,
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _handleRegister,
                ),

                const SizedBox(height: 24),

                // Link to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: Color(0xFF6B5E53), fontSize: 14),
                    ),
                    GestureDetector(
                      key: const Key('register_go_to_login'),
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => LoginScreen(authState: widget.authState),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppTheme.primaryMaroon,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab({
    required Key key,
    required UserRole role,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      key: key,
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primaryMaroon : const Color(0xFF7A6D61),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryMaroon : const Color(0xFF7A6D61),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
