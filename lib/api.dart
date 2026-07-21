import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'models.dart';
import 'mock.dart';

/// Thrown when the vendor backend returns an error envelope ({success:false}).
/// [code] is the backend error code (e.g. NOT_FOUND, CONFLICT, BAD_REQUEST),
/// [message] is the user-facing message, [status] the HTTP status code.
class ApiException implements Exception {
  final String code;
  final String message;
  final int status;
  ApiException(this.code, this.message, this.status);
  @override
  String toString() => message;
}

/// API client for the vendor backend (rms-master) REST API at `<origin>/api/v1`.
///
/// Differences from the old FastAPI backend this replaced:
///  - every response is wrapped `{success, data, error, meta}` — we unwrap `.data`.
///  - authenticated calls send `Authorization: Bearer <token>` (token from AuthState).
///  - booking requires the slot to be locked first (lock → book → pay → verify).
///
/// Base URL precedence:
///   1. --dart-define=API_URL=...   (full origin or origin+/api/v1; used for release/devices)
///   2. web on localhost            → http://localhost:3000
///   3. native dev default          → http://localhost:3000 (pass API_URL for real devices)
class Api {
  /// App origin (scheme://host[:port]) WITHOUT the /api/v1 suffix — used for assets.
  static final String _origin = _resolveOrigin();

  /// REST API base, e.g. http://localhost:3000/api/v1
  static String get baseUrl => '$_origin/api/v1';

