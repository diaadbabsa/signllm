import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUser = 'user_data';

  // Current user in memory (set after login or auto-login)
  static UserModel? currentUser;

  /// Save tokens + user after successful login
  static Future<void> saveSession(
      String access, String refresh, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, access);
    await prefs.setString(_keyRefresh, refresh);
    await prefs.setString(_keyUser, jsonEncode(userData));
    currentUser = UserModel.fromJson(userData);
  }

  /// Try to restore session from stored tokens
  /// Returns true if user is still authenticated
  static Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_keyAccess);
    final refresh = prefs.getString(_keyRefresh);
    final userJson = prefs.getString(_keyUser);

    if (access == null || refresh == null || userJson == null) {
      return false;
    }

    // Try using access token
    final me = await ApiService.getMe(access);
    if (me != null) {
      currentUser = UserModel.fromJson(me);
      return true;
    }

    // Access expired — try refresh
    final newAccess = await ApiService.refreshToken(refresh);
    if (newAccess != null) {
      await prefs.setString(_keyAccess, newAccess);
      final me2 = await ApiService.getMe(newAccess);
      if (me2 != null) {
        currentUser = UserModel.fromJson(me2);
        return true;
      }
    }

    // Tokens invalid — clear everything
    await logout();
    return false;
  }

  /// Clear all stored data
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove(_keyUser);
    currentUser = null;
  }
}
