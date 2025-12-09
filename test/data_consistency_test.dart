import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('Data Consistency Tests', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test(
      'learnedWordsCount should sync between user_data and learned_words collection',
      () async {
        const userId = 'test_user_123';

        // Mock learned words in subcollection
        await firestore
            .collection('users')
            .doc(userId)
            .collection('words')
            .doc('word1')
            .set({'learned': true, 'word': 'test1'});

        await firestore
            .collection('users')
            .doc(userId)
            .collection('words')
            .doc('word2')
            .set({'learned': true, 'word': 'test2'});

        // Mock user_data stats with incorrect count
        await firestore
            .collection('users')
            .doc(userId)
            .collection('user_data')
            .doc('stats')
            .set({'wordsLearned': 5}); // incorrect count

        // Mock leaderboard_stats with incorrect count
        await firestore.collection('leaderboard_stats').doc(userId).set({
          'wordsLearned': 3,
          'displayName': 'TestUser',
        }); // incorrect count

        // Get actual learned words count
        final learnedWordsSnapshot =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('words')
                .where('learned', isEqualTo: true)
                .get();

        final actualCount = learnedWordsSnapshot.docs.length;
        expect(actualCount, equals(2));

        // Simulate sync operation (batch update)
        final batch = firestore.batch();

        final userDataRef = firestore
            .collection('users')
            .doc(userId)
            .collection('user_data')
            .doc('stats');

        final leaderboardRef = firestore
            .collection('leaderboard_stats')
            .doc(userId);

        batch.update(userDataRef, {'wordsLearned': actualCount});
        batch.update(leaderboardRef, {'wordsLearned': actualCount});

        await batch.commit();

        // Verify synchronization
        final userDataDoc = await userDataRef.get();
        final leaderboardDoc = await leaderboardRef.get();

        expect(userDataDoc.data()!['wordsLearned'], equals(2));
        expect(leaderboardDoc.data()!['wordsLearned'], equals(2));
      },
    );

    test(
      'username should sync between user profile and leaderboard_stats',
      () async {
        const userId = 'test_user_456';
        const newDisplayName = 'UpdatedUsername';

        // Mock initial leaderboard_stats
        await firestore.collection('leaderboard_stats').doc(userId).set({
          'displayName': 'OldUsername',
          'wordsLearned': 10,
          'currentLevel': 2,
        });

        // Simulate username update
        await firestore.collection('leaderboard_stats').doc(userId).update({
          'displayName': newDisplayName,
        });

        // Verify update
        final leaderboardDoc =
            await firestore.collection('leaderboard_stats').doc(userId).get();

        expect(leaderboardDoc.data()!['displayName'], equals(newDisplayName));
      },
    );

    test('batch operations should maintain data consistency', () async {
      const userId = 'test_user_789';
      const displayName = 'BatchTestUser';
      const wordsCount = 15;

      // Simulate batch operation for username and learned words sync
      final batch = firestore.batch();

      final userDataRef = firestore
          .collection('users')
          .doc(userId)
          .collection('user_data')
          .doc('stats');

      final leaderboardRef = firestore
          .collection('leaderboard_stats')
          .doc(userId);

      // Set initial data
      batch.set(userDataRef, {'wordsLearned': wordsCount});
      batch.set(leaderboardRef, {
        'displayName': displayName,
        'wordsLearned': wordsCount,
        'currentLevel': 3,
      });

      await batch.commit();

      // Verify both documents have consistent data
      final userDataDoc = await userDataRef.get();
      final leaderboardDoc = await leaderboardRef.get();

      expect(userDataDoc.data()!['wordsLearned'], equals(wordsCount));
      expect(leaderboardDoc.data()!['wordsLearned'], equals(wordsCount));
      expect(leaderboardDoc.data()!['displayName'], equals(displayName));
    });
  });
}
