import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'models.dart';
import 'mock.dart';

/// API client. Base URL precedence:
///   1. --dart-define=API_URL=...  (explicit override, used for release APKs)
///   2. On web: same host the app is served from, port 8000 (survives IP changes)
///   3. Fallback LAN IP for native dev.
/// Falls back to bundled mock data when the backend is unreachable, so the app
/// is always demoable.
class Api {
  static final String baseUrl = _resolveBaseUrl();
  // Browsing falls back to bundled data after this (keeps the UI snappy).
  static const _timeout = Duration(seconds: 8);
  // Writes (booking, invite, payment) must reach the server — wait longer so they
  // never silently fall back to a fake local result.
  static const _writeTimeout = Duration(seconds: 25);
  // Payment operations need extra time — backend retries Razorpay up to 3x
  static const _paymentTimeout = Duration(seconds: 75);

  /// On web, route images through the backend proxy (fixes CORS). On native
  /// (Android/iOS) load them directly — no proxy, so images don't depend on the
  /// backend tunnel being reachable.
  static String img(String url) =>
      kIsWeb ? '$baseUrl/img?u=${Uri.encodeComponent(url)}' : url;

  static String _resolveBaseUrl() {
    const override = String.fromEnvironment('API_URL', defaultValue: '');
    if (override.isNotEmpty) return override;
    if (kIsWeb) {
      final b = Uri.base;
      // In dev the Flutter web server runs on a random port. API is always on 8000.
      if (b.host == 'localhost' || b.host == '127.0.0.1') {
        return 'http://localhost:8000';
      }
      // Production: same-origin (backend serves the app).
      return b.origin;
    }
    return 'http://192.168.1.26:8000';
  }

