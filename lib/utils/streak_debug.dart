import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Debug helper for streak verification
class StreakDebug {
  static Future<void> verifyStreakData(String userId) async {
    if (!kDebugMode) return;

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get data from all sources
      final userDoc = await firestore.collection('users').doc(userId).get();
      final leaderboardDoc = await firestore.collection('leaderboard_stats').doc(userId).get();
      final summaryDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('summary')
          .get();

      final userData = userDoc.data();
      final leaderboardData = leaderboardDoc.data();
      final summaryData = summaryDoc.data();

      // Check for inconsistencies
      final userStreak = userData?['currentStreak'] as int?;
      final leaderboardStreak = leaderboardData?['currentStreak'] as int?;
      final summaryStreak = summaryData?['currentStreak'] as int?;

      if (userStreak != leaderboardStreak || userStreak != summaryStreak) {

      } else {

      }

    } catch (e) {

    }
  }

  /// Check if streak should be reset
  static Future<void> checkStreakReset(String userId) async {
    if (!kDebugMode) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      final lastActivityDate = userData?['lastActivityDate'] as Timestamp?;
      
      if (lastActivityDate == null) {

        return;
      }

      final lastDate = lastActivityDate.toDate().toUtc();
      final now = DateTime.now().toUtc();
      final daysDiff = now.difference(lastDate).inDays;

      if (daysDiff > 1) {

      } else if (daysDiff == 1) {

      } else {

      }
    } catch (e) {

    }
  }
}
