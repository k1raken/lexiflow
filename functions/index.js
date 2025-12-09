const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const BONUS_WORD_COUNT = 5;
const BONUS_COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 hours
const TURKEY_OFFSET_MS = 3 * 60 * 60 * 1000;

const getTodayTurkeyDateString = () => {
  const now = new Date();
  const trDate = new Date(now.getTime() + TURKEY_OFFSET_MS);
  const year = trDate.getUTCFullYear();
  const month = trDate.getUTCMonth() + 1;
  const day = trDate.getUTCDate();
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
};

const shuffleArray = (array) => {
  for (let i = array.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
};

exports.verifyRewardAndGrantExtraWords = functions.https.onCall(async (data, context) => {
  const userId = data && data.userId;
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication is required.');
  }
  if (!userId || typeof userId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'A valid userId is required.');
  }
  if (context.auth.uid !== userId) {
    throw new functions.https.HttpsError('permission-denied', 'You can only claim rewards for your own account.');
  }

  const db = admin.firestore();
  const todayId = getTodayTurkeyDateString();
  const dailyDocRef = db.collection('users').doc(userId).collection('daily_words').doc(todayId);

  return db.runTransaction(async (tx) => {
    const dailyDocSnapshot = await tx.get(dailyDocRef);
    if (!dailyDocSnapshot.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'Daily words not initialized for today.');
    }

    const dailyData = dailyDocSnapshot.data() || {};
    if (dailyData.hasWatchedAd) {
      throw new functions.https.HttpsError('failed-precondition', 'Reward already claimed.');
    }

    const lastRewardedAt = dailyData.lastRewardedAt ? dailyData.lastRewardedAt.toDate() : null;
    if (lastRewardedAt) {
      const elapsed = Date.now() - lastRewardedAt.getTime();
      if (elapsed < BONUS_COOLDOWN_MS) {
        throw new functions.https.HttpsError('failed-precondition', 'Cooldown active.');
      }
    }

    const dailyWords = new Set(dailyData.dailyWords || []);
    const existingExtra = new Set(dailyData.extraWords || []);

    const publicWordsSnapshot = await db.collection('public_words').get();
    const candidateWordIds = [];
    publicWordsSnapshot.forEach((doc) => {
      if (!dailyWords.has(doc.id) && !existingExtra.has(doc.id)) {
        candidateWordIds.push(doc.id);
      }
    });

    if (candidateWordIds.length < BONUS_WORD_COUNT) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Not enough candidate words available for bonus.'
      );
    }

    shuffleArray(candidateWordIds);
    const bonusWords = candidateWordIds.slice(0, BONUS_WORD_COUNT);

    tx.update(dailyDocRef, {
      extraWords: bonusWords,
      hasWatchedAd: true,
      lastRewardedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('Rewarded extra words granted', { userId, bonusWords });

    return { extraWords: bonusWords };
  });
});
