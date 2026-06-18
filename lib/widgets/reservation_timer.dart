import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Green banner: "1 activity reserved • mm:ss left" — counts down from 10 min,
/// matching the production reservation hold.
class ReservationTimer extends StatefulWidget {
  const ReservationTimer({super.key});
  @override
  State<ReservationTimer> createState() => _ReservationTimerState();
}

class _ReservationTimerState extends State<ReservationTimer> {
  int _seconds = 10 * 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) _seconds--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      color: const Color(0x1AD6FD31),
      child: Text(
        '1 activity reserved  •  $m:$s mins left',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
