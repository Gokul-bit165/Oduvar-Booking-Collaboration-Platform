import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outlined, text }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final double? width;
  final double height;
  final Key? customKey;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.width,
    this.height = 50,
    this.customKey,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveKey = customKey ?? key;

    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.outlined || variant == AppButtonVariant.text
                ? AppTheme.primaryMaroon
                : Colors.white,
          ),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    } else {
      child = Text(label);
    }

    Widget button;

    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          key: effectiveKey,
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryMaroon,
            foregroundColor: Colors.white,
            minimumSize: Size(width ?? double.infinity, height),
          ),
          child: child,
        );
        break;

      case AppButtonVariant.secondary:
        button = ElevatedButton(
          key: effectiveKey,
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.sacredSaffron,
            foregroundColor: Colors.white,
            minimumSize: Size(width ?? double.infinity, height),
          ),
          child: child,
        );
        break;

      case AppButtonVariant.outlined:
        button = OutlinedButton(
          key: effectiveKey,
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(width ?? double.infinity, height),
          ),
          child: child,
        );
        break;

      case AppButtonVariant.text:
        button = TextButton(
          key: effectiveKey,
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryMaroon,
            minimumSize: Size(width ?? double.infinity, height),
          ),
          child: child,
        );
        break;
    }

    return SizedBox(
      width: width ?? double.infinity,
      child: button,
    );
  }
}
