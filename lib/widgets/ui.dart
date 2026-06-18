import 'package:flutter/material.dart';
import '../theme.dart';

/// Primary / secondary / ghost button.
class AppButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;
  final String variant; // primary | secondary | ghost
  final bool loading;
  const AppButton(this.title, {super.key, this.onPressed, this.variant = 'primary', this.loading = false});

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == 'primary';
    final disabled = onPressed == null || loading;
    final bg = isPrimary
        ? AppColors.primary
        : variant == 'secondary'
            ? AppColors.surfaceElevated
            : Colors.transparent;
    final fg = isPrimary ? AppColors.textOnAccent : AppColors.text;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                  : Text(title, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.lg), this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor ?? AppColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final bool selected, disabled;
  final VoidCallback? onTap;
  const Pill(this.label, {super.key, this.selected = false, this.disabled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, color: selected ? AppColors.textOnAccent : AppColors.text)),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String label;
  final String tone; // neutral | success | accent | danger
  const Tag(this.label, {super.key, this.tone = 'neutral'});

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    switch (tone) {
      case 'success': bg = AppColors.successBg; fg = AppColors.success; break;
      case 'accent': bg = const Color(0x26D6FD31); fg = AppColors.primary; break;
      case 'danger': bg = const Color(0x26E5484D); fg = AppColors.danger; break;
      default: bg = AppColors.surfaceElevated; fg = AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }
}

class AppField extends StatelessWidget {
  final IconData icon;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  const AppField({super.key, required this.icon, required this.hint, this.controller, this.keyboardType, this.autofocus = false, this.onChanged, this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textFaint),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofocus: autofocus,
            onChanged: onChanged,
            style: style ?? const TextStyle(color: AppColors.text, fontSize: 15),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textFaint),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
      ]),
    );
  }
}

String rupees(num v) {
  final s = v.round().toString();
  // Indian grouping
  final buf = StringBuffer();
  final digits = s.length;
  for (int i = 0; i < digits; i++) {
    buf.write(s[i]);
    final remaining = digits - i - 1;
    if (remaining > 3 && (remaining - 3) % 2 == 0) buf.write(',');
    else if (remaining == 3) buf.write(',');
  }
  return '₹${buf.toString()}';
}
