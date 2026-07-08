import 'package:flutter/material.dart';
import '../api.dart';
import '../auth.dart';
import '../theme.dart';
import 'home.dart';
import 'bookings.dart';
import 'corporate_cx.dart';
import 'loyalty.dart';
import 'profile.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _maintenance = false;

  @override
  void initState() {
    super.initState();
    AuthState.instance.addListener(_onAuth);
    Api.maintenanceEnabled().then((m) {
      if (mounted && m) setState(() => _maintenance = true);
    });
  }

  // Rebuild when the user logs in/out so a corporate login swaps the home tab.
  void _onAuth() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_onAuth);
    super.dispose();
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    // Role decides the home tab: super admin → full company dashboard,
    // team lead → their scoped team+budget view, everyone else → normal home.
    final u = AuthState.instance.user;
    final Widget home = (u?.isSuperAdmin ?? false)
        ? const CxDashboardScreen()
        : (u?.isTeamLead ?? false)
            ? const CxTeamLeadDashboard()
            : HomeScreen(onOpenTab: _goTo);
    final screens = [
      home,
      const BookingsScreen(),
      const LoyaltyScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (_maintenance)
            Material(
              color: AppColors.warning,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(children: const [
                    Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFF191919)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Strikin is under maintenance — some features may be unavailable.', style: TextStyle(color: Color(0xFF191919), fontSize: 12, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            ),
          Expanded(child: IndexedStack(index: _index, children: screens)),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceAlt,
          indicatorColor: const Color(0x26D6FD31),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textFaint,
              )),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: [
            NavigationDestination(icon: const Icon(Icons.explore_outlined, color: AppColors.textFaint), selectedIcon: Icon(Icons.explore, color: AppColors.primary), label: 'Explore'),
            NavigationDestination(icon: const Icon(Icons.calendar_today_outlined, color: AppColors.textFaint), selectedIcon: Icon(Icons.calendar_today, color: AppColors.primary), label: 'Bookings'),
            NavigationDestination(icon: const Icon(Icons.diamond_outlined, color: AppColors.textFaint), selectedIcon: Icon(Icons.diamond, color: AppColors.primary), label: 'Loyalty'),
            NavigationDestination(icon: const Icon(Icons.person_outline, color: AppColors.textFaint), selectedIcon: Icon(Icons.person, color: AppColors.primary), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
