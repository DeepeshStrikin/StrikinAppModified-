// Native (Android/iOS) implementation using the razorpay_flutter SDK.
// Opens Razorpay's native bottom sheet — handles UPI, GPay, PhonePe,
// cards, netbanking, wallets without any WebView or browser redirect.
import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_checkout.dart';

bool get razorpayClientSupportedImpl => true;

// Held at module level so it's not garbage-collected before callbacks fire.
Razorpay? _activeRazorpay;
Completer<RazorpayResult?>? _activeCompleter;

void _cleanUp() {
  _activeRazorpay?.clear();
  _activeRazorpay = null;
  _activeCompleter = null;
}

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
}) async {
  // Cancel any previous checkout that didn't complete.
  if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
    _activeCompleter!.complete(null);
  }
  _cleanUp();

  final completer = Completer<RazorpayResult?>();
  _activeCompleter = completer;

  final razorpay = Razorpay();
  _activeRazorpay = razorpay; // keep alive until callbacks fire

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
    if (!completer.isCompleted) {
      completer.complete(RazorpayResult(
        response.paymentId ?? '',
        response.orderId ?? orderId,
        response.signature ?? '',
      ));
    }
    _cleanUp();
  });

  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
    if (!completer.isCompleted) completer.complete(null);
    _cleanUp();
  });

  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
    if (!completer.isCompleted) completer.complete(null);
    _cleanUp();
  });

  try {
    razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': 'Strikin',
      'description': description,
      'prefill': {
        'name': name,
        'email': email,
        'contact': contact,
        'method': method,
      },
      'theme': {'color': '#D6FD31'},
      'send_sms_hash': true,
      'remember_customer': false,
    });
  } catch (_) {
    _cleanUp();
    if (!completer.isCompleted) completer.complete(null);
  }

  return completer.future;
}
