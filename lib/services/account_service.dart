import 'package:shared_preferences/shared_preferences.dart';

class AccountService {
  static const String _currentAccountKey = 'current_worker_account';
  
  /// Get the currently selected worker account ID
  static Future<String?> getCurrentAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentAccountKey);
  }
  
  /// Set the current worker account
  static Future<void> setCurrentAccount(String workerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentAccountKey, workerId);
  }
  
  /// Clear the current account (logout)
  static Future<void> clearCurrentAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentAccountKey);
  }
  
  /// Check if a user account is selected
  static Future<bool> hasActiveAccount() async {
    final accountId = await getCurrentAccountId();
    return accountId != null && accountId.isNotEmpty;
  }
}