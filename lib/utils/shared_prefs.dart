import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart'; // Ensure this path is correct for your User model

class SharedPrefs {
  /// Saves the user object, authentication token, user ID, and user role to SharedPreferences.
  static Future<void> saveUser(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final userDataString = jsonEncode(user.toJson());
      await prefs.setString('user', userDataString);
      await prefs.setString('token', token);

      // Ensure user.id is not null before saving
      await prefs.setInt('userId', user.id);

      // Ensure user.user_role is not null before saving
      await prefs.setString('userRole', user.user_role);
    } catch (e) {
      // In a production app, you'd use a logging framework here (e.g., logger, Firebase Crashlytics)
      // print('SharedPrefs Error: Failed to save user data to SharedPreferences: $e');
    }
  }

  /// Retrieves the user object from SharedPreferences.
  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    if (userData != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userData);
        return User.fromJson(userMap);
      } catch (e) {
        // In a production app, you'd use a logging framework here
        // print('SharedPrefs Error: Error decoding user data from SharedPreferences: $e');
        // print('SharedPrefs Error: Data that caused the error: $userData');
        return null;
      }
    }
    return null;
  }

  /// Saves only the user ID to SharedPreferences.
  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', userId);
  }

  /// Retrieves the user ID from SharedPreferences.
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  /// Saves the authentication token to SharedPreferences.
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  /// Saves the user role to SharedPreferences.
  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role);
  }

  /// Retrieves the authentication token from SharedPreferences.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Retrieves the user role from SharedPreferences.
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole');
  }

  /// Clears user-specific data from SharedPreferences.
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('userRole');
  }

  /// Clears all data from SharedPreferences. Use with caution.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
