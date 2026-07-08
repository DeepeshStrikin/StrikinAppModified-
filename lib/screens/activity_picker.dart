import 'package:flutter/material.dart';
import '../api.dart';
import '../app_image.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import 'activity_booking.dart';
import 'shows.dart';

/// Picker shown when the user taps "Add another activity" during checkout.
/// Selecting an activity starts a fresh activity-booking flow while the
/// previously-configured activities stay in the multi-activity cart.
class ActivityPickerScreen extends StatefulWidget {
  const ActivityPickerScreen({super.key});
  @override
  State<ActivityPickerScreen> createState() => _ActivityPickerScreenState();
}

class _ActivityPickerScreenState extends State<ActivityPickerScreen> {
  List<ActivityType> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Api.getActivities().then((a) {
      if (mounted) setState(() { _activities = a; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _open(ActivityType a) {
    BookingStore.instance.setActivity(a);
    final s = '${a.slug} ${a.name}'.toLowerCase();
    final isScreen = s.contains('mega-screen') || s.contains('mega screen') || s.contains('screen');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => isScreen ? const ShowsScreen() : const ActivityBookingScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = BookingStore.instance.cart.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppHeader(title: 'Add another activity'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: Text(
                    cartCount == 1
                        ? '1 activity already in your booking. Pick another to add.'
                        : '$cartCount activities already in your booking. Pick another to add.',
                    style: T.caption,
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                          itemCount: _activities.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                          itemBuilder: (_, i) => _tile(_activities[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(ActivityType a) => GestureDetector(
        onTap: () => _open(a),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.md)),
                child: Image(
                  image: appImg(a.image),
                  width: 96,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 96,
                    height: 84,
                    color: AppColors.surfaceAlt,
                    child: const Icon(Icons.sports_esports_outlined, color: AppColors.textFaint),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: T.bodyStrong),
                    if (a.tagline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(a.tagline, style: T.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: AppSpacing.md),
                child: Icon(Icons.chevron_right, color: AppColors.textFaint),
              ),
            ],
          ),
        ),
      );
}
