import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class AuthRepository extends ChangeNotifier {
  final SharedPreferences _prefs;

  AuthRepository(this._prefs);

  bool get isLoggedIn => _prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
  String get userName => _prefs.getString(AppConstants.keyUserName) ?? '';
  String get userPhone => _prefs.getString(AppConstants.keyUserPhone) ?? '';
  String get userId => _prefs.getString(AppConstants.keyUserId) ?? '';

  // ── Simulate sending OTP ──────────────────────────────────────────────────
  Future<bool> sendOtp(String phone) async {
    await Future.delayed(const Duration(seconds: 1));
    // In production: call your backend/Firebase Auth
    return true;
  }

  // ── Simulate OTP verification ─────────────────────────────────────────────
  Future<bool> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 800));
    // Demo: accept any 6-digit code
    return otp.length == 6;
  }

  // ── Complete registration with name ───────────────────────────────────────
  Future<void> completeRegistration({
    required String phone,
    required String name,
  }) async {
    await _prefs.setBool(AppConstants.keyIsLoggedIn, true);
    await _prefs.setString(AppConstants.keyUserPhone, phone);
    await _prefs.setString(AppConstants.keyUserName, name);
    await _prefs.setString(
      AppConstants.keyUserId,
      'user_${DateTime.now().millisecondsSinceEpoch}',
    );
    notifyListeners();
  }

  // ── Update name ───────────────────────────────────────────────────────────
  Future<void> updateName(String name) async {
    await _prefs.setString(AppConstants.keyUserName, name);
    notifyListeners();
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _prefs.clear();
    notifyListeners();
  }
}
