import 'package:flutter/material.dart';
import '../theme.dart';
import 'brand_mark.dart';

/// Responsive page scaffold: dark background, safe area, and a phone-width
/// (max 480) centered column so it looks right on phones, tablets and web.
class AppScaffold extends StatelessWidget {
  final Widget child;
  final Widget? bottomBar;
  final bool scroll;
  final EdgeInsetsGeometry padding;
  const AppScaffold({
    super.key,
    required this.child,
    this.bottomBar,
    this.scroll = true,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(padding: padding, child: child);
    if (scroll) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        child: body,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: bottomBar,
                ),
              ),
            ),
    );
  }
}

/// In-screen header: back arrow · STRIKIN (or title) · profile icon.
class AppHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final VoidCallback? onProfile;
  const AppHeader({super.key, this.title = 'Strikin', this.showBack = true, this.onProfile});

  @override
  Widget build(BuildContext context) {
    final canBack = showBack && Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: canBack
                ? IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(Icons.arrow_back, color: AppColors.text),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(title, style: T.h3),
            ),
          ),
          SizedBox(
            width: 40,
            child: onProfile == null
                ? const SizedBox()
                : IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerRight,
                    icon: const Icon(Icons.account_circle_outlined, color: AppColors.text),
                    onPressed: onProfile,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Small brand row used at the top of the home screen.
class BrandRow extends StatelessWidget {
  const BrandRow({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(children: const [
      BrandMark(size: 30),
      SizedBox(width: AppSpacing.sm),
      Text('STRIKIN', style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2)),
    ]);
  }
}
