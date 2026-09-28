import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';

// ─── Selectable chip for skills / songs / performance types ──────────────────

class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = selectedColor ?? AppTheme.primaryMaroon;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? activeColor : AppTheme.sacredBorder,
            width: selected ? 0 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: activeColor.withAlpha(50), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : const Color(0xFF6B5E53),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─── Section heading ─────────────────────────────────────────────────────────

class ProfileSectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ProfileSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                  letterSpacing: 0.3,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9B8E84)),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─── Profile completion bar ───────────────────────────────────────────────────

class ProfileCompletionBar extends StatelessWidget {
  final int percentage;

  const ProfileCompletionBar({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 80
        ? AppTheme.successGreen
        : percentage >= 50
            ? AppTheme.sacredSaffron
            : AppTheme.errorRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryMaroon.withAlpha(15),
            AppTheme.sacredSaffron.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profile Completion',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.primaryMaroonDark,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: AppTheme.sacredBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (percentage < 100)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _completionHint(percentage),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9B8E84)),
              ),
            ),
        ],
      ),
    );
  }

  String _completionHint(int p) {
    if (p < 30) return 'Add your bio, skills and location to get started.';
    if (p < 60) return 'Add performance types and instruments to stand out.';
    if (p < 80) return 'Add gallery photos to attract more clients.';
    return 'Almost complete! Add your profile photo.';
  }
}

// ─── Placeholder action button ────────────────────────────────────────────────

class PlaceholderActionButton extends StatelessWidget {
  final String label;
  final IconData icon;

  const PlaceholderActionButton({
    super.key,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label — coming in a future phase'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF9B8E84),
        side: const BorderSide(color: AppTheme.sacredBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── Transport display helper ─────────────────────────────────────────────────

String transportLabel(String key) {
  switch (key) {
    case 'INCLUDED':
      return 'Included';
    case 'NOT_INCLUDED':
      return 'Not Included';
    case 'ADDITIONAL_FEE':
      return 'Additional Fee';
    case 'TO_BE_DISCUSSED':
    default:
      return 'To Be Discussed';
  }
}
