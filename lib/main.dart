import 'package:flutter/material.dart';
import 'app_nav.dart';
import 'auth.dart';
import 'theme.dart';
import 'widgets/animated_splash.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'screens/guest_invite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AuthState.instance.load();
  runApp(const StrikinApp());
}

class StrikinApp extends StatelessWidget {
  const StrikinApp({super.key});

  @override
  Widget build(BuildContext context) {
    // If the app was opened from an invite link (?invite=TOKEN), show the
    // guest invite screen directly — guests don't need to log in.
    final inviteToken = Uri.base.queryParameters['invite'];
    return MaterialApp(
      title: 'Strikin',
      navigatorKey: navigatorKey,
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
