import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'app_nav.dart';
import 'screens/guest_invite.dart';

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

  void _handle(Uri uri) {
    final token = inviteTokenFrom(uri);
    if (token == null || token.isEmpty) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(builder: (_) => GuestInviteScreen(token: token)));
  }
}
