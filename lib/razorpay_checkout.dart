// Cross-platform Razorpay checkout entry point.
// Web uses Razorpay's checkout.js (via JS interop); native mobile uses razorpay_flutter SDK.
// dart.library.html is only available on web, so this correctly switches implementations.
import 'razorpay_checkout_stub.dart'
    if (dart.library.html) 'razorpay_checkout_web.dart' as impl;

class RazorpayResult {
  final String paymentId;
  final String orderId;
  final String signature;
  RazorpayResult(this.paymentId, this.orderId, this.signature);
}

/// Opens Razorpay checkout. Resolves to the result on success, or null if the
/// user dismissed it or the platform can't open it.
/// [method] hint: 'upi', 'card', 'wallet' — pre-selects the payment method tab.
Future<RazorpayResult?> openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amountPaise,
  required String name,
  required String email,
  required String contact,
  String description = 'Strikin booking',
  String bookingId = '',
  String method = 'upi',
}) =>
    impl.openRazorpayCheckoutImpl(
      keyId: keyId,
      orderId: orderId,
      amountPaise: amountPaise,
      name: name,
      email: email,
      contact: contact,
      description: description,
      bookingId: bookingId,
      method: method,
    );

/// True if this platform can open Razorpay checkout right now (web only for now).
bool get razorpayClientSupported => impl.razorpayClientSupportedImpl;
