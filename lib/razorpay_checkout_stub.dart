// Native (Android/iOS) implementation using the razorpay_flutter SDK.
// Opens Razorpay's native bottom sheet — handles UPI, GPay, PhonePe,
// cards, netbanking, wallets without any WebView or browser redirect.
import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_checkout.dart';

bool get razorpayClientSupportedImpl => true;

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
  final completer = Completer<RazorpayResult?>();
  final razorpay = Razorpay();

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
    if (!completer.isCompleted) {
      completer.complete(RazorpayResult(
        response.paymentId ?? '',
        response.orderId ?? orderId,
        response.signature ?? '',
      ));
    }
    razorpay.clear();
  });

  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
    if (!completer.isCompleted) completer.complete(null);
    razorpay.clear();
  });

  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
    if (!completer.isCompleted) completer.complete(null);
    razorpay.clear();
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
        'method': method, // pre-selects UPI/card on the native sheet
      },
      'theme': {'color': '#D6FD31'},
    });
  } catch (_) {
    razorpay.clear();
    if (!completer.isCompleted) completer.complete(null);
  }

  return completer.future;
}
