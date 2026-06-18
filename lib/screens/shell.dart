import 'package:flutter/material.dart';
import '../theme.dart';
import 'home.dart';
import 'bookings.dart';
import 'loyalty.dart';
import 'profile.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onOpenTab: _goTo),
      const BookingsScreen(),
      const LoyaltyScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: screens),
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