  static Future<T> _get<T>(String path, T fallback, T Function(dynamic) parse) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl$path')).timeout(_timeout);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      return parse(jsonDecode(res.body));
    } catch (_) {
      return fallback;
    }
  }

  static Future<T> _post<T>(String path, Map body, T fallback, T Function(dynamic) parse,
      {Duration? timeout}) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl$path'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout ?? _timeout);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      return parse(jsonDecode(res.body));
    } catch (_) {
      return fallback;
    }
  }

  static Future<List<ActivityType>> getActivities() => _get(
        '/activities',
        mockActivities,
        (d) => (d as List).map((e) => ActivityType.fromJson(e)).toList(),
      );

  static Future<List<Bay>> getBays(String activityId) => _get(
        '/activities/$activityId/bays',
        mockBays[activityId] ?? [],
        (d) => (d as List).map((e) => Bay.fromJson(e)).toList(),
      );

  static Future<List<Slot>> getSlots(String bayId, String date) => _get(
        '/bays/$bayId/slots?date=$date',
        mockSlots,
        (d) => (d as List).map((e) => Slot.fromJson(e)).toList(),
      );

  static Future<List<FoodItem>> getFood() => _get(
        '/food',
        mockFood,
        (d) => (d as List).map((e) => FoodItem.fromJson(e)).toList(),
      );

  static Future<Map<String, dynamic>> requestOtp(String email) => _post(
        '/auth/otp/request',
        {'email': email, 'purpose': 'login'},
        {'sent': true},
        (d) => Map<String, dynamic>.from(d),
      );

  static Future<bool> submitInquiry({
    required String companyName,
    required String email,
    String contactName = '',
    String phone = '',
    String licenseNo = '',
    String gstNo = '',
  }) =>
      _post<bool>(
        '/corporate/inquiries',
        {
          'company_name': companyName,
          'email': email,
          'contact_name': contactName,
          'phone': phone,
          'license_no': licenseNo,
          'gst_no': gstNo,
        },
        true,
        (d) => d['id'] != null,
      );

  static Future<bool> verifyOtp(String email, String code) => _post<bool>(
        '/auth/otp/verify',
        {'email': email, 'code': code},
        RegExp(r'^\d{6}$').hasMatch(code),
        (d) => d['verified'] == true,
      );

  /// Whether real Razorpay checkout is configured on the backend, plus the public key id.
  static Future<Map<String, dynamic>> paymentsConfig() => _get(
        '/payments/config',
        {'razorpay_enabled': false, 'key_id': ''},
        (d) => Map<String, dynamic>.from(d),
      );

  /// Create a Razorpay order for a booking. Returns {id, amount, ...} or null.
  static Future<Map<String, dynamic>?> createRazorpayOrder(double amount, String bookingId) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/payments/razorpay/order'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'amount': amount, 'booking_id': bookingId}))
          .timeout(_paymentTimeout); // longer timeout — backend retries up to 3x
      if (res.statusCode != 200) return null;
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {
      return null;
    }
  }

  /// Verify a Razorpay payment signature server-side; confirms the booking. Returns true if verified.
  static Future<bool> verifyPayment({
    required String bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/payments/razorpay/verify'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'booking_id': bookingId,
                'razorpay_order_id': orderId,
                'razorpay_payment_id': paymentId,
                'razorpay_signature': signature,
              }))
          .timeout(_writeTimeout);
      if (res.statusCode != 200) return false;
      return jsonDecode(res.body)['verified'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Create a shareable invite for a booking. Returns the invite token, or null on failure.
  static Future<String?> createInvite(String bookingId) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/bookings/$bookingId/invite'),
              headers: {'Content-Type': 'application/json'})
          .timeout(_writeTimeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body)['token'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Public URL of the customer WEB app (Netlify), used for shareable invite links.
  /// Build with --dart-define=WEB_URL=https://your-web-app.netlify.app
  static const _webUrl = String.fromEnvironment('WEB_URL', defaultValue: '');

  /// Build the shareable link a host sends to guests. It must open the customer
  /// web app (not the API), so guests see the booking + add their food.
  static String inviteLink(String token) {
    if (kIsWeb) return '${Uri.base.origin}/?invite=$token';
    if (_webUrl.isNotEmpty) return '$_webUrl/?invite=$token';
    return '$baseUrl/?invite=$token'; // fallback (points at API — set WEB_URL to fix)
  }

  /// Full booking details (host + guest food) for the Booking Summary screen.
  static Future<Map<String, dynamic>?> bookingDetails(String bookingId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/bookings/$bookingId/details')).timeout(_writeTimeout);
      if (res.statusCode != 200) return null;
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {
      return null;
    }
  }

  /// Cancel a booking (frees the slot). Returns true on success.
  static Future<bool> cancelBooking(String bookingId) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
              headers: {'Content-Type': 'application/json'})
          .timeout(_writeTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<InviteBooking?> getInvite(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/invites/$token')).timeout(_writeTimeout);
      if (res.statusCode != 200) return null;
      return InviteBooking.fromJson(jsonDecode(res.body));
    } catch (_) {
      return null;
    }
  }

  /// Add a guest's food to a booking. When paying online, pass the Razorpay proof.
  /// Returns the updated booking view, or null on failure (e.g. payment required/invalid).
  static Future<InviteBooking?> addGuestFood(
    String token,
    String guestName,
    List<CartFood> food, {
    String orderId = '',
    String paymentId = '',
    String signature = '',
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/invites/$token/food'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'guest_name': guestName,
                'food': food.map((f) => {'item_id': f.item.id, 'quantity': f.quantity}).toList(),
                'razorpay_order_id': orderId,
                'razorpay_payment_id': paymentId,
                'razorpay_signature': signature,
              }))
          .timeout(_writeTimeout);
      if (res.statusCode != 200) return null;
      return InviteBooking.fromJson(jsonDecode(res.body));
    } catch (_) {
      return null;
    }
  }

  static Future<BookingResult> createBooking({
    required String activityId,
    required List<Bay> bays,
    required String date,
    required String time,
    required int players,
    required List<CartFood> food,
    String guestName = '',
    String guestPhone = '',
    String bookingType = 'b2c',
    bool payOnline = false,
  }) {
    final foodTotal = food.fold<double>(0, (s, f) => s + f.item.price * f.quantity);
    final bayTotal = bays.fold<double>(0, (s, b) => s + b.pricePerSession);
    final total = bayTotal + foodTotal;
    final fallback = BookingResult(
      id: 'BK${100000 + (DateTime.now().millisecondsSinceEpoch % 900000)}',
      qrCode: 'STRIKIN-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      pin: '${1000 + (DateTime.now().millisecond % 9000)}',
      status: 'upcoming',
      totalAmount: total,
      loyaltyEarned: (total * 0.05).round(),
    );
    return _post(
      '/bookings',
      {
        'activity_id': activityId,
        'bay_id': bays.isNotEmpty ? bays.first.id : '',
        'bay_ids': bays.map((b) => b.id).toList(),
        'date': date,
        'time': time,
        'players': players,
        'guest_name': guestName,
        'guest_phone': guestPhone,
        'booking_type': bookingType,
        'pay_online': payOnline,
        'food': food.map((f) => {'item_id': f.item.id, 'quantity': f.quantity}).toList(),
      },
      fallback,
      (d) => BookingResult.fromJson(d),
      timeout: _writeTimeout,
    );
  }
}
