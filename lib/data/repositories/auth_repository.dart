import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../models/customer_profile_model.dart';

class AuthRepository extends ChangeNotifier {
  final SharedPreferences _prefs;

  // In-memory customer profile cache
  CustomerProfile? _profile;
  CustomerProfile? get profile => _profile;

  AuthRepository(this._prefs);

  // ─── Getters (SharedPreferences se) ────────────────────────────────────────
  bool get isLoggedIn => _prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
  String get userName => _prefs.getString(AppConstants.keyUserName) ?? '';
  String get userPhone => _prefs.getString(AppConstants.keyUserPhone) ?? '';
  String get userId => _prefs.getString(AppConstants.keyUserId) ?? '';
  String get authToken => _prefs.getString(AppConstants.keyAuthToken) ?? '';

  // ─── NEW USER: Register + Send OTP ─────────────────────────────────────────
  Future<ApiResponse> registerAndSendOtp({
    required String phone,
    required String name,
    String? email,
  }) async {
    final response = await ApiService.post('/register', {
      'mobile': phone,
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return response;
  }

  // ─── EXISTING USER: Login + Send OTP ───────────────────────────────────────
  Future<ApiResponse> loginAndSendOtp({required String phone}) async {
    final response = await ApiService.post('/login', {'mobile': phone});
    if (response.success && response.userId != null) {
      await _prefs.setString('temp_user_id', response.userId.toString());
    }
    return response;
  }

  // ─── VERIFY OTP (Login flow) ────────────────────────────────────────────────
  Future<ApiResponse> verifyLoginOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await ApiService.post('/login/verify-otp', {
      'mobile': phone,
      'otp': otp,
    });
    if (response.success) await _saveSession(response, phone);
    return response;
  }

  // ─── VERIFY OTP (Registration flow) ────────────────────────────────────────
  Future<ApiResponse> verifyRegisterOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await ApiService.post('/verify-otp', {
      'mobile': phone,
      'otp': otp,
    });
    if (response.success) await _saveSession(response, phone);
    return response;
  }

  // ─── Check karo ki user already registered hai ya nahi ─────────────────────
  Future<UserCheckResult> checkUser({required String phone}) async {
    final response = await ApiService.post('/login', {'mobile': phone});

    if (response.success) {
      if (response.userId != null) {
        await _prefs.setString('temp_user_id', response.userId.toString());
      }
      return UserCheckResult.existingUser(response);
    } else if (response.statusCode == 404) {
      final msg = response.message.toLowerCase();
      final bool isBlockedAccount = msg.contains('deleted') ||
          msg.contains('banned') ||
          msg.contains('suspended') ||
          msg.contains('support') ||
          msg.contains('block');
      if (isBlockedAccount) return UserCheckResult.error(response.message);
      return UserCheckResult.newUser();
    } else {
      return UserCheckResult.error(response.errorMessage);
    }
  }

  // ─── FETCH Customer Profile from API ────────────────────────────────────────
  // Call this when profile screen opens or after login.
  // NOTE: Adjust endpoint to match your routes/api.php
  Future<ProfileResult> fetchProfile() async {
    if (authToken.isEmpty) return ProfileResult.error('Not authenticated');

    final response = await ApiService.get(
      '/customer/profile',
      token: authToken,
    );

    if (response.success && response.payload != null) {
      final p = CustomerProfile.fromJson(response.payload!);
      _profile = p;
      await _prefs.setString(AppConstants.keyUserName, p.name);
      await _prefs.setString(AppConstants.keyUserPhone, p.mobile);
      notifyListeners();
      return ProfileResult.success(p);
    }

    return ProfileResult.error(response.errorMessage);
  }

