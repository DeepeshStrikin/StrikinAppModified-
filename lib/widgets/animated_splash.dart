import 'package:flutter/material.dart';
import '../theme.dart';
import 'brand_mark.dart';

/// Launch animation: the brand rings ripple in, then STRIKIN appears
/// letter-by-letter, then the tagline — then it fades out and calls onFinish.
class AnimatedSplash extends StatefulWidget {
  final VoidCallback? onFinish;
  const AnimatedSplash({super.key, this.onFinish});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash> with TickerProviderStateMixin {
  static const _word = 'STRIKIN';

  late final AnimationController _rings =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  late final AnimationController _letters =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final AnimationController _tag =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350), value: 1);

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _rings.forward();
    await _letters.forward();
    await _tag.forward();
    await Future.delayed(const Duration(milliseconds: 450));
    await _fade.reverse();
    widget.onFinish?.call();
  }

  @override
  void dispose() {
    _rings.dispose();
    _letters.dispose();
    _tag.dispose();
    _fade.dispose();
    super.dispose();
  }

  Widget _letter(int i) {
    final start = i / _word.length * 0.7;
    final anim = CurvedAnimation(parent: _letters, curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final v = anim.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 18),
            child: Text(
              _word[i],
              style: const TextStyle(color: AppColors.text, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 4),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBrandMark(controller: _rings, size: 168),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (int i = 0; i < _word.length; i++) _letter(i)],
            ),
            const SizedBox(height: AppSpacing.sm),
            FadeTransition(
              opacity: _tag,
              child: Text('THE ADVENTURE MENU',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 4)),
            ),
          ],
        ),
      ),
    );
  }
}
