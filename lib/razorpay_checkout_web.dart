// Web implementation: opens Razorpay's hosted checkout via checkout.js (loaded in
// web/index.html). Supports UPI / GPay / PhonePe / cards / netbanking automatically.
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
import 'razorpay_checkout.dart';

bool get razorpayClientSupportedImpl => js.context.hasProperty('Razorpay');

Future<RazorpayResult?> openRazorpayCheckoutImpl({
  required String keyId,
  required String orderId,
  required int amountPaise,
  required String name,
  required String email,
  required String contact,
  String description = 'Strikin booking',
  String bookingId = '',
  String method = 'upi',
}) {
  final completer = Completer<RazorpayResult?>();

  if (!js.context.hasProperty('Razorpay')) {
    completer.complete(null);
    return completer.future;
  }

  final options = js.JsObject.jsify({
    'key': keyId,
    'order_id': orderId,
    'amount': amountPaise,
    'currency': 'INR',
    'name': 'Strikin',
    'description': description,
    'prefill': {'name': name, 'email': email, 'contact': contact},
    'theme': {'color': '#D6FD31'},
    'redirect': false,
  });

  // Success handler — Razorpay passes payment_id / order_id / signature.
  // (Legacy dart:js auto-wraps Dart closures stored into JS objects.)
  options['handler'] = (resp) {
    final r = resp as js.JsObject;
    if (!completer.isCompleted) {
      completer.complete(RazorpayResult(
        r['razorpay_payment_id'] as String,
        r['razorpay_order_id'] as String,
        r['razorpay_signature'] as String,
      ));
    }
  };

  // Dismiss handler — user closed the modal without paying.
  options['modal'] = js.JsObject.jsify({});
  (options['modal'] as js.JsObject)['ondismiss'] = () {
    if (!completer.isCompleted) completer.complete(null);
  };

  final rzp = js.JsObject(js.context['Razorpay'] as js.JsFunction, [options]);
  rzp.callMethod('open');
  return completer.future;
}