  /// Razorpay public key for opening checkout on the client.
  /// Pass with --dart-define=RAZORPAY_KEY_ID=rzp_test_xxx (required for payments).
  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: '');
  static bool get razorpayConfigured => razorpayKeyId.isNotEmpty;

  // Browsing falls back to bundled data after this (keeps the UI snappy).
  static const _timeout = Duration(seconds: 8);
  // Writes (booking, invite) must reach the server — wait longer.
  static const _writeTimeout = Duration(seconds: 25);
  // Payment operations need extra time.
  static const _paymentTimeout = Duration(seconds: 75);

  /// Public URL of the customer WEB app, used for shareable invite links.
  /// Build with --dart-define=WEB_URL=https://your-web-app
  static const _webUrl = String.fromEnvironment('WEB_URL', defaultValue: '');

  static String _resolveOrigin() {
    const override = String.fromEnvironment('API_URL', defaultValue: '');
    if (override.isNotEmpty) {
      var o = override.trim();
      if (o.endsWith('/')) o = o.substring(0, o.length - 1);
      if (o.endsWith('/api/v1')) o = o.substring(0, o.length - '/api/v1'.length);
      return o;
    }
    if (kIsWeb) {
      final b = Uri.base;
      if (b.host == 'localhost' || b.host == '127.0.0.1') return 'http://localhost:3000';
      // Production web: assume same-origin (reverse-proxied). Override with API_URL otherwise.
      return '${b.scheme}://${b.host}${b.hasPort ? ':${b.port}' : ''}';
    }
    // Native dev default. For a physical device pass --dart-define=API_URL=http://<pc-ip>:3000
    return 'http://localhost:3000';
  }

  /// Resolve an image URL. Vendor assets are relative paths (e.g. /activities/x.webp)
  /// served from the app origin; absolute URLs are used as-is.
  static String img(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http')) return url;
    return '$_origin$url';
  }

  // ── Core request plumbing ──────────────────────────────────────────────────

  static Map<String, String> _headers({bool jsonBody = false}) {
    final t = AuthState.instance.user?.token;
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  /// Unwraps the vendor envelope. Returns `data` on success; throws [ApiException]
  /// on an error envelope. A 401 clears the local session (token expired/invalid).
  static dynamic _unwrap(http.Response res) {
    dynamic body;
    try {
      body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.statusCode == 204) return null;
      if (body is Map && body['success'] == true) return body['data'];
      // Some endpoints may return a bare body — pass it through.
      if (body is! Map || !body.containsKey('success')) return body;
    }
    var code = 'ERROR';
    var msg = 'Request failed (HTTP ${res.statusCode})';
    if (body is Map && body['error'] is Map) {
      code = (body['error']['code'] ?? code).toString();
      msg = (body['error']['message'] ?? msg).toString();
    }
    if (res.statusCode == 401 && AuthState.instance.user?.token != null) {
      AuthState.instance.logout(); // fire-and-forget — drop the expired session
    }
    throw ApiException(code, msg, res.statusCode);
  }

  static Future<dynamic> _get(String path, {Duration? timeout}) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers()).timeout(timeout ?? _timeout);
    return _unwrap(res);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    final res = await http
        .post(Uri.parse('$baseUrl$path'), headers: _headers(jsonBody: true), body: jsonEncode(body))
        .timeout(timeout ?? _writeTimeout);
    return _unwrap(res);
  }

  static Future<dynamic> _delete(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    final res = await http
        .delete(Uri.parse('$baseUrl$path'), headers: _headers(jsonBody: true), body: jsonEncode(body))
        .timeout(timeout ?? _writeTimeout);
    return _unwrap(res);
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    final res = await http
        .patch(Uri.parse('$baseUrl$path'), headers: _headers(jsonBody: true), body: jsonEncode(body))
        .timeout(timeout ?? _writeTimeout);
    return _unwrap(res);
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Build the auth body key for an identifier — `email` if it looks like an
  /// email, otherwise `phone`. The vendor auth endpoints accept `email || phone`.
  static Map<String, String> _idField(String identifier) =>
      identifier.contains('@') ? {'email': identifier} : {'phone': identifier};

  /// Request a login OTP for an EXISTING account. [identifier] is an email or a
  /// 10-digit mobile number (OTP goes by email or SMS accordingly). Throws
  /// ApiException('NOT_FOUND') if no account exists (caller switches to register).
  static Future<void> requestLoginOtp(String identifier) async {
    await _post('/auth/login', _idField(identifier));
  }

  /// Verify a login OTP. Returns {token, role, fullName, requiresAccountSelection, accounts?}.
  static Future<Map<String, dynamic>> loginVerify(String identifier, String otp) async {
    final d = await _post('/auth/login/verify', {..._idField(identifier), 'otp': otp});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Finalise login when a phone has multiple accounts. Returns {token, role, fullName}.
  static Future<Map<String, dynamic>> selectAccount(String phone, String userId) async {
    final d = await _post('/auth/login/select-account', {'phone': phone, 'userId': userId});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Register a NEW account. A phone is always required; email + dateOfBirth are
  /// optional. The verification OTP is sent by email if an email is given,
  /// otherwise by SMS to the phone.
  static Future<void> register({
    required String fullName,
    required String phone,
    String? email,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    await _post('/auth/register', {
      'fullName': fullName,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
      if (gender != null && gender.isNotEmpty) 'gender': gender,
    });
  }

  /// Verify the registration OTP. [identifier] is whatever the OTP was sent to
  /// (email if one was given at signup, otherwise the phone). Returns {token, role, fullName}.
  static Future<Map<String, dynamic>> verifyRegisterOtp(String identifier, String otp) async {
    // The verify-otp route reads the `email` key but the service treats it as a
    // generic identifier (email or phone), so pass whichever was registered.
    final d = await _post('/auth/verify-otp', {'email': identifier, 'otp': otp});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Resend a login OTP. [identifier] is an email or a 10-digit mobile number.
  static Future<void> resendLoginOtp(String identifier) async {
    await _post('/auth/resend-otp', _idField(identifier));
  }

  /// Fetch the admin-managed Terms & Conditions + Disclaimer. Returns {terms, disclaimer, updatedAt}.
  static Future<Map<String, dynamic>> getTerms() async {
    final d = await _get('/legal/terms');
    return Map<String, dynamic>.from(d as Map);
  }

  /// Fetch active GST rates as fractions keyed by service category
  /// (e.g. {'bay_booking': 0.18, 'food_restaurant': 0.05}). For display only —
  /// the real charge is computed server-side.
  static Future<Map<String, double>> getTaxRates() async {
    final d = await _get('/tax-config/rates');
    final list = (d as List?) ?? [];
    final map = <String, double>{};
    for (final item in list) {
      final m = Map<String, dynamic>.from(item as Map);
      final cat = m['serviceCategory']?.toString();
      final pct = double.tryParse('${m['gstRatePercent']}') ?? 0;
      if (cat != null) map[cat] = pct / 100.0;
    }
    return map;
  }

  /// Create an anonymous guest session (name + phone required; gender + DOB optional).
  /// Returns {guestSessionId, token}.
  static Future<Map<String, dynamic>> guestSession({
    required String fullName,
    required String phone,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    final d = await _post('/auth/guest', {
      'fullName': fullName,
      'phone': phone,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
      if (gender != null && gender.isNotEmpty) 'gender': gender,
    });
    return Map<String, dynamic>.from(d as Map);
  }

  /// Move a guest's bookings onto the current (real) account after registering.
  /// Call once logged in as the new account. Returns the number of bookings claimed.
  static Future<int> claimGuestBookings(String guestSessionId) async {
    try {
      final d = await _post('/auth/claim-guest-bookings', {'guestSessionId': guestSessionId});
      final m = Map<String, dynamic>.from(d as Map);
      return (m['claimed'] is num) ? (m['claimed'] as num).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Fetch the current user's profile (validates the stored token). Returns null on network error.
  static Future<Map<String, dynamic>?> authMe() async {
    try {
      final d = await _get('/auth/me');
      return Map<String, dynamic>.from(d as Map);
    } on ApiException {
      rethrow; // 401 handled by _unwrap (clears session); caller may ignore
    } catch (_) {
      return null;
    }
  }

  /// Update the current user's editable profile. Returns the updated profile map.
  /// Pass [clearDob] to remove the stored date of birth.
  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
    String? dateOfBirth,
    String? gender,
    bool clearDob = false,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (clearDob) {
      body['dateOfBirth'] = null;
    } else if (dateOfBirth != null) {
      body['dateOfBirth'] = dateOfBirth;
    }
    if (gender != null && gender.isNotEmpty) body['gender'] = gender;
    final d = await _patch('/auth/me', body);
    return Map<String, dynamic>.from(d as Map);
  }

  /// Step 1 of a phone/email change: send an OTP to the NEW value.
  /// [field] is 'phone' or 'email'. Throws ApiException on invalid/duplicate.
  static Future<void> requestContactChangeOtp(String field, String value) async {
    await _post('/auth/me/contact/request', {'field': field, 'value': value});
  }

  /// Step 2: verify the OTP and apply the change. Returns the updated profile map.
  static Future<Map<String, dynamic>> verifyContactChangeOtp(String field, String value, String otp) async {
    final d = await _post('/auth/me/contact/verify', {'field': field, 'value': value, 'otp': otp});
    return Map<String, dynamic>.from(d as Map);
  }

  // ── Notifications ────────────────────────────────────────────────────────────

  /// In-app notification feed for the current user. Returns {items:[...], unreadCount:int}.
  static Future<Map<String, dynamic>> getNotifications({int limit = 50, bool unreadOnly = false}) async {
    final d = await _get('/notifications?limit=$limit${unreadOnly ? '&unreadOnly=true' : ''}');
    return Map<String, dynamic>.from(d as Map);
  }

  /// Number of unread in-app notifications (0 on any error — safe for a badge).
  static Future<int> unreadNotificationCount() async {
    try {
      final d = await getNotifications(limit: 1, unreadOnly: false);
      return (d['unreadCount'] is num) ? (d['unreadCount'] as num).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Mark notifications read. Pass [ids] to mark specific ones; omit to mark all. Returns the new unread count.
  static Future<int> markNotificationsRead({List<String>? ids}) async {
    final d = await _post('/notifications/read', {if (ids != null) 'ids': ids});
    final m = Map<String, dynamic>.from(d as Map);
    return (m['unreadCount'] is num) ? (m['unreadCount'] as num).toInt() : 0;
  }

  // ── Theatre / Mega Screen ────────────────────────────────────────────────

  /// Upcoming shows for a screen-type activity (Mega Screen). Empty on error.
  static Future<List<Show>> getShows(String activityId) async {
    try {
      final d = await _get('/attractions/$activityId/shows');
      final list = (d is Map ? (d['shows'] as List?) : (d as List?)) ?? const [];
      return list.map((e) => Show.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  /// The seat map for a show (every seat + per-seat price + availability). Null on error.
  static Future<ShowSeatMap?> getShowSeats(String showId) async {
    try {
      final d = await _get('/shows/$showId/seats');
      return ShowSeatMap.fromJson(Map<String, dynamic>.from(d as Map));
    } catch (_) {
      return null;
    }
  }

  /// Book seats for a show. Requires a session token (guests use their guest session).
  /// Returns {bookingId, amount, holdExpiresAt, seatLabels, show}. Throws [ApiException] on conflict.
  static Future<Map<String, dynamic>> bookShowSeats(String showId, List<String> seatIds,
      {String paymentMethod = 'upi'}) async {
    final d = await _post(
      '/shows/$showId/book',
      {'seatIds': seatIds, 'paymentMethod': paymentMethod},
      timeout: _writeTimeout,
    );
    return Map<String, dynamic>.from(d as Map);
  }

  /// Release a theatre booking's held seats (payment cancelled/failed). Best-effort.
  static Future<void> releaseShowSeats(String bookingId) async {
    try {
      await _post('/bookings/$bookingId/release-seats', {});
    } catch (_) {
      // Ignore — the 8-minute hold will auto-expire anyway.
    }
  }

  // ── Browse (reads — fall back to bundled mock data when offline) ────────────

  static Future<List<ActivityType>> getActivities() async {
    try {
      final d = await _get('/attractions');
      return (d as List).map((e) => ActivityType.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return mockActivities;
    }
  }

  /// Bays for an activity. Uses the dated endpoint so we get tier prices +
  /// allowBaySelect, flattened into a list of [Bay]. [date] is informational for
  /// pricing (date-independent); defaults to today.
  static Future<List<Bay>> getBays(String activityId, {String? date}) async {
    final d = date ?? _todayIso();
    try {
      final data = await _get('/attractions/$activityId/bays?date=$d');
      final bays = _flattenTierGroups(activityId, data);
      if (bays.isNotEmpty) return bays;
      return mockBays[activityId] ?? [];
    } catch (_) {
      return mockBays[activityId] ?? [];
    }
  }

  static Future<List<Slot>> getSlots(String bayId, String date) async {
    try {
      final d = await _get('/bays/$bayId/slots?date=$date');
      return (d as List).map((e) => Slot.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return mockSlots;
    }
  }

  static Future<List<FoodItem>> getFood() async {
    try {
      final d = await _get('/food/menu');
      final items = _flattenMenu(d);
      if (items.isNotEmpty) return items;
      return mockFood;
    } catch (_) {
      return mockFood;
    }
  }

  static List<Bay> _flattenTierGroups(String activityId, dynamic data) {
    final groups = (data is Map) ? data['tierGroups'] : null;
    if (groups is! List) return [];
    final out = <Bay>[];
    for (final g in groups) {
      if (g is! Map) continue;
      final tierSlug = (g['slug'] ?? g['name'] ?? 'standard').toString();
      final tierPrice = toDouble(g['pricePerSession']);
      final allowSel = (g['allowBaySelect'] ?? true) == true;
      final bays = g['bays'];
      if (bays is! List) continue;
      for (final b in bays) {
        if (b is! Map) continue;
        out.add(Bay(
          id: b['id'].toString(),
          activityTypeId: activityId,
          name: (b['name'] ?? '').toString(),
          bayTier: tierSlug,
          pricePerSession: b['pricePerSession'] != null ? toDouble(b['pricePerSession']) : tierPrice,
          maxPlayers: ((b['maxPlayers'] ?? 6) as num).toInt(),
          description: (b['description'] ?? '').toString(),
          image: firstImage(b['images']),
          allowSelect: allowSel,
        ));
      }
    }
    return out;
  }

  static List<FoodItem> _flattenMenu(dynamic data) {
    final cats = (data is Map) ? data['categories'] : null;
    if (cats is! List) return [];
    final out = <FoodItem>[];
    for (final c in cats) {
      if (c is! Map) continue;
      final cname = (c['name'] ?? 'Food').toString();
      final items = c['items'];
      if (items is! List) continue;
      for (final it in items) {
        if (it is! Map) continue;
        out.add(FoodItem.fromJson({...Map<String, dynamic>.from(it), 'category': cname}));
      }
    }
    return out;
  }

  // ── Slot locking (required before booking) ──────────────────────────────────

  /// Lock a (bay, date, time) slot for this session. Returns {locked, expiresAt, lockKey}.
  /// Throws ApiException('CONFLICT') if the slot is already locked/taken.
  static Future<Map<String, dynamic>> lockSlot(String bayId, String date, String time) async {
    final d = await _post('/slots/lock', {'bayId': bayId, 'date': date, 'time': time});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Release a previously held slot lock (best-effort).
  static Future<void> releaseSlot(String bayId, String date, String time) async {
    try {
      await _delete('/slots/lock', {'bayId': bayId, 'date': date, 'time': time});
    } catch (_) {/* best-effort */}
  }

  // ── Booking ─────────────────────────────────────────────────────────────────

  /// Create a booking. Requires the slots to already be locked by this session.
  /// [bays] all share the chosen [date]/[time]. itemAmount is PRE-tax (the server
  /// adds GST and returns the authoritative totalAmount). Throws ApiException.
  /// Validate a coupon against a gross amount. Returns {offerId, discountAmount, finalAmount, ...}.
  /// Throws ApiException with a user-facing message if the code is invalid/expired/etc.
  static Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required double bookingAmount,
    String? bookingType,
    List<String>? activityTypeIds,
  }) async {
    final d = await _post('/coupons/validate', {
      'code': code,
      'bookingAmount': bookingAmount,
      if (bookingType != null) 'bookingType': bookingType,
      if (activityTypeIds != null && activityTypeIds.isNotEmpty) 'activityTypeIds': activityTypeIds,
    });
    return Map<String, dynamic>.from(d as Map);
  }

  static Future<BookingResult> createBooking({
    required List<Bay> bays,
    required String date,
    required String time,
    required int players,
    required List<CartFood> food,
    String paymentMethod = 'upi',
    String? offerId,
    double? discountAmount,
  }) async {
    final items = <Map<String, dynamic>>[];
    final n = bays.length;
    final per = n == 0 ? players : (players / n).floor();
    final extra = players - per * n;
    for (var i = 0; i < n; i++) {
      var np = per + (i < extra ? 1 : 0);
      if (np < 1) np = 1;
      items.add({
        'bayId': bays[i].id,
        'numPlayers': np,
        'itemAmount': bays[i].pricePerSession,
        'slotDate': date,
        'slotTime': time,
      });
    }
    final foodOrders = food
        .map((f) => {
              'restroworksItemId': f.item.id,
              'restroworksItemName': f.item.name,
              'restroworksItemPrice': f.item.price,
              'quantity': f.quantity,
              'itemTotal': f.item.price * f.quantity,
            })
        .toList();

    final d = await _post(
      '/bookings',
      {
        'items': items,
        if (foodOrders.isNotEmpty) 'foodOrders': foodOrders,
        'bookingDate': date,
        'paymentMethod': paymentMethod,
        if (offerId != null && offerId.isNotEmpty) 'offerId': offerId,
        if (discountAmount != null && discountAmount > 0) 'discountAmount': discountAmount,
      },
      timeout: _writeTimeout,
    );
    return BookingResult.fromJson(Map<String, dynamic>.from(d as Map));
  }

  /// Multi-activity booking: send prebuilt [items] (one entry per bay across
  /// every activity) and [foodOrders] in a single /bookings order. Used by the
  /// multi-activity cart so all configured activities are paid together.
  static Future<BookingResult> createBookingItems({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> foodOrders,
    required String bookingDate,
    String paymentMethod = 'upi',
    String? offerId,
    double? discountAmount,
    int? loyaltyPoints,
    String? idempotencyKey,
  }) async {
    final d = await _post(
      '/bookings',
      {
        'items': items,
        if (foodOrders.isNotEmpty) 'foodOrders': foodOrders,
        'bookingDate': bookingDate,
        'paymentMethod': paymentMethod,
        if (offerId != null && offerId.isNotEmpty) 'offerId': offerId,
        if (discountAmount != null && discountAmount > 0) 'discountAmount': discountAmount,
        if (loyaltyPoints != null && loyaltyPoints > 0) 'loyaltyPoints': loyaltyPoints,
        if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'idempotencyKey': idempotencyKey,
      },
      timeout: _writeTimeout,
    );
    return BookingResult.fromJson(Map<String, dynamic>.from(d as Map));
  }

  /// Initiate payment for a booking. Returns {orderId, amount (rupees), requiresCheckout}.
  static Future<Map<String, dynamic>?> initiatePayment(String bookingId, double amountRupees, {String method = 'upi'}) async {
    try {
      final d = await _post(
        '/bookings/$bookingId/payment',
        {'paymentMethod': method, 'amount': amountRupees},
        timeout: _paymentTimeout,
      );
      return Map<String, dynamic>.from(d as Map);
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// The reason the last [verifyPayment] failed (for showing the user why).
  static String? lastPaymentError;

  /// Verify a Razorpay payment + confirm the booking. Returns true on success.
  /// On failure, [lastPaymentError] holds the server's reason.
  static Future<bool> verifyPayment({
    required String bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    lastPaymentError = null;
    try {
      final d = await _post('/bookings/$bookingId/payment/verify', {
        'razorpayPaymentId': paymentId,
        'razorpayOrderId': orderId,
        'razorpaySignature': signature,
      });
      final ok = d is Map && d['success'] == true;
      if (!ok) lastPaymentError = 'The server did not confirm the payment.';
      return ok;
    } on ApiException catch (e) {
      lastPaymentError = e.message; // e.g. invalid signature, slot conflict
      return false;
    } catch (_) {
      lastPaymentError = 'Network error while verifying payment.';
      return false;
    }
  }

  /// Fetch the QR code for a confirmed booking. Returns the QR payload string or ''.
  static Future<String> getQr(String bookingId) async {
    try {
      final d = await _get('/bookings/$bookingId/qr');
      return (d is Map ? (d['qrCode'] ?? '') : '').toString();
    } catch (_) {
      return '';
    }
  }

  /// Server-side booking history (confirmed bookings only). Returns raw maps.
  static Future<List<Map<String, dynamic>>> listBookings() async {
    try {
      final d = await _get('/bookings/list');
      return (d as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Full booking detail (host + items + food). Returns the vendor booking map.
  static Future<Map<String, dynamic>?> bookingDetails(String bookingId) async {
    try {
      final d = await _get('/bookings/$bookingId');
      return Map<String, dynamic>.from(d as Map);
    } catch (_) {
      return null;
    }
  }

  /// Cancel a booking (only `upcoming` bookings). Returns true on success.
  static Future<bool> cancelBooking(String bookingId) async {
    try {
      final d = await _post('/bookings/$bookingId/cancel', {});
      return d is Map ? d['success'] == true : true;
    } catch (_) {
      return false;
    }
  }

  // ── Invites (host) ───────────────────────────────────────────────────────────

  /// Create a guest invite for a booking. Returns the invite token, or null on failure.
  /// guestsMustPayForFood defaults to TRUE so invited guests pay for their own food
  /// (they're taken to Razorpay checkout after adding items).
  static Future<String?> createInvite(String bookingId, {int maxPlayers = 10, bool guestsMustPayForFood = true}) async {
    try {
      final d = await _post('/bookings/$bookingId/invite', {
        'maxPlayers': maxPlayers,
        'guestsMustPayForFood': guestsMustPayForFood,
      });
      if (d is Map) return (d['inviteToken'] ?? d['token'])?.toString();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Build the shareable link a host sends to guests. Prefers the Strikin WEB
  /// build (same UI as the app — `main.dart` routes `?invite=<token>` to the
  /// guest screen). Falls back to the backend's own `/join/<token>` page if no
  /// web build is hosted (set with `--dart-define=WEB_URL=https://…`).
  static String inviteLink(String token) {
    if (kIsWeb) return '${Uri.base.origin}/?invite=$token';
    if (_webUrl.isNotEmpty) return '$_webUrl/?invite=$token';
    return '$_origin/join/$token';
  }

  /// A native deep link that opens the installed Strikin app directly
  /// (handled by the app's deep-link router → guest invite screen).
  static String inviteDeepLink(String token) => 'strikin://join/$token';

  /// The message to share with guests: the universal web link (opens in a
  /// browser, or the app once the domain is App-Links-verified) plus the app
  /// deep link (opens the installed app straight away).
  static String inviteShareMessage(String token) =>
      'Join my Strikin booking! View it and add your food:\n${inviteLink(token)}\n\nHave the Strikin app? Open it directly: ${inviteDeepLink(token)}';

  // ── Invites (guest-facing) ────────────────────────────────────────────────────

  /// Read an invite (public). Returns the booking view a guest sees.
  static Future<InviteBooking?> getInvite(String token) async {
    try {
      final d = await _get('/join/$token');
      return InviteBooking.fromJson(Map<String, dynamic>.from(d as Map));
    } catch (_) {
      return null;
    }
  }

  /// Guest joins an invite. Returns the inviteJoinId (used for adding food / paying).
  static Future<String?> joinInvite(String token, {required String name, required String phone, String? email}) async {
    try {
      final d = await _post('/join/$token', {
        'name': name,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      if (d is Map) return (d['inviteJoinId'] ?? d['id'])?.toString();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Add one food item to a guest's join (call once per cart line).
  static Future<bool> addJoinFood(String token, String inviteJoinId, FoodItem item, int quantity) async {
    try {
      await _post('/join/$token/food', {
        'inviteJoinId': inviteJoinId,
        'restroworksItemId': item.id,
        'restroworksItemName': item.name,
        'restroworksItemPrice': item.price,
        'quantity': quantity,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Initiate a guest's own food payment. Returns {razorpayOrderId, amount, ...} or null.
  static Future<Map<String, dynamic>?> joinPaymentInitiate(String token, String inviteJoinId, double amountRupees) async {
    try {
      final d = await _post('/join/$token/payment', {
        'inviteJoinId': inviteJoinId,
        'method': 'upi',
        'amount': amountRupees,
      }, timeout: _paymentTimeout);
      return Map<String, dynamic>.from(d as Map);
    } catch (_) {
      return null;
    }
  }

  /// Verify a guest's food payment.
  static Future<bool> joinPaymentVerify(String token, String inviteJoinId,
      {required String paymentId, required String orderId, required String signature}) async {
    try {
      final d = await _post('/join/$token/payment/verify', {
        'inviteJoinId': inviteJoinId,
        'razorpayPaymentId': paymentId,
        'razorpayOrderId': orderId,
        'razorpaySignature': signature,
      });
      return d is Map ? d['success'] == true : true;
    } catch (_) {
      return false;
    }
  }

  // ── Booking lifecycle: game details / invite mgmt / guest food ────────────────

  /// Rich game details: per-activity breakdown + players + their food + paid/unpaid + unpaidTotal.
  static Future<Map<String, dynamic>?> gameDetails(String bookingId, {String? bookingItemId}) async {
    try {
      final q = bookingItemId != null ? '?bookingItemId=$bookingItemId' : '';
      final d = await _get('/bookings/$bookingId/game-details$q');
      return Map<String, dynamic>.from(d as Map);
    } catch (_) {
      return null;
    }
  }

  /// All active invites for a booking: [{inviteToken, inviteLink, maxPlayers, joinedCount, status, guestsMustPayForFood, ...}].
  static Future<List<Map<String, dynamic>>> listInvites(String bookingId) async {
    try {
      final d = await _get('/bookings/$bookingId/invites');
      return (d as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Regenerate the invite link (invalidates the previous one). Returns the new {inviteToken, inviteLink, ...}.
  static Future<Map<String, dynamic>?> regenerateInvite(String bookingId) async {
    try {
      final d = await _post('/bookings/$bookingId/invite/regenerate', {});
      return Map<String, dynamic>.from(d as Map);
    } catch (_) {
      return null;
    }
  }

  /// Toggle whether invited guests must pay for their own food.
  static Future<bool> updateInviteSettings(String bookingId, bool guestsMustPayForFood) async {
    try {
      await _patch('/bookings/$bookingId/invite/settings', {'guestsMustPayForFood': guestsMustPayForFood});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Host removes a joined player (only if they haven't paid).
  static Future<bool> removePlayer(String bookingId, String joinId) async {
    try {
      await _delete('/bookings/$bookingId/players/$joinId', {});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Host removes a guest food order (only if unpaid).
  static Future<bool> removeFoodOrder(String bookingId, String orderId) async {
    try {
      await _delete('/bookings/$bookingId/food-orders/$orderId', {});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Host pays for ALL unpaid guests' food. Wallet → instant {requiresPayment:false};
  /// online → {requiresPayment:true, razorpayOrderId, amount} (open Razorpay then verify).
  static Future<Map<String, dynamic>?> payGuestFoodInitiate(String bookingId, double amountRupees, {String method = 'upi', String? bookingItemId}) async {
    try {
      final d = await _post('/bookings/$bookingId/payment/guest-food', {
        'paymentMethod': method,
        'amount': amountRupees,
        if (bookingItemId != null) 'bookingItemId': bookingItemId,
      }, timeout: _paymentTimeout);
      return Map<String, dynamic>.from(d as Map);
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Verify the host's guest-food Razorpay payment.
  static Future<bool> payGuestFoodVerify(String bookingId, {required String paymentId, required String orderId, required String method, required double amount, String? bookingItemId}) async {
    try {
      final d = await _post('/bookings/$bookingId/payment/guest-food/verify', {
        'razorpayPaymentId': paymentId,
        'razorpayOrderId': orderId,
        'paymentMethod': method,
        'amount': amount,
        if (bookingItemId != null) 'bookingItemId': bookingItemId,
      });
      return d is Map ? d['success'] == true : true;
    } catch (_) {
      return false;
    }
  }

  // ── Corporate (placeholder — full corporate flow is Phase 2) ──────────────────

  /// Corporate inquiry. The vendor's corporate onboarding lives under /corporate/*
  /// and /onboard/* (a richer flow built in Phase 2). Stubbed for now so the
  /// existing corporate screen keeps working.
  static Future<bool> submitInquiry({
    required String companyName,
    required String email,
    String contactName = '',
    String phone = '',
    String licenseNo = '',
    String gstNo = '',
  }) async {
    // TODO(phase-2): wire to the vendor corporate onboarding flow.
    return true;
  }

  // ── Corporate (B2B) ──────────────────────────────────────────────────────────

  /// Self-signup step 1: send an OTP to the work email.
  /// company = {name, panNumber, gstNumber?, size}; admin = {fullName, jobTitle?, workEmail, phone}.
  static Future<void> corporateSignupSendOtp({
    required Map<String, dynamic> company,
    required Map<String, dynamic> admin,
  }) async {
    await _post('/onboard/self-signup/send-otp', {'company': company, 'admin': admin});
  }

  /// Self-signup step 2: verify OTP → creates company + super-admin + wallet and
  /// returns a session: {success, companyId, userId, token, role, fullName}.
  static Future<Map<String, dynamic>> corporateSignupVerify({
    required String otp,
    required Map<String, dynamic> company,
    required Map<String, dynamic> admin,
  }) async {
    final d = await _post('/onboard/self-signup/verify', {'otp': otp, 'company': company, 'admin': admin});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Check if a work email is available (true = not taken).
  static Future<bool> corporateCheckEmail(String email) async {
    try {
      final d = await _get('/onboard/check-email?email=${Uri.encodeComponent(email)}');
      return d is Map ? d['available'] == true : true;
    } catch (_) {
      return true;
    }
  }

  /// Check if a PAN is already registered. Returns {exists, status?, message?}.
  static Future<Map<String, dynamic>> corporateCheckPan(String panNumber) async {
    try {
      final d = await _post('/onboard/check-pan', {'panNumber': panNumber});
      return Map<String, dynamic>.from(d as Map);
    } catch (_) {
      return {'exists': false};
    }
  }

  /// Company status + KYC state (super-admin).
  static Future<Map<String, dynamic>> corporateStatus() async =>
      Map<String, dynamic>.from(await _get('/corporate/status') as Map);

  /// Company dashboard: upcoming bookings, counts, wallet balance, status (super-admin).
  static Future<Map<String, dynamic>> corporateDashboard() async =>
      Map<String, dynamic>.from(await _get('/corporate/dashboard') as Map);

  /// Wallet balance {totalBalance, creditUsed, creditLimit, hasPendingFunding}.
  static Future<Map<String, dynamic>> corporateWallet() async =>
      Map<String, dynamic>.from(await _get('/corporate/wallet') as Map);

  /// KYC status + uploaded documents.
  static Future<Map<String, dynamic>> corporateKycStatus() async =>
      Map<String, dynamic>.from(await _get('/corporate/kyc/status') as Map);

  /// Request a presigned S3 upload URL for a KYC document. Returns {uploadUrl, uploadId, ...}.
  /// documentType: pan_card | gst_certificate | certificate_of_incorporation | address_proof | cancelled_cheque | other.
  static Future<Map<String, dynamic>> corporateKycUploadUrl({
    required String documentType,
    required String fileName,
    required String mimeType,
    required int fileSizeBytes,
  }) async {
    final d = await _post('/corporate/kyc/upload-url', {
      'documentType': documentType,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
    });
    return Map<String, dynamic>.from(d as Map);
  }

  /// PUT raw file bytes to a presigned S3 URL. Returns true on 2xx.
  static Future<bool> uploadToPresignedUrl(String url, List<int> bytes, String mimeType) async {
    try {
      final res = await http
          .put(Uri.parse(url), headers: {'Content-Type': mimeType}, body: bytes)
          .timeout(_paymentTimeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Confirm an upload (creates the KycDocument record). Returns documentId.
  static Future<String> corporateKycConfirmUpload(String uploadId) async {
    final d = await _post('/corporate/kyc/confirm-upload', {'uploadId': uploadId});
    return (d is Map ? (d['documentId'] ?? '') : '').toString();
  }

  /// Submit KYC for review (requires at least one uploaded document). Throws ApiException otherwise.
  static Future<void> corporateKycSubmit() async {
    await _post('/corporate/kyc/submit', {});
  }

  /// Start a wallet top-up. For card/upi returns {razorpayOrderId, transactionId, amount};
  /// for bank_transfer/cheque returns {transactionId, ...} (offline). Throws ApiException on bad input.
  static Future<Map<String, dynamic>> corporateFundWallet({
    required double amount,
    required String method, // corporate_card | upi | bank_transfer | cheque
    String? referenceId,
    String? bankName,
  }) async {
    final d = await _post('/corporate/wallet/fund', {
      'amount': amount,
      'method': method,
      if (referenceId != null && referenceId.isNotEmpty) 'referenceId': referenceId,
      if (bankName != null && bankName.isNotEmpty) 'bankName': bankName,
    }, timeout: _paymentTimeout);
    return Map<String, dynamic>.from(d as Map);
  }

  /// Verify a wallet top-up after Razorpay checkout. Returns true on success.
  static Future<bool> corporateFundVerify({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      final d = await _post('/corporate/wallet/fund/verify', {
        'razorpayPaymentId': paymentId,
        'razorpayOrderId': orderId,
        'razorpaySignature': signature,
      });
      return d is Map ? d['success'] == true : true;
    } catch (_) {
      return false;
    }
  }

  // Team / members
  /// {currentUserId, members:[{id, fullName, email, phone, role, isTeamLead, createdAt}]}
  static Future<Map<String, dynamic>> corporateMembers() async =>
      Map<String, dynamic>.from(await _get('/corporate/members') as Map);

  /// Bulk-add members. members = [{fullName, email, phone?, isTeamLead?}]. Returns {created, skipped, skippedEmails}.
  static Future<Map<String, dynamic>> corporateAddMembers(List<Map<String, dynamic>> members) async {
    final d = await _post('/corporate/members/bulk', {'members': members});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Promote/demote a member: role = team_lead | member.
  static Future<bool> corporateSetMemberRole(String userId, String role) async {
    try {
      await _patch('/corporate/members/$userId/role', {'role': role});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove a member (reverts them to a personal b2c account).
  static Future<bool> corporateRemoveMember(String userId) async {
    try {
      await _delete('/corporate/members/$userId', {});
      return true;
    } catch (_) {
      return false;
    }
  }

  // Budget
  /// {walletBalance, totalAllocated, totalUsed, allocations:[{id, teamLeadId, teamLeadName, allocatedAmount, usedAmount, remaining}]}
  static Future<Map<String, dynamic>> corporateBudgetAllocations() async =>
      Map<String, dynamic>.from(await _get('/corporate/budget/allocations') as Map);

  /// Allocate (or top up) a team lead's budget from the unallocated wallet balance. Throws ApiException on insufficient balance.
  static Future<void> corporateAllocateBudget(String teamLeadId, double amount) async {
    await _post('/corporate/budget/allocate', {'teamLeadId': teamLeadId, 'amount': amount});
  }

  /// A team lead's own budget: {totalAllocated, totalUsed, available}.
  static Future<Map<String, dynamic>> corporateMyBudget() async =>
      Map<String, dynamic>.from(await _get('/corporate/budget') as Map);

  /// Redeem loyalty points for a checkout discount (1 pt = ₹1).
  /// Returns {pointsRedeemed, discount, remainingPoints}. Throws ApiException on error.
  static Future<Map<String, dynamic>> redeemLoyalty(int points) async {
    final d = await _post('/loyalty/redeem', {'points': points});
    return Map<String, dynamic>.from(d as Map);
  }

  // Credit line
  /// {hasApprovedCreditLine, creditLimit, creditUsed, creditAvailable, pendingRequest}
  static Future<Map<String, dynamic>> corporateCreditLineStatus() async =>
      Map<String, dynamic>.from(await _get('/corporate/credit-line/status') as Map);

  static Future<void> corporateRequestCreditLine({required double amount, required int billingCycleDays}) async {
    await _post('/corporate/credit-line/request', {'amount': amount, 'billingCycleDays': billingCycleDays});
  }

  // Teams & company invites
  /// Teams in the company: [{teamId/id, name, ...}].
  static Future<List<Map<String, dynamic>>> corporateTeams() async {
    try {
      final d = await _get('/corporate/teams');
      final list = (d is Map ? (d['teams'] ?? d['data'] ?? []) : d) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Create a team (super-admin). Returns {teamId, name}.
  static Future<Map<String, dynamic>> corporateCreateTeam(String name) async {
    final d = await _post('/corporate/teams', {'name': name});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Generate a shareable company invite code (super-admin). Returns {inviteCode, deepLink, expiresAt}.
  static Future<Map<String, dynamic>> corporateGenerateInvite() async {
    final d = await _post('/corporate/invite', {});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Join a company via an invite code (public — a brand-new employee). Returns {userId}.
  static Future<Map<String, dynamic>> corporateJoinByCode(String code,
      {required String fullName, required String phone, required String email, String? jobTitle, String? dateOfBirth}) async {
    final d = await _post('/corporate/teams/join/$code', {
      'fullName': fullName,
      'phone': phone,
      'email': email,
      if (jobTitle != null && jobTitle.isNotEmpty) 'jobTitle': jobTitle,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
    });
    return Map<String, dynamic>.from(d as Map);
  }

  /// Resubmit the company for review after a "needs more info" decision (super-admin).
  static Future<bool> corporateResubmit({String? name, String? gstNumber, String? size}) async {
    try {
      await _post('/corporate/resubmit', {
        if (name != null && name.isNotEmpty) 'name': name,
        if (gstNumber != null && gstNumber.isNotEmpty) 'gstNumber': gstNumber,
        if (size != null && size.isNotEmpty) 'size': size,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Adjust a budget allocation's amount (super-admin). Returns {newAmount, usedAmount, remaining}.
  static Future<Map<String, dynamic>> corporateUpdateAllocation(String allocationId, double amount) async {
    final d = await _patch('/corporate/budget/allocations/$allocationId', {'amount': amount});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Revoke a budget allocation entirely (only if nothing has been spent).
  static Future<bool> corporateRevokeAllocation(String allocationId) async {
    try {
      await _delete('/corporate/budget/allocations/$allocationId', {});
      return true;
    } catch (_) {
      return false;
    }
  }

  // Corporate bookings + invoices
  static Future<List<Map<String, dynamic>>> corporateBookings() async {
    try {
      final d = await _get('/corporate/bookings');
      return (d as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> invoices() async {
    try {
      final d = await _get('/invoices');
      final list = (d is Map ? (d['invoices'] ?? d['data'] ?? []) : d) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Team lead: manage own team + domain-locked invite ──────────────────────

  /// The current team lead's own team + members. Returns {teamId, teamName, members[]}.
  static Future<Map<String, dynamic>> corporateMyTeam() async {
    final d = await _get('/corporate/my-team');
    return Map<String, dynamic>.from(d as Map);
  }

  /// Team lead adds a member (name + email) to their team.
  static Future<Map<String, dynamic>> corporateAddTeamMember({
    required String fullName,
    required String email,
    String? phone,
  }) async {
    final d = await _post('/corporate/my-team', {
      'fullName': fullName,
      'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return Map<String, dynamic>.from(d as Map);
  }

  /// Team lead removes a member from their team.
  static Future<bool> corporateRemoveTeamMember(String userId) async {
    try {
      await _delete('/corporate/my-team/members/$userId', {});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Team lead generates a domain-locked invite for their team.
  /// Returns {inviteCode, allowedDomains[], deepLink, expiresAt}.
  static Future<Map<String, dynamic>> corporateTeamInvite() async {
    final d = await _post('/corporate/my-team/invite', {});
    return Map<String, dynamic>.from(d as Map);
  }

  /// The company's allowed email domains (for invite links).
  static Future<List<String>> corporateGetDomains() async {
    try {
      final d = await _get('/corporate/domains');
      final m = Map<String, dynamic>.from(d as Map);
      return ((m['allowedDomains'] as List?) ?? []).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Super-admin sets the company's allowed email domains. Returns the saved list.
  static Future<List<String>> corporateSetDomains(List<String> domains) async {
    final d = await _post('/corporate/domains', {'domains': domains});
    final m = Map<String, dynamic>.from(d as Map);
    return ((m['allowedDomains'] as List?) ?? []).map((e) => e.toString()).toList();
  }

  // ── Misc ──────────────────────────────────────────────────────────────────────

  /// Authenticated URL of a GST invoice PDF (needs the Bearer header to fetch).
  static String invoicePdfUrl(String invoiceId) => '$baseUrl/invoices/$invoiceId/pdf';

  /// Download an invoice PDF's bytes (with auth). Returns null on failure.
  static Future<List<int>?> downloadInvoicePdf(String invoiceId) async {
    try {
      final res = await http.get(Uri.parse(invoicePdfUrl(invoiceId)), headers: _headers()).timeout(_paymentTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Whether the platform is in maintenance mode.
  static Future<bool> maintenanceEnabled() async {
    try {
      final d = await _get('/maintenance/status');
      return d is Map && d['isEnabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Revoke the current session server-side (best-effort; call before clearing the local token).
  static Future<void> serverLogout() async {
    try {
      await _post('/auth/logout', {});
    } catch (_) {}
  }

  /// Trending bays this month: {topBays:[{bayId, bayName, activityName, activitySlug, pricePerSession, bookingCount, images}], activeOffersCount}.
  static Future<Map<String, dynamic>> getTrending() async {
    try {
      final d = await _get('/attractions/trending');
      return Map<String, dynamic>.from(d as Map);
    } catch (_) {
      return {'topBays': [], 'activeOffersCount': 0};
    }
  }

  // ── Invite-based corporate onboarding (admin-sent link; vs self-signup) ────────

  /// Validate an admin-sent onboarding token. Returns {status: valid|used|expired|invalid, inquiryId?}.
  static Future<Map<String, dynamic>> onboardCheckToken(String token) async {
    try {
      final d = await _get('/onboard/$token');
      return Map<String, dynamic>.from(d as Map);
    } catch (_) {
      return {'status': 'invalid'};
    }
  }

  /// Send the onboarding OTP for an invited company.
  static Future<void> onboardSendOtp(String email, String token) async {
    await _post('/onboard/send-otp', {'email': email, 'token': token});
  }

  /// Resend the onboarding OTP.
  static Future<void> onboardResendOtp(String email) async {
    await _post('/onboard/resend-otp', {'email': email});
  }

  /// Verify invite-based onboarding. NOTE: unlike self-signup this does NOT return a session token.
  static Future<Map<String, dynamic>> onboardVerify({
    required String token,
    required String otp,
    required Map<String, dynamic> company,
    required Map<String, dynamic> admin,
  }) async {
    final d = await _post('/onboard/verify', {'token': token, 'otp': otp, 'company': company, 'admin': admin});
    return Map<String, dynamic>.from(d as Map);
  }

  /// Back-compat helper used by older screens: reports whether client-side Razorpay
  /// is configured (via --dart-define) and the public key.
  static Future<Map<String, dynamic>> paymentsConfig() async =>
      {'razorpay_enabled': razorpayConfigured, 'key_id': razorpayKeyId};

  static String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);
}
