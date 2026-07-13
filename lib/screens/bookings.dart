import 'package:flutter/material.dart';
import '../api.dart';
import '../app_image.dart';
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
  void initState() {
    super.initState();
    _sync();
  }

  /// Pull confirmed bookings from the server (source of truth) and merge them in.
  Future<void> _sync() async {
    final rows = await Api.listBookings();
    if (!mounted) return;
    BookingStore.instance.mergeServerBookings(rows.map((e) => MyBooking.fromServer(e)).toList());
  }

  /// A booking is "past" once its slot date+time is before now (so a completed
  /// game moves to History even if the server hasn't flipped its status yet).
  bool _isPast(MyBooking b) {
    final t = (b.time.contains(':')) ? b.time : '23:59';
    final dt = DateTime.tryParse('${b.date}T$t:00') ?? DateTime.tryParse(b.date);
    return dt != null && dt.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BookingStore.instance,
      builder: (context, _) {
        // Upcoming = not cancelled/completed AND the slot hasn't passed yet.
        // History = completed, cancelled, OR the slot time is already in the past.
        final list = BookingStore.instance.myBookings.where((b) {
          final finished = b.status == 'completed' || b.status == 'cancelled' || _isPast(b);
          return _tab == 'upcoming' ? !finished : finished;
        }).toList();
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
                        child: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _sync,
                          child: list.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 80),
                                    _EmptyState(tab: _tab),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (b.image.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image(
                    image: appImg(b.image),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: AppColors.surfaceElevated),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(b.activity, style: T.h3, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: AppSpacing.sm),
                        Tag(bookingStatusLabel(b.status), tone: bookingStatusTone(b.status)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${b.bay} · ${b.date} · ${b.time}', style: T.caption),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(rupees(b.amount), style: T.bodyStrong),
              Row(children: [
                Icon(Icons.qr_code, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(b.pin.isNotEmpty ? 'PIN ${b.pin}' : 'QR', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
