import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Friendly label for a booking's status (shared by the list + summary screens).
String bookingStatusLabel(String s) {
  switch (s) {
    case 'upcoming':
      return 'CONFIRMED';
    case 'pending_payment':
      return 'PAY AT VENUE';
    case 'completed':
      return 'SESSION FINISHED';
    case 'cancelled':
      return 'CANCELLED';
    default:
      return s.toUpperCase();
  }
}

String bookingStatusTone(String s) {
  switch (s) {
    case 'completed':
      return 'success';
    case 'cancelled':
      return 'danger';
    default:
      return 'accent'; // upcoming / pending_payment
  }
}

/// Whether a booking's slot date+time is already in the past.
/// Falls back to end-of-day when the time is missing, and to the raw date
/// when the timestamp can't be parsed.
bool bookingIsPast(MyBooking b) {
  final t = b.time.contains(':') ? b.time : '23:59';
  final dt = DateTime.tryParse('${b.date}T$t:00') ?? DateTime.tryParse(b.date);
  return dt != null && dt.isBefore(DateTime.now());
}

/// A booking is "expired" when its slot has already passed but it was never
/// completed or cancelled — i.e. it still reads as upcoming / pending. The
/// server's nightly job may not have flipped it yet (and in production that
/// job isn't scheduled), so the app decides expiry itself: an expired booking
/// has no usable QR and must not say "start your game".
bool bookingIsExpired(MyBooking b) =>
    (b.status == 'upcoming' || b.status == 'pending_payment') && bookingIsPast(b);

/// Status label that accounts for client-side expiry (shows EXPIRED).
String bookingEffectiveLabel(MyBooking b) =>
    bookingIsExpired(b) ? 'EXPIRED' : bookingStatusLabel(b.status);

/// Status tone that accounts for client-side expiry (greys out EXPIRED).
String bookingEffectiveTone(MyBooking b) =>
    bookingIsExpired(b) ? 'neutral' : bookingStatusTone(b.status);

/// How long before the slot a booking can still be cancelled.
const cancellationCutoff = Duration(hours: 1);

/// A booking can be cancelled only while it's still upcoming AND its slot is
/// more than [cancellationCutoff] away. Inside the final hour (or once the slot
/// has started/passed) cancellation is locked. The server enforces the same
/// rule — this just keeps the button honest.
bool bookingCancellable(MyBooking b) {
  if (b.status != 'upcoming') return false;
  final t = b.time.contains(':') ? b.time : '23:59';
  final dt = DateTime.tryParse('${b.date}T$t:00');
  if (dt == null) return false;
  return dt.difference(DateTime.now()) > cancellationCutoff;
}

