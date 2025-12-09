import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local streak tracker for notification purposes
/// Works alongside the Firestore StreakService for offline tracking
/// 
/// This service is specifically designed for:
/// - Determining notification messages
/// - Checking if user studied today (for notification scheduling)
/// - Fast local access without network calls
class LocalStreakTracker {
  LocalStreakTracker._();
  static final LocalStreakTracker _instance = LocalStreakTracker._();
  factory LocalStreakTracker() => _instance;

  // SharedPreferences keys
  static const String _kLocalStreakCurrent = 'local_streak_current';
  static const String _kLocalStreakLastStudyDate = 'local_streak_last_study_date';

  /// Get today's date in YYYY-MM-DD format (UTC)
  String _getTodayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Record a study session locally
  Future<void> recordStudySession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayKey();
      final lastStudyDateStr = prefs.getString(_kLocalStreakLastStudyDate);
      
      // If already studied today, skip
      if (lastStudyDateStr == today) {
        return;
      }
      
      // Calculate new streak
      int newStreak = 1;
      if (lastStudyDateStr != null) {
        try {
          final lastDate = DateTime.parse(lastStudyDateStr);
          final todayDate = DateTime.parse(today);
          final daysDiff = todayDate.difference(lastDate).inDays;
          
          if (daysDiff == 1) {
            // Consecutive day
            final currentStreak = prefs.getInt(_kLocalStreakCurrent) ?? 0;
            newStreak = currentStreak + 1;
          }
          // else: daysDiff > 1 means streak broken, reset to 1
        } catch (e) {
          if (kDebugMode) {
          }
        }
      }
      
      await prefs.setInt(_kLocalStreakCurrent, newStreak);
      await prefs.setString(_kLocalStreakLastStudyDate, today);
      
      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  /// Get the current local streak count
  Future<int> getCurrentStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastStudyDateStr = prefs.getString(_kLocalStreakLastStudyDate);
      
      if (lastStudyDateStr == null) {
        return 0;
      }
      
      // Check if streak is still valid (not broken)
      final lastDate = DateTime.parse(lastStudyDateStr);
      final today = DateTime.now().toUtc();
      final daysDiff = today.difference(lastDate).inDays;
      
      if (daysDiff > 1) {
        // Streak broken, return 0
        return 0;
      }
      
      return prefs.getInt(_kLocalStreakCurrent) ?? 0;
    } catch (e) {
      if (kDebugMode) {
      }
      return 0;
    }
  }

  /// Check if user has studied today
  Future<bool> hasStudiedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastStudyDateStr = prefs.getString(_kLocalStreakLastStudyDate);
      final today = _getTodayKey();
      return lastStudyDateStr == today;
    } catch (e) {
      if (kDebugMode) {
      }
      return false;
    }
  }

  /// Sync local streak with Firestore streak value
  /// Call this when app starts to ensure consistency
  Future<void> syncWithFirestore(int firestoreStreak) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLocalStreakCurrent, firestoreStreak);
      
      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }
}
