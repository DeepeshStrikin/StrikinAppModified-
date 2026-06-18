import 'package:flutter/widgets.dart';

/// Global navigator key so non-widget code (e.g. the payment WebView launcher)
/// can push routes without a BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();
