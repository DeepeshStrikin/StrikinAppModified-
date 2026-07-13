import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'store.dart';

class AppUser {
  final String? name, email, phone;
  final bool isGuest;
  // Bearer session token from the vendor backend. Sent as `Authorization: Bearer <token>`
  // on authenticated API calls. Present for both logged-in users and guest sessions.
  final String? token;
  // For guests this is the server-side guestSessionId (also the auth subject).
  final String? guestSessionId;
  // Backend role: b2c | guest | super_admin | team_lead | member.
  final String? role;
  // Company name for corporate users (from /auth/me, login verify, or signup).
  final String? companyName;
  // Real loyalty balance from the backend (1 pt per ₹100 spent on confirmed bookings).
  final int loyaltyPoints;
  // Date of birth as an ISO string (e.g. "1990-05-01T00:00:00.000Z"), nullable.
  final String? dob;
  // Self-reported gender: male | female | other | prefer_not_to_say, nullable.
  final String? gender;
  AppUser({
    this.name,
    this.email,
    this.phone,
    this.isGuest = false,
    this.token,
    this.guestSessionId,
    this.role,
    this.companyName,
    this.loyaltyPoints = 0,
    this.dob,
    this.gender,
  });
  String get key => email ?? phone ?? guestSessionId ?? 'guest';

  /// True for corporate users (company employees), any corporate role.
  bool get isCorporate => role == 'super_admin' || role == 'team_lead' || role == 'member';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isTeamLead => role == 'team_lead';

  /// Whether we still need to collect demographic details (gender + DOB).
  /// Corporate users are exempt (their profile is managed by the company).
  bool get needsProfileDetails =>
      !isCorporate && ((gender == null || gender!.isEmpty) || (dob == null || dob!.isEmpty));

  AppUser copyWith({String? name, String? phone, String? dob, String? gender, int? loyaltyPoints, String? companyName, String? role, bool clearDob = false, bool clearGender = false, bool clearCompanyName = false}) => AppUser(
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        isGuest: isGuest,
        token: token,
        guestSessionId: guestSessionId,
        role: role ?? this.role,
        companyName: clearCompanyName ? null : (companyName ?? this.companyName),
        loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
        dob: clearDob ? null : (dob ?? this.dob),
        gender: clearGender ? null : (gender ?? this.gender),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'isGuest': isGuest,
        'token': token,
        'guestSessionId': guestSessionId,
        'role': role,
        'companyName': companyName,
        'loyaltyPoints': loyaltyPoints,
        'dob': dob,
        'gender': gender,
      };
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        name: j['name'],
        email: j['email'],
        phone: j['phone'],
        isGuest: j['isGuest'] ?? false,
        token: j['token'],
        guestSessionId: j['guestSessionId'],
        role: j['role'],
        companyName: j['companyName'],
        loyaltyPoints: (j['loyaltyPoints'] is num) ? (j['loyaltyPoints'] as num).toInt() : 0,
        dob: j['dob'],
        gender: j['gender'],
      );
}

/// Persisted authentication state. Global singleton — listen via ListenableBuilder.
class AuthState extends ChangeNotifier {
  static final AuthState instance = AuthState._();
  AuthState._();

  static const _key = 'strikin.user';
  AppUser? user;
  bool isReady = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        user = AppUser.fromJson(jsonDecode(raw));
        await BookingStore.instance.loadForUser(user!.key);
      }
    } catch (_) {}
    isReady = true;
    notifyListeners();
    refreshProfile(); // fire-and-forget: pull latest loyalty/profile from the server
  }

  Future<void> login(AppUser u) async {
    user = u;
    await BookingStore.instance.loadForUser(u.key);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(u.toJson()));
    } catch (_) {}
    if (!u.isGuest) refreshProfile();
  }

  /// Pull the latest profile (loyalty points, name/phone/DOB) from `/auth/me` and persist.
  Future<void> refreshProfile() async {
    final u = user;
    if (u == null || u.isGuest || u.token == null) return;
    try {
      final me = await Api.authMe();
      if (me == null || user == null) return;
      await applyProfileUpdate(me);
    } catch (_) {}
  }

  /// Merge a profile map (from GET or PATCH /auth/me) into the session and persist.
  Future<void> applyProfileUpdate(Map<String, dynamic> me) async {
    if (user == null) return;
    user = user!.copyWith(
      name: me['fullName']?.toString(),
      phone: me['phone']?.toString(),
      dob: me['dateOfBirth']?.toString(),
      clearDob: me.containsKey('dateOfBirth') && me['dateOfBirth'] == null,
      gender: me['gender']?.toString(),
      clearGender: me.containsKey('gender') && me['gender'] == null,
      loyaltyPoints: (me['loyaltyPoints'] is num) ? (me['loyaltyPoints'] as num).toInt() : null,
      role: me['role']?.toString(),
      companyName: me['companyName']?.toString(),
    );
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(user!.toJson()));
    } catch (_) {}
  }

  Future<void> logout() async {
    if (user?.isGuest == false && user?.token != null) {
      Api.serverLogout(); // best-effort revoke server-side (captures token before we clear it)
    }
    user = null;
    BookingStore.instance.clearSession();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
