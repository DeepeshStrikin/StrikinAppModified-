import 'package:flutter/widgets.dart';

/// Global navigator key so non-widget code (e.g. the payment WebView launcher)
/// can push routes without a BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();

/// Lets a screen refresh itself when the user returns to it after a pushed
/// flow (e.g. the corporate dashboard re-fetching the wallet after a booking).
final routeObserver = RouteObserver<ModalRoute<void>>();
