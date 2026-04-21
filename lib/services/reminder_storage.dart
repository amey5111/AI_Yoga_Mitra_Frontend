// lib/services/reminder_storage.dart
//
// ✅ FIX 2: Reminders are stored PER-USER.
//
// How it works:
//   • Every key is prefixed with the userId: "yoga_reminder_<userId>"
//   • On login → loadReminder(userId) only returns that user's reminder.
//   • On logout → reminders are NOT deleted; they stay in storage so
//     when the same user logs back in their reminder is restored.
//   • When a different user logs in, their own key is looked up and
//     returned (or null if they never set one).

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReminderStorage {
  // ✅ Key is scoped to userId — different users never share the same key
  static String _key(String userId) => 'yoga_reminder_$userId';

  /// Save the reminder for [userId].
  static Future<void> saveReminder({
    required String userId,
    required List<int> days,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {'days': days, 'hour': hour, 'minute': minute};
    await prefs.setString(_key(userId), jsonEncode(data));
  }

  /// Load the reminder for [userId]. Returns null if this user has
  /// never set a reminder.
  static Future<Map<String, dynamic>?> loadReminder(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Delete the saved reminder for [userId] (e.g. user taps "Delete Reminder").
  static Future<void> clearReminder(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
