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
      return 'COMPLETED';
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

/// A booking the user has actually made (kept per-user, persisted locally,
/// also stored server-side in the cloud DB).
class MyBooking {
  final String id, activity, bay, date, time, status, qr, pin;
  final double amount;
  final int loyalty;
  final int createdAtMs;
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
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'activity': activity, 'bay': bay, 'date': date, 'time': time,
        'status': status, 'qr': qr, 'pin': pin, 'amount': amount, 'loyalty': loyalty,
        'createdAtMs': createdAtMs,
      };
  factory MyBooking.fromJson(Map<String, dynamic> j) => MyBooking(
        id: j['id'], activity: j['activity'], bay: j['bay'], date: j['date'], time: j['time'],
        status: j['status'], qr: j['qr'], pin: j['pin'],
        amount: (j['amount'] as num).toDouble(), loyalty: (j['loyalty'] as num).toInt(),
        createdAtMs: j['createdAtMs'] ?? 0,
      );
}

/// In-progress booking draft + the user's real bookings & loyalty. Global singleton.
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
    notifyListeners();
  }
}
