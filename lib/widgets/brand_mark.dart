import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _rings = ['assets/ring1.svg', 'assets/ring2.svg', 'assets/ring3.svg', 'assets/ring4.svg'];

/// Static Strikin brand mark — the official grayscale logo, rendered directly
/// (no badge) on the dark theme.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [for (final r in _rings) SvgPicture.asset(r, width: size, height: size)]),
    );
  }
}

/// Animated brand mark — rings fade + scale in (staggered).
class AnimatedBrandMark extends StatelessWidget {
  final double size;
  final Animation<double> controller;
  const AnimatedBrandMark({super.key, required this.controller, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: List.generate(_rings.length, (i) {
          final start = i * 0.16;
          final end = (start + 0.5).clamp(0.0, 1.0);
          final anim = CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeOutBack));
          return AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final v = anim.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: v,
                child: Transform.scale(scale: 0.4 + 0.6 * v, child: SvgPicture.asset(_rings[i], width: size, height: size)),
              );
            },
          );
        }),
      ),
    );
  }
}