/// A booking the user has actually made (kept per-user, persisted locally,
/// also stored server-side in the cloud DB).
class MyBooking {
  final String id, activity, bay, date, time, status, qr, pin;
  final double amount;
  final int loyalty;
  final int createdAtMs;
  final String image; // bay image (relative path, resolve via Api.img)
  MyBooking({
    required this.id,
    required this.activity,
    required this.bay,
    required this.date,
    required this.time,
    required this.status,
    required this.qr,
    required this.pin,
    required this.amount,
    required this.loyalty,
    required this.createdAtMs,
    this.image = '',
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'activity': activity, 'bay': bay, 'date': date, 'time': time,
        'status': status, 'qr': qr, 'pin': pin, 'amount': amount, 'loyalty': loyalty,
        'createdAtMs': createdAtMs, 'image': image,
      };
  factory MyBooking.fromJson(Map<String, dynamic> j) => MyBooking(
        id: j['id'], activity: j['activity'], bay: j['bay'], date: j['date'], time: j['time'],
        status: j['status'], qr: j['qr'], pin: j['pin'],
        amount: (j['amount'] as num).toDouble(), loyalty: (j['loyalty'] as num).toInt(),
        createdAtMs: j['createdAtMs'] ?? 0, image: (j['image'] ?? '').toString(),
      );

  /// Map a booking row from the vendor backend (`GET /bookings/list` or `/bookings/{id}`).
  factory MyBooking.fromServer(Map<String, dynamic> j) {
    final items = (j['items'] as List?) ?? const [];
    final first = items.isNotEmpty ? items.first as Map : null;
    var activity = 'Activity', bayName = 'Bay', bayTier = '', time = '', image = '';
    if (first != null) {
      final bay = first['bay'];
      if (bay is Map) {
        bayName = (bay['name'] ?? 'Bay').toString();
        bayTier = (bay['bayTier'] ?? '').toString();
        final at = bay['activityType'];
        if (at is Map) activity = (at['name'] ?? 'Activity').toString();
        final imgs = bay['images'];
        if (imgs is List && imgs.isNotEmpty) image = imgs.first.toString();
      }
      time = _hhmm(first['slotTime']);
    }
    final bayLabel = items.length <= 1
        ? bayName
        : '${items.length} ${bayTier.isEmpty ? '' : '${bayTier.toUpperCase()} '}bays';
    final date = (j['bookingDate'] ?? '').toString();
    return MyBooking(
      id: (j['id'] ?? '').toString(),
      activity: activity,
      bay: bayLabel,
      date: date.length >= 10 ? date.substring(0, 10) : date,
      time: time,
      status: (j['status'] ?? 'upcoming').toString(),
      qr: (j['qrCode'] ?? '').toString(),
      pin: (j['pin'] ?? '').toString(),
      amount: toDouble(j['totalAmount']),
      loyalty: 0,
      createdAtMs: _parseMs(j['createdAt']),
      image: image,
    );
  }
}

/// "1970-01-01T15:30:00.000Z" (or "15:30:00") → "15:30"
String _hhmm(dynamic v) {
  final s = (v ?? '').toString();
  final t = s.contains('T') ? s.split('T').last : s;
  return t.length >= 5 ? t.substring(0, 5) : t;
}

int _parseMs(dynamic v) {
  try {
    return DateTime.parse(v.toString()).millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

/// In-progress booking draft + the user's real bookings & loyalty. Global singleton.
/// One activity's full selection, held in the multi-activity cart.
class CartLeg {
  final ActivityType activity;
  final List<Bay> bays;
  final String date, time;
  final int players;
  final List<CartFood> food;
  CartLeg({required this.activity, required this.bays, required this.date, required this.time, required this.players, required this.food});
  double get bayTotal => bays.fold(0.0, (s, b) => s + b.pricePerSession);
  double get foodTotal => food.fold(0.0, (s, f) => s + f.item.price * f.quantity);
  double get total => bayTotal + foodTotal;
}

class BookingStore extends ChangeNotifier {
  static final BookingStore instance = BookingStore._();
  BookingStore._();

  // ---- draft ----
  ActivityType? activity;
  String date = DateTime.now().toIso8601String().substring(0, 10);
  int players = 4;
  final List<Bay> bays = []; // selected bays (one tier, can be multiple)
  String? time;
  final List<CartFood> food = [];

  // ---- multi-activity cart: previously-configured activities in this order ----
  final List<CartLeg> cart = [];
  double get cartTotal => cart.fold(0.0, (s, l) => s + l.total);
  /// All configured activities' total (cart legs + the current selection).
  double get combinedTotal => cartTotal + grandTotal;
  /// Pre-tax bay (activity) subtotal across the whole cart + current selection.
  double get combinedBayTotal => cart.fold(0.0, (s, l) => s + l.bayTotal) + bayTotal;
  /// Pre-tax food subtotal across the whole cart + current selection.
  double get combinedFoodTotal => cart.fold(0.0, (s, l) => s + l.foodTotal) + foodTotal;

  /// First selected bay — used for slot loading and single-name display.
  Bay? get bay => bays.isEmpty ? null : bays.first;
  double get bayTotal => bays.fold(0.0, (s, b) => s + b.pricePerSession);
  int get totalCapacity => bays.fold(0, (s, b) => s + b.maxPlayers);
  bool isBaySelected(String id) => bays.any((b) => b.id == id);

  // ---- the user's real bookings (fresh = empty) ----
  final List<MyBooking> myBookings = [];
  String? _userKey;

  int get loyaltyPoints => myBookings.fold(0, (s, b) => s + b.loyalty);

  double get foodTotal => food.fold(0, (s, f) => s + f.item.price * f.quantity);
  double get grandTotal => bayTotal + foodTotal;

  void setActivity(ActivityType a) {
    // Start each activity booking fresh — clear bay, time, players and the food
    // cart so selections don't carry over from a previously viewed activity.
    activity = a;
    bays.clear();
    time = null;
    players = 4;
    food.clear();
    notifyListeners();
  }
  void setDate(String d) { date = d; notifyListeners(); }
  void setPlayers(int n) { players = n; notifyListeners(); }

  /// Toggle a bay in/out of the selection (all selected bays are the same tier).
  void toggleBay(Bay b) {
    final i = bays.indexWhere((x) => x.id == b.id);
    if (i >= 0) {
      bays.removeAt(i);
    } else {
      bays.add(b);
    }
    time = null; // re-pick time when the bay set changes
    notifyListeners();
  }
  void clearBay() { bays.clear(); time = null; food.clear(); notifyListeners(); }

  /// Snapshot the current activity selection into the cart, then reset the
  /// current selection so the user can configure another activity.
  bool addCurrentToCart() {
    if (activity == null || bays.isEmpty || time == null) return false;
    cart.add(CartLeg(
      activity: activity!,
      bays: List.of(bays),
      date: date,
      time: time!,
      players: players,
      food: food.map((f) => CartFood(f.item, f.quantity)).toList(),
    ));
    activity = null;
    bays.clear();
    time = null;
    players = 4;
    food.clear();
    notifyListeners();
    return true;
  }

  void clearCart() { cart.clear(); notifyListeners(); }

  /// Combined /bookings items[] from every cart leg + the current selection.
  List<Map<String, dynamic>> buildAllItems() {
    final items = <Map<String, dynamic>>[];
    void addLeg(List<Bay> bs, String d, String? t, int pl) {
      if (bs.isEmpty || t == null) return;
      final n = bs.length;
      final per = n == 0 ? pl : (pl ~/ n);
      final extra = pl - per * n;
      for (var i = 0; i < n; i++) {
        var np = per + (i < extra ? 1 : 0);
        if (np < 1) np = 1;
        items.add({'bayId': bs[i].id, 'numPlayers': np, 'itemAmount': bs[i].pricePerSession, 'slotDate': d, 'slotTime': t});
      }
    }
    for (final leg in cart) {
      addLeg(leg.bays, leg.date, leg.time, leg.players);
    }
    addLeg(bays, date, time, players);
    return items;
  }

  /// Combined foodOrders[] from every cart leg + the current selection.
  List<Map<String, dynamic>> buildAllFood() {
    final all = <CartFood>[...cart.expand((l) => l.food), ...food];
    return all
        .map((f) => {
              'restroworksItemId': f.item.id,
              'restroworksItemName': f.item.name,
              'restroworksItemPrice': f.item.price,
              'quantity': f.quantity,
              'itemTotal': f.item.price * f.quantity,
            })
        .toList();
  }

  /// Mark a saved booking as cancelled locally (after the server confirms).
  void cancelLocal(String id) {
    final i = myBookings.indexWhere((b) => b.id == id);
    if (i < 0) return;
    final o = myBookings[i];
    myBookings[i] = MyBooking(
      id: o.id, activity: o.activity, bay: o.bay, date: o.date, time: o.time,
      status: 'cancelled', qr: o.qr, pin: o.pin, amount: o.amount,
      loyalty: o.loyalty, createdAtMs: o.createdAtMs,
    );
    notifyListeners();
    _persist();
  }
  void setTime(String t) { time = t; notifyListeners(); }

  int qtyOf(String id) {
    final f = food.where((e) => e.item.id == id);
    return f.isEmpty ? 0 : f.first.quantity;
  }

  void addFood(FoodItem item) {
    final existing = food.where((f) => f.item.id == item.id);
    if (existing.isEmpty) {
      food.add(CartFood(item, 1));
    } else {
      existing.first.quantity++;
    }
    notifyListeners();
  }

  void removeFood(String id) {
    final existing = food.where((f) => f.item.id == id);
    if (existing.isNotEmpty) {
      existing.first.quantity--;
      food.removeWhere((f) => f.quantity <= 0);
    }
    notifyListeners();
  }

  /// Record a confirmed booking (called after the server returns success).
  /// Pass [status] to override the server's draft status — e.g. after an online
  /// payment is verified the booking is 'upcoming', not 'pending_payment'.
  Future<void> recordBooking(BookingResult r, {String? status}) async {
    myBookings.insert(
      0,
      MyBooking(
        id: r.id,
        activity: activity?.name ?? 'Activity',
        bay: bays.isEmpty
            ? 'Bay'
            : (bays.length == 1 ? bays.first.name : '${bays.length} ${bays.first.bayTier.toUpperCase()} bays'),
        date: date,
        time: time ?? '',
        status: status ?? r.status,
        qr: r.qrCode,
        pin: r.pin,
        amount: r.totalAmount,
        loyalty: r.loyaltyEarned,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    notifyListeners();
    await _persist();
  }

  /// Insert an already-built booking row (used by flows that don't go through the
  /// bay/slot draft, e.g. Mega Screen seat bookings). De-dupes by id.
  Future<void> recordBookingRow(MyBooking b) async {
    myBookings.removeWhere((x) => x.id == b.id);
    myBookings.insert(0, b);
    notifyListeners();
    await _persist();
  }

  /// Merge server-fetched bookings (source of truth for confirmed bookings) with any
  /// local-only ones not yet returned by the server (e.g. a booking just made).
  void mergeServerBookings(List<MyBooking> server) {
    final serverIds = server.map((b) => b.id).toSet();
    final localOnly = myBookings.where((b) => !serverIds.contains(b.id)).toList();
    myBookings
      ..clear()
      ..addAll(server)
      ..addAll(localOnly);
    myBookings.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    notifyListeners();
    _persist();
  }

  // ---- per-user persistence ----
  Future<void> loadForUser(String key) async {
    _userKey = key;
    myBookings.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('strikin.bookings.$key');
      if (raw != null) {
        final list = (jsonDecode(raw) as List).map((e) => MyBooking.fromJson(e)).toList();
        myBookings.addAll(list);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_userKey == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('strikin.bookings.$_userKey', jsonEncode(myBookings.map((b) => b.toJson()).toList()));
    } catch (_) {}
  }

  void clearSession() {
    myBookings.clear();
    _userKey = null;
    notifyListeners();
  }

  void reset() {
    activity = null;
    date = DateTime.now().toIso8601String().substring(0, 10);
    players = 4;
    bays.clear();
    time = null;
    food.clear();
    cart.clear();
    notifyListeners();
  }
}
