import 'package:flutter/material.dart';
import '../auth.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

/// Loyalty / rewards. Points are the REAL balance from the backend
/// (`User.loyaltyPoints`, earned 1 pt per ₹100 spent on confirmed bookings),
/// surfaced via `/auth/me` and refreshed on open.
class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});
  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  @override
  void initState() {
    super.initState();
    // Pull the latest points balance whenever this tab is shown.
    AuthState.instance.refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([BookingStore.instance, AuthState.instance]),
      builder: (context, _) {
        final store = BookingStore.instance;
        final user = AuthState.instance.user;
        final pts = user?.loyaltyPoints ?? 0;
        const nextTier = 1000;
        final progress = (pts / nextTier).clamp(0.0, 1.0);
        final tier = pts >= nextTier ? 'Gold' : 'Silver';
        final referral = 'STRIKIN-${(user?.email ?? 'GUEST').split('@').first.toUpperCase()}';

        return AppScaffold(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Text('Loyalty', style: T.h1),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('STRIKIN REWARDS', style: TextStyle(color: AppColors.textOnAccent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        Icon(Icons.diamond, size: 18, color: AppColors.textOnAccent),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('$pts pts', style: const TextStyle(color: AppColors.textOnAccent, fontSize: 28, fontWeight: FontWeight.w800)),
                    Text(pts >= nextTier ? '$tier member' : '$tier member · ${nextTier - pts} pts to Gold',
                        style: const TextStyle(color: AppColors.textOnAccent)),
                    const SizedBox(height: AppSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: const Color(0x33000000), color: AppColors.textOnAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Refer & earn', style: T.h3),
                          SizedBox(height: 4),
                          Text('You and your friend each get 100 pts on their first booking.', style: T.caption),
                        ]),
                      ),
                      Icon(Icons.card_giftcard, size: 26, color: AppColors.primary),
                    ]),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(referral, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, letterSpacing: 1)),
                          Row(children: const [Icon(Icons.copy, size: 16, color: AppColors.textMuted), SizedBox(width: 6), Text('Copy', style: T.label)]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Points activity', style: T.h3),
              const SizedBox(height: AppSpacing.md),
              if (store.myBookings.isEmpty)
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Column(children: const [
                      Icon(Icons.diamond_outlined, size: 32, color: AppColors.textFaint),
                      SizedBox(height: AppSpacing.sm),
                      Text('No points yet', style: T.body),
                      SizedBox(height: 2),
                      Text('Earn points every time you complete a booking.', textAlign: TextAlign.center, style: T.caption),
                    ]),
                  ),
                )
              else
                AppCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < store.myBookings.length; i++) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${store.myBookings[i].activity} · ${store.myBookings[i].bay}', style: T.body),
                                Text(store.myBookings[i].date, style: const TextStyle(color: AppColors.textFaint, fontSize: 13)),
                              ]),
                            ),
                            Tag('+${(store.myBookings[i].amount / 100).floor()}', tone: 'accent'),
                          ],
                        ),
                        if (i < store.myBookings.length - 1) const Divider(color: AppColors.border, height: AppSpacing.xl),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              const Center(child: Text('Points are credited after each confirmed booking — 1 point for every ₹100 spent.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
            ],
          ),
        );
      },
    );
  }
}
