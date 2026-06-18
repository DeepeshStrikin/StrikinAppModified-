import 'package:flutter/material.dart';
import '../api.dart';
import '../app_image.dart';
import '../auth.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'activity_booking.dart';
import 'corporate.dart';
import 'info_screens.dart';

const _heroImg =
    'https://cdn.sanity.io/images/y370h02s/production/6624398bde2b524e87d266a0c255324e341a611f-1920x1080.png?w=1200&q=75';

class HomeScreen extends StatefulWidget {
  final void Function(int) onOpenTab;
  const HomeScreen({super.key, required this.onOpenTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ActivityType> _activities = [];
  final _scroll = ScrollController();
  final _activitiesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Api.getActivities().then((a) => setState(() => _activities = a));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(ActivityType a) {
    BookingStore.instance.setActivity(a);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityBookingScreen()));
  }

  void _scrollToActivities() {
    final ctx = _activitiesKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const _StrikinDrawer(),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // Header: STRIKIN + hamburger
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('STRIKIN',
                          style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3)),
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: AppColors.text),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero
                        Stack(
                          children: [
                            Image(image: appImg(_heroImg),
                                height: 440, width: double.infinity, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(height: 440, color: AppColors.surface)),
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0x33000000), Color(0xCC191919)],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: AppSpacing.lg,
                              right: AppSpacing.lg,
                              bottom: AppSpacing.xl,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('THE FUTURE HAS AN\nADDRESS — STRIKIN',
                                      style: TextStyle(color: AppColors.text, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
                                  const SizedBox(height: AppSpacing.lg),
                                  SizedBox(
                                    width: 180,
                                    child: AppButton('Book activity', onPressed: _scrollToActivities),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Activities
                        Padding(
                          key: _activitiesKey,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                          child: const Text('Select an activity to book', style: T.h2),
                        ),
                        ..._activities.map((a) => Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                              child: GestureDetector(
                                onTap: () => _open(a),
                                child: AppCard(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(a.name, style: T.h3),
                                            const SizedBox(height: 6),
                                            Text(a.tagline, style: T.caption),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        child: Image(image: appImg(a.image), width: 120, height: 90, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(width: 120, height: 90, color: AppColors.surfaceElevated)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )),

                        // Corporate entry
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                          child: AppCard(
                            borderColor: AppColors.primary,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('Corporate / Bulk booking', style: T.h3),
                                      SizedBox(height: 4),
                                      Text('Register your company, allocate budgets, and book group sessions.', style: T.caption),
                                    ]),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Icon(Icons.business, color: AppColors.primary, size: 28),
                                ]),
                                const SizedBox(height: AppSpacing.md),
                                AppButton('Explore corporate', variant: 'secondary',
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CorporateScreen()))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StrikinDrawer extends StatelessWidget {
  const _StrikinDrawer();

  @override
  Widget build(BuildContext context) {
    void go(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    final items = <(IconData, String, VoidCallback)>[
      (Icons.person_outline, 'Login / Sign up', () => AuthState.instance.logout()),
      (Icons.star_outline, 'Attractions', () => go(const AttractionsScreen())),
      (Icons.info_outline, 'About us', () => go(const AboutScreen())),
      (Icons.description_outlined, 'Blogs', () => go(const BlogsScreen())),
      (Icons.work_outline, 'Corporate booking', () => go(const CorporateScreen())),
      (Icons.headset_mic_outlined, 'Support', () => go(const SupportScreen())),
    ];
    return Drawer(
      backgroundColor: AppColors.surfaceAlt,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('STRIKIN',
                  style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3)),
            ),
            ...items.map((it) => ListTile(
                  leading: Icon(it.$1, color: AppColors.text),
                  title: Text(it.$2, style: T.bodyStrong),
                  onTap: () {
                    Navigator.of(context).pop();
                    it.$3();
                  },
                )),
          ],
        ),
      ),
    );
  }
}
