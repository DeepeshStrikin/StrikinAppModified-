import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'app_nav.dart';
import 'screens/guest_invite.dart';
import 'screens/corporate_cx.dart';

/// Routes incoming deep links / App Links to the right screen.
///
/// Recognised invite forms (all yield a token → [GuestInviteScreen]):
///   strikin://join/<token>
///   strikin://invite?token=<token>
///   https://<host>/join/<token>
///   https://<host>/?invite=<token>          (same as the web build)
///
/// Handles both a cold start (link that launched the app) and links that
/// arrive while the app is already running.
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// Call once, after the first frame, so [navigatorKey] has a Navigator.
  Future<void> init() async {
    if (_started) return;
    _started = true;

    // Warm start: links delivered while the app is running.
    _sub = _appLinks.uriLinkStream.listen(_handle, onError: (_) {});

    // Cold start: the link that launched the app (if any).
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (_) {/* no initial link */}
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  /// Extract an invite token from any supported URI shape.
  static String? inviteTokenFrom(Uri uri) {
    // ?invite=<token> (web-style, and https://host/?invite=)
    final q = uri.queryParameters['invite'] ?? uri.queryParameters['token'];
    if (q != null && q.isNotEmpty) return q;

    // Path form: .../join/<token>  (also custom-scheme host "join": strikin://join/<token>)
    final segments = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();
    final i = segments.indexWhere((s) => s == 'join' || s == 'invite');
    if (i != -1 && i + 1 < segments.length) return segments[i + 1];
    return null;
  }

  /// Corporate team-join code from  strikin://corporate/join/<code>  (or the
  /// https path form). Kept separate from booking invites so it opens the
  /// company-join form rather than the guest booking screen.
  static String? corporateJoinCodeFrom(Uri uri) {
    final segs = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();
    final ci = segs.indexOf('corporate');
    if (ci != -1 && ci + 2 < segs.length && segs[ci + 1] == 'join') return segs[ci + 2];
    return null;
  }

  void _handle(Uri uri) {
    debugPrint('[deep_link] received: $uri');
    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[deep_link] navigator not ready — ignoring');
      return;
    }
    // Corporate team-join links open the company-join form (not the booking invite).
    final joinCode = corporateJoinCodeFrom(uri);
    if (joinCode != null && joinCode.isNotEmpty) {
      debugPrint('[deep_link] corporate join → code=$joinCode');
      nav.push(MaterialPageRoute(builder: (_) => CxJoinScreen(code: joinCode)));
      return;
    }
    final token = inviteTokenFrom(uri);
    if (token == null || token.isEmpty) {
      debugPrint('[deep_link] no invite/join token found in $uri');
      return;
    }
    debugPrint('[deep_link] booking invite → token=$token');
    nav.push(MaterialPageRoute(builder: (_) => GuestInviteScreen(token: token)));
  }
}
