import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'store.dart';

class AppUser {
  final String? name, email, phone;
  final bool isGuest;
  AppUser({this.name, this.email, this.phone, this.isGuest = false});
  String get key => email ?? phone ?? 'guest';
  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'phone': phone, 'isGuest': isGuest};
  factory AppUser.fromJson(Map<String, dynamic> j) =>
      AppUser(name: j['name'], email: j['email'], phone: j['phone'], isGuest: j['isGuest'] ?? false);
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
  }

  Future<void> login(AppUser u) async {
    user = u;
    await BookingStore.instance.loadForUser(u.key);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(u.toJson()));
    } catch (_) {}
  }

  Future<void> logout() async {
    user = null;
    BookingStore.instance.clearSession();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
