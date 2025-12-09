import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('Username Transaction Tests', () {
    late FakeFirebaseFirestore firestore;
    
    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('transaction should read all documents before writing', () async {
      const userId = 'test_user_123';
      const newUsername = 'UpdatedUsername';
      
      // Setup initial user data
      await firestore
          .collection('users')
          .doc(userId)
          .collection('user_data')
          .doc('stats')
          .set({
        'username': 'OldUsername',
        'level': 5,
        'totalXp': 1500,
        'wordsLearned': 25,
        'quizzesCompleted': 10,
        'currentStreak': 3,
        'longestStreak': 7,
      });

      // Setup initial leaderboard data
      await firestore
          .collection('leaderboard_stats')
          .doc(userId)
          .set({
        'displayName': 'OldUsername',
        'currentLevel': 5,
        'totalXp': 1500,
        'wordsLearned': 25,
      });

      // Simulate the fixed transaction pattern: reads first, then writes
      await firestore.runTransaction((transaction) async {
        // Define document references
        final userDataRef = firestore
            .collection('users')
            .doc(userId)
            .collection('user_data')
            .doc('stats');
        
        final leaderboardRef = firestore
            .collection('leaderboard_stats')
            .doc(userId);

        // PHASE 1: Perform all reads first
        final userDataDoc = await transaction.get(userDataRef);
        final leaderboardDoc = await transaction.get(leaderboardRef);

        // PHASE 2: Perform all writes after reads
        transaction.update(userDataRef, {
          'username': newUsername,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        if (leaderboardDoc.exists) {
          transaction.update(leaderboardRef, {
            'displayName': newUsername,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // This shouldn't happen in this test, but included for completeness
          final userData = userDataDoc.data();
          transaction.set(leaderboardRef, {
            'userId': userId,
            'displayName': newUsername,
            'currentLevel': userData?['level'] ?? 1,
            'totalXp': userData?['totalXp'] ?? 0,
            'wordsLearned': userData?['wordsLearned'] ?? 0,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      // Verify both documents were updated correctly
      final updatedUserData = await firestore
          .collection('users')
          .doc(userId)
          .collection('user_data')
          .doc('stats')
          .get();
      
      final updatedLeaderboard = await firestore
          .collection('leaderboard_stats')
          .doc(userId)
          .get();

      expect(updatedUserData.data()!['username'], equals(newUsername));
      expect(updatedLeaderboard.data()!['displayName'], equals(newUsername));
    });

    test('transaction should create leaderboard entry if it does not exist', () async {
      const userId = 'new_user_456';
      const newUsername = 'NewUser';
      
      // Setup only user data, no leaderboard entry
      await firestore
          .collection('users')
          .doc(userId)
          .collection('user_data')
          .doc('stats')
          .set({
        'username': 'TempUsername',
        'level': 2,
        'totalXp': 500,
        'wordsLearned': 10,
        'quizzesCompleted': 5,
        'currentStreak': 1,
        'longestStreak': 3,
      });

      // Run transaction with read-before-write pattern
      await firestore.runTransaction((transaction) async {
        final userDataRef = firestore
            .collection('users')
            .doc(userId)
            .collection('user_data')
            .doc('stats');
        
        final leaderboardRef = firestore
            .collection('leaderboard_stats')
            .doc(userId);

        // Read phase
        final userDataDoc = await transaction.get(userDataRef);
        final leaderboardDoc = await transaction.get(leaderboardRef);

        // Write phase
        transaction.update(userDataRef, {
          'username': newUsername,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        if (leaderboardDoc.exists) {
          transaction.update(leaderboardRef, {
            'displayName': newUsername,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new leaderboard entry with user data
          final userData = userDataDoc.data();
          transaction.set(leaderboardRef, {
            'userId': userId,
            'displayName': newUsername,
            'currentLevel': userData?['level'] ?? 1,
            'highestLevel': userData?['level'] ?? 1,
            'totalXp': userData?['totalXp'] ?? 0,
            'weeklyXp': 0,
            'currentStreak': userData?['currentStreak'] ?? 0,
            'longestStreak': userData?['longestStreak'] ?? 0,
            'quizzesCompleted': userData?['quizzesCompleted'] ?? 0,
            'wordsLearned': userData?['wordsLearned'] ?? 0,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      // Verify leaderboard entry was created with correct data
      final leaderboardDoc = await firestore
          .collection('leaderboard_stats')
          .doc(userId)
          .get();

      expect(leaderboardDoc.exists, isTrue);
      expect(leaderboardDoc.data()!['displayName'], equals(newUsername));
      expect(leaderboardDoc.data()!['currentLevel'], equals(2));
      expect(leaderboardDoc.data()!['totalXp'], equals(500));
      expect(leaderboardDoc.data()!['wordsLearned'], equals(10));
    });
  });
}