  // ─── UPDATE Customer Profile ─────────────────────────────────────────────────
  // Uses multipart because profile_image is a file.
  // NOTE: Adjust endpoint to match your routes/api.php
  Future<ProfileResult> updateProfile({
    required String name,
    String? email,
    String? mobile,
    String? address,
    File? profileImage,
    String? bankName,
    String? accountNo,
    String? ifscCode,
    String? upiId,
  }) async {
    if (authToken.isEmpty) return ProfileResult.error('Not authenticated');

    final fields = <String, String>{
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      if (address != null && address.isNotEmpty) 'address': address,
      if (bankName != null && bankName.isNotEmpty) 'bank_name': bankName,
      if (accountNo != null && accountNo.isNotEmpty) 'account_no': accountNo,
      if (ifscCode != null && ifscCode.isNotEmpty) 'ifsc_code': ifscCode,
      if (upiId != null && upiId.isNotEmpty) 'upi_id': upiId,
    };

    final response = await ApiService.postMultipart(
      '/customer/update-profile',
      fields: fields,
      token: authToken,
      imageFile: profileImage,
      imageFieldName: 'profile_image',
    );

    if (response.success && response.payload != null) {
      final updated = CustomerProfile.fromJson(response.payload!);
      _profile = updated;
      await _prefs.setString(AppConstants.keyUserName, updated.name);
      notifyListeners();
      return ProfileResult.success(updated);
    }

    return ProfileResult.error(response.errorMessage);
  }

  // ─── DELETE Account ──────────────────────────────────────────────────────────
  // Laravel soft-deletes customer + user, revokes tokens.
  // NOTE: Adjust endpoint to match your routes/api.php
  Future<ApiResponse> deleteAccount() async {
    final response = await ApiService.delete(
      '/customer/delete',
      token: authToken,
    );
    if (response.success) {
      _profile = null;
      await _prefs.clear();
      notifyListeners();
    }
    return response;
  }

  // ─── Session Save ────────────────────────────────────────────────────────────
  Future<void> _saveSession(ApiResponse response, String phone) async {
    final user = response.user;
    final token = response.token;

    await _prefs.setBool(AppConstants.keyIsLoggedIn, true);
    await _prefs.setString(AppConstants.keyUserPhone, phone);
    if (token != null) await _prefs.setString(AppConstants.keyAuthToken, token);
    if (user != null) {
      await _prefs.setString(
          AppConstants.keyUserName, user['name'] as String? ?? '');
      await _prefs.setString(
          AppConstants.keyUserId, user['id']?.toString() ?? '');
    }
    await _prefs.remove('temp_user_id');
    notifyListeners();
  }

  // ─── Complete Registration ────────────────────────────────────────────────
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

  Future<void> updateName(String name) async {
    await _prefs.setString(AppConstants.keyUserName, name);
    notifyListeners();
  }

  Future<void> logout() async {
    _profile = null;
    await _prefs.clear();
    notifyListeners();
  }
}

// ─── Profile Result ───────────────────────────────────────────────────────────
class ProfileResult {
  final bool isSuccess;
  final CustomerProfile? profile;
  final String? error;

  ProfileResult._({required this.isSuccess, this.profile, this.error});

  factory ProfileResult.success(CustomerProfile p) =>
      ProfileResult._(isSuccess: true, profile: p);
  factory ProfileResult.error(String msg) =>
      ProfileResult._(isSuccess: false, error: msg);
}

// ─── User Check Result ────────────────────────────────────────────────────────
enum UserStatus { existing, newUser, error }

class UserCheckResult {
  final UserStatus status;
  final ApiResponse? response;
  final String? errorMsg;

  UserCheckResult._({required this.status, this.response, this.errorMsg});

  factory UserCheckResult.existingUser(ApiResponse r) =>
      UserCheckResult._(status: UserStatus.existing, response: r);
  factory UserCheckResult.newUser() =>
      UserCheckResult._(status: UserStatus.newUser);
  factory UserCheckResult.error(String msg) =>
      UserCheckResult._(status: UserStatus.error, errorMsg: msg);

  bool get isExisting => status == UserStatus.existing;
  bool get isNew => status == UserStatus.newUser;
  bool get hasError => status == UserStatus.error;
}