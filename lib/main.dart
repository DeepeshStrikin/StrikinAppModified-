import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_nav.dart';
import 'auth.dart';
import 'deep_link.dart';
import 'theme.dart';
import 'widgets/animated_splash.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'screens/corporate_cx.dart';
import 'screens/guest_invite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AuthState.instance.load();
  runApp(const StrikinApp());
}

class StrikinApp extends StatefulWidget {
  const StrikinApp({super.key});

  @override
  State<StrikinApp> createState() => _StrikinAppState();
}

class _StrikinAppState extends State<StrikinApp> {
  @override
  void initState() {
    super.initState();
    // Native invite deep links (strikin://join/… and verified https App Links)
    // are handled by app_links; the web build uses Uri.base below. Init after
    // the first frame so the Navigator exists when a cold-start link arrives.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => DeepLinkService.instance.init());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web: if the app was opened from an invite link (?invite=TOKEN), show the
    // guest invite screen directly — guests don't need to log in.
    final inviteToken = kIsWeb ? Uri.base.queryParameters['invite'] : null;
    return MaterialApp(
      title: 'Strikin',
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: (inviteToken != null && inviteToken.isNotEmpty)
          ? GuestInviteScreen(token: inviteToken)
          : const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _animDone = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthState.instance,
      builder: (context, _) {
        final auth = AuthState.instance;
        final ready = auth.isReady && _animDone;

        Widget content;
        if (!ready) {
          content = const SizedBox.shrink();
        } else if (auth.user == null) {
          content = const LoginScreen();
        } else if (auth.user?.isCorporate ?? false) {
          // Corporate users (super admin + team lead) get the dedicated
          // Home / Team / Bookings / Settings shell.
          content = const CxCorporateShell();
        } else {
          content = const AppShell();
        }

        return Stack(
          children: [
            AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: content),
            if (!ready)
              AnimatedSplash(onFinish: () => setState(() => _animDone = true)),
          ],
        );
      },
    );
  }
}
