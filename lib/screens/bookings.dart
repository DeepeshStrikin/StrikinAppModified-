import 'package:flutter/material.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'booking_summary.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _tab = 'upcoming';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BookingStore.instance,
      builder: (context, _) {
        final list = BookingStore.instance.myBookings
            .where((b) => _tab == 'upcoming' ? b.status == 'upcoming' : b.status != 'upcoming')
            .toList();
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const Text('My bookings', style: T.h1),
                      const SizedBox(height: AppSpacing.lg),
                      // Tabs
                      Row(
                        children: [
                          for (final t in ['upcoming', 'completed'])
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: GestureDetector(
                                onTap: () => setState(() => _tab = t),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: _tab == t ? AppColors.primary : AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(t == 'upcoming' ? 'Upcoming' : 'History',
                                      style: T.label.copyWith(color: _tab == t ? AppColors.textOnAccent : AppColors.textMuted)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Expanded(
                        child: list.isEmpty
                            ? _EmptyState(tab: _tab)
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                                itemBuilder: (ctx, i) => GestureDetector(
                                  onTap: () => Navigator.of(ctx).push(
                                      MaterialPageRoute(builder: (_) => BookingSummaryScreen(booking: list[i]))),
                                  child: _BookingCard(b: list[i]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String tab;
  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.surfaceElevated, shape: BoxShape.circle),
            child: const Icon(Icons.calendar_today_outlined, size: 36, color: AppColors.textFaint),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tab == 'upcoming' ? 'No upcoming bookings yet' : 'No past bookings yet',
            style: T.h3.copyWith(color: AppColors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            width: 260,
            child: Text('Book an activity from the Explore tab to get started.',
                textAlign: TextAlign.center, style: T.caption),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final MyBooking b;
  const _BookingCard({required this.b});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(b.activity, style: T.h3, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: AppSpacing.sm),
              Tag(b.status.toUpperCase(),
                  tone: b.status == 'upcoming' ? 'accent' : b.status == 'completed' ? 'success' : 'danger'),
            ],
          ),
          const SizedBox(height: 4),
          Text('${b.bay} · ${b.date} · ${b.time}', style: T.caption),
          const Divider(color: AppColors.border, height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(rupees(b.amount), style: T.bodyStrong),
              Row(children: [
                Icon(Icons.qr_code, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('PIN ${b.pin}', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
