// lib/services/daily_word_service.dart
// Daily Word System with 10 free + 5 ad bonus words

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import '../models/word_model.dart';
import 'firestore_schema.dart';
import 'ad_service.dart';
import '../di/locator.dart';
import '../utils/feature_flags.dart';
import '../utils/id_list_sanitizer.dart';
import '../utils/retry_helper.dart';

/// Daily Word Service
/// Manages daily word assignments with smart selection algorithm
class DailyWordService {
  static const Duration _turkeyOffset = Duration(hours: 3);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final AdService _adService = locator<AdService>();

  static const int dailyWordCount = 10;
  static const int bonusWordCount = 5;
  static const int totalMaxWords = dailyWordCount + bonusWordCount;
  static const Duration extraUnlockCooldown = Duration(minutes: 10);
  static const String lastWordUnlockKey = 'lastWordUnlockAt';

  DateTime _nowInTurkey() {
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.add(_turkeyOffset);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Get today's date string in TR local time (UTC+3) (YYYY-MM-DD format)
  String _getTodayDateString() {
    final trNow = _nowInTurkey();
    return _formatDate(trNow);
  }

  /// Expose current date key for UI layers to stay in sync with backend.
  String getCurrentDateKey() => _getTodayDateString();

  /// Convert various date types (Timestamp | DateTime | String) to YYYY-MM-DD (UTC)
  String _toDateString(dynamic value) {
    DateTime dt;
    if (value is Timestamp) {
      dt = value.toDate().toUtc();
    } else if (value is DateTime) {
      dt = value.toUtc();
    } else if (value is String) {
      // Assume already formatted; sanitize to first 10 chars (YYYY-MM-DD)
      final s = value.trim();
      if (s.length >= 10) return s.substring(0, 10);
      // Fallback: try parsing
      try {
        dt = DateTime.parse(s).toUtc();
      } catch (_) {
        dt = DateTime.now().toUtc();
      }
    } else {
      dt = DateTime.now().toUtc();
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Check if the local cooldown prevents unlocking extra words
  Future<bool> isExtraUnlockCooldownActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMillis = prefs.getInt(lastWordUnlockKey);
      if (lastMillis == null) return false;
      final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
      final now = DateTime.now();
      return now.difference(last) < extraUnlockCooldown;
    } catch (_) {
      return false;
    }
  }

  /// Get remaining cooldown time, or Duration.zero if none
  Future<Duration> getExtraUnlockCooldownRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMillis = prefs.getInt(lastWordUnlockKey);
      if (lastMillis == null) return Duration.zero;
      final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
      final now = DateTime.now();
      final elapsed = now.difference(last);
      final remaining = extraUnlockCooldown - elapsed;
      return remaining.isNegative ? Duration.zero : remaining;
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Mark the cooldown start time after successful unlock
  Future<void> markExtraUnlockUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(lastWordUnlockKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // noop
    }
  }

  /// Get next reset time (midnight in TR, stored as UTC)
  DateTime getNextResetTime() {
    final trNow = _nowInTurkey();
    final trTomorrowMidnightUtc =
        DateTime.utc(trNow.year, trNow.month, trNow.day + 1)
            .subtract(_turkeyOffset);
    return trTomorrowMidnightUtc;
  }

  /// Get time remaining until reset (aligned with TR midnight)
  Duration getTimeUntilReset() {
    final nowUtc = DateTime.now().toUtc();
    final nextResetUtc = getNextResetTime();
    final remaining = nextResetUtc.difference(nowUtc);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get today's words for a user
  Future<Map<String, dynamic>> getTodaysWords(String userId) async {
    try {
      final today = _getTodayDateString();
      
      // Check cache first
      if (_cachedDailyWords != null &&
          _cachedDailyWordsUserId == userId &&
          _cachedDailyWordsDate == today) {

        return _cachedDailyWords!;
      }

      final path = FirestoreSchema.getDailyWordsPath(userId, today);

      // Use retry for network resilience
      final doc = await RetryHelper.retry(
        () => _firestore.doc(path).get(),
        maxAttempts: 3,
        retryIf: RetryHelper.isRetryableError,
      );

      if (!doc.exists) {

        return await generateDailyWords(userId);
      }

      final data = doc.data()!;
      final dateStr = _toDateString(data['date'] ?? today);
      
      // Check if the stored date matches today's date
      if (dateStr != today) {

        return await generateDailyWords(userId);
      }

      final rawDailyWords = data['dailyWords'];
      final rawExtraWords = data['extraWords'];
      final rawCompletedWords = data['completedWords'];

      final dailyWordIds =
          sanitizeIdList(rawDailyWords, context: 'dailyWords/$userId/$dateStr');
      final extraWordIds =
          sanitizeIdList(rawExtraWords, context: 'extraWords/$userId/$dateStr');
      final completedWordIds = sanitizeIdList(
        rawCompletedWords,
        context: 'completedWords/$userId/$dateStr',
      );

      final needsRepair =
          _listNeedsRepair(rawDailyWords, dailyWordIds) ||
              _listNeedsRepair(rawExtraWords, extraWordIds) ||
              _listNeedsRepair(rawCompletedWords, completedWordIds);

      if (needsRepair) {
        Future.microtask(
          () => _repairDailyWordsDoc(
            userId: userId,
            date: dateStr,
            dailyWords: dailyWordIds,
            extraWords: extraWordIds,
            completedWords: completedWordIds,
          ),
        );
      }

      final result = {
        'date': dateStr,
        'dailyWords': dailyWordIds,
        'extraWords': extraWordIds,
        'completedWords': completedWordIds,
        'hasWatchedAd': data['hasWatchedAd'] ?? false,
        // Optional metadata normalized to strings for robustness
        'createdAt': data.containsKey('createdAt') ? _toDateString(data['createdAt']) : null,
        'updatedAt': data.containsKey('updatedAt') ? _toDateString(data['updatedAt']) : null,
      };
      
      // Cache the result
      _cachedDailyWords = result;
      _cachedDailyWordsUserId = userId;
      _cachedDailyWordsDate = dateStr;
      
      return result;
    } catch (e) {

      rethrow;
    }
  }

  /// Generate daily words for a user
  Future<Map<String, dynamic>> generateDailyWords(String userId) async {
    try {
      final today = _getTodayDateString();

      // Get word IDs using smart selection algorithm
      final rawWordIds = await _selectDailyWords(userId, dailyWordCount);
      final wordIds =
          sanitizeIdList(rawWordIds, context: 'generateDailyWords/$userId');

      if (wordIds.isEmpty) {

        return {
          'date': today,
          'dailyWords': <String>[],
          'extraWords': <String>[],
          'completedWords': <String>[],
          'hasWatchedAd': false,
        };
      }

      // Create daily words document
      final dailyWordsData = FirestoreSchema.createDailyWords(
        date: today,
        dailyWords: wordIds,
        extraWords: const <String>[],
        completedWords: const <String>[],
      );

      final path = FirestoreSchema.getDailyWordsPath(userId, today);

      await _firestore.doc(path).set(dailyWordsData);

      final result = {
        'date': today,
        'dailyWords': wordIds,
        'extraWords': <String>[],
        'completedWords': <String>[],
        'hasWatchedAd': false,
      };
      
      // Cache the result
      _cachedDailyWords = result;
      _cachedDailyWordsUserId = userId;
      _cachedDailyWordsDate = today;
      
      return result;
    } catch (e) {

      rethrow;
    }
  }

  // Cache for loaded words from JSON
  List<Word>? _cachedWords;
  
  // Cache for user progress (expires after 5 minutes)
  Map<String, Map<String, dynamic>>? _cachedUserProgress;
  String? _cachedProgressUserId;
  DateTime? _progressCacheTime;
  static const Duration _progressCacheExpiry = Duration(minutes: 5);
  
  // Cache for daily words (expires at midnight)
  Map<String, dynamic>? _cachedDailyWords;
  String? _cachedDailyWordsUserId;
  String? _cachedDailyWordsDate;

  /// Parse words JSON in isolate (top-level function required)
  static List<Word> _parseWordsJson(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Load words from local JSON file
  Future<List<Word>> _loadWordsFromJson() async {
    if (_cachedWords != null) {

      return _cachedWords!;
    }

    try {

      final String jsonString = await rootBundle.loadString('assets/words/1kwords.json');
      
      // Parse in isolate to avoid blocking UI
      _cachedWords = await compute(_parseWordsJson, jsonString);

      return _cachedWords!;
    } catch (e) {

      return [];
    }
  }

  /// Get user progress with caching and retry
  Future<Map<String, Map<String, dynamic>>> _getUserProgress(String userId) async {
    // Check if cache is valid
    if (_cachedUserProgress != null &&
        _cachedProgressUserId == userId &&
        _progressCacheTime != null &&
        DateTime.now().difference(_progressCacheTime!) < _progressCacheExpiry) {

      return _cachedUserProgress!;
    }

    // Use retry mechanism for network resilience
    final progressSnapshot = await RetryHelper.retry(
      () => _firestore
          .collection('users')
          .doc(userId)
          .collection(FirestoreSchema.userWordProgressSubcollection)
          .get(),
      maxAttempts: 3,
      retryIf: RetryHelper.isRetryableError,
    );

    final userProgress = <String, Map<String, dynamic>>{};
    for (final doc in progressSnapshot.docs) {
      userProgress[doc.id] = doc.data();
    }

    // Update cache
    _cachedUserProgress = userProgress;
    _cachedProgressUserId = userId;
    _progressCacheTime = DateTime.now();

    return userProgress;
  }

  /// Smart word selection algorithm (using local JSON)
  Future<List<String>> _selectDailyWords(String userId, int count) async {
    try {

      // Load words from JSON
      final allWords = await _loadWordsFromJson();
      if (allWords.isEmpty) {

        return [];
      }

      // Get user's word progress (cached)
      final userProgress = await _getUserProgress(userId);

      // Get recently used words (last 7 days)
      final recentlyUsed = await _getRecentlyUsedWords(userId, 7);

      // Categorize words
      final unlearnedWords = <String>[];
      final lowSrsWords = <String>[];
      final otherWords = <String>[];

      for (final word in allWords) {
        final wordId = word.word.toLowerCase();

        // Skip recently used words
        if (recentlyUsed.contains(wordId)) continue;

        final progress = userProgress[wordId];

        if (progress == null) {
          // Unlearned word
          unlearnedWords.add(wordId);
        } else {
          final srsLevel = progress['srsLevel'] ?? 0;
          if (srsLevel <= 2) {
            // Low SRS level (still learning)
            lowSrsWords.add(wordId);
          } else {
            otherWords.add(wordId);
          }
        }
      }

      // Select words with priority: unlearned > low SRS > random
      final selectedWords = <String>[];
      final random = Random();

      // 1. Prioritize unlearned words (60%)
      final unlearnedCount = min((count * 0.6).ceil(), unlearnedWords.length);
      if (unlearnedWords.isNotEmpty) {
        unlearnedWords.shuffle(random);
        selectedWords.addAll(unlearnedWords.take(unlearnedCount));
      }

      // 2. Add low SRS words (30%)
      final lowSrsCount = min(
        (count * 0.3).ceil(),
        min(lowSrsWords.length, count - selectedWords.length),
      );
      if (lowSrsWords.isNotEmpty && selectedWords.length < count) {
        lowSrsWords.shuffle(random);
        selectedWords.addAll(lowSrsWords.take(lowSrsCount));
      }

      // 3. Fill remaining with random words
      if (selectedWords.length < count && otherWords.isNotEmpty) {
        otherWords.shuffle(random);
        selectedWords.addAll(otherWords.take(count - selectedWords.length));
      }

      // If still not enough, use recently used words as fallback
      if (selectedWords.length < count) {
        final allWordIds = allWords.map((w) => w.word.toLowerCase()).toList();
        allWordIds.shuffle(random);
        for (final wordId in allWordIds) {
          if (!selectedWords.contains(wordId)) {
            selectedWords.add(wordId);
            if (selectedWords.length >= count) break;
          }
        }
      }

      return sanitizeIdList(
        selectedWords.take(count).toList(),
        context: 'selectDailyWords/$userId',
      );
    } catch (e) {

      return [];
    }
  }

  /// Get recently used words from last N days
  Future<Set<String>> _getRecentlyUsedWords(String userId, int days) async {
    try {
      final recentWords = <String>{};
      final trNow = _nowInTurkey();

      for (int i = 1; i <= days; i++) {
        final date = trNow.subtract(Duration(days: i));
        final dateString = _formatDate(date);

        final path = FirestoreSchema.getDailyWordsPath(userId, dateString);
        final doc = await _firestore.doc(path).get();

        if (doc.exists) {
          final data = doc.data()!;
          final dailyWords = sanitizeIdList(
            data['dailyWords'],
            context: 'recent/dailyWords/$userId/$dateString',
          );
          final extraWords = sanitizeIdList(
            data['extraWords'],
            context: 'recent/extraWords/$userId/$dateString',
          );
          recentWords.addAll(dailyWords);
          recentWords.addAll(extraWords);
        }
      }

      return recentWords;
    } catch (e) {

      return {};
    }
  }

  /// Check if user can watch ad for extra words
  Future<bool> canWatchAdForExtraWords(String userId) async {
    try {
      final today = _getTodayDateString();
      final path = FirestoreSchema.getDailyWordsPath(userId, today);
      final doc = await _firestore.doc(path).get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final hasWatchedAd = data['hasWatchedAd'] ?? false;

      return !hasWatchedAd;
    } catch (e) {

      return false;
    }
  }

  /// Generate extra words after watching ad (using local JSON)
  Future<List<String>> generateExtraWords(String userId) async {
    try {
      final today = _getTodayDateString();

      // Load words from JSON
      final allWords = await _loadWordsFromJson();
      if (allWords.isEmpty) {

        return [];
      }

      // Get current daily words to avoid duplicates
      final dailyWordsData = await getTodaysWords(userId);
      final existingDailyWords = sanitizeIdList(
        dailyWordsData['dailyWords'],
        context: 'generateExtraWords/existing',
      );
      final existingExtraWords = sanitizeIdList(
        dailyWordsData['extraWords'],
        context: 'generateExtraWords/existingExtra',
      );

      // Get all existing word IDs
      final existingWordIds = <String>{...existingDailyWords, ...existingExtraWords};

      // Get user's learned words to exclude them (using cache)
      final userProgress = await _getUserProgress(userId);
      final learnedWordIds = userProgress.entries
          .where((entry) => (entry.value['srsLevel'] ?? 0) > 3)
          .map((entry) => entry.key)
          .toSet();

      // Filter available words from JSON
      final availableWords = allWords
          .where((word) {
            final wordId = word.word.toLowerCase();
            return !existingWordIds.contains(wordId) && 
                   !learnedWordIds.contains(wordId);
          })
          .map((word) => word.word.toLowerCase())
          .toList();

      if (availableWords.isEmpty) {

        return [];
      }

      // Shuffle and select bonus words
      availableWords.shuffle(Random());
      final selectedExtraWords = availableWords.take(bonusWordCount).toList();

      // Update Firestore document
      final path = FirestoreSchema.getDailyWordsPath(userId, today);
      await _firestore.doc(path).update({
        'extraWords': FieldValue.arrayUnion(selectedExtraWords),
        'hasWatchedAd': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Invalidate cache so next getTodaysWords fetches fresh data
      _cachedDailyWords = null;
      _cachedDailyWordsUserId = null;
      _cachedDailyWordsDate = null;

      return selectedExtraWords;
    } catch (e) {

      return [];
    }
  }

  /// Add extra words after watching ad (deprecated - use generateExtraWords)
  @Deprecated('Use generateExtraWords instead')
  Future<List<String>?> addExtraWordsAfterAd(String userId) async {
    try {
      // Show rewarded ad
      final adWatched = await _adService.showRewardedAd();

      if (!adWatched) {
        return null;
      }

      final callable = _functions.httpsCallable('verifyRewardAndGrantExtraWords');
      final result = await callable.call({'userId': userId});
      final payload = Map<String, dynamic>.from(
        (result.data as Map?) ?? const {},
      );

      final extraWordIds = sanitizeIdList(
        payload['extraWords'],
        context: 'extraWordsCallable/$userId',
      );

      if (extraWordIds.isEmpty) {
        return null;
      }

      // Start local cooldown after successful unlock (UI hint only)
      await markExtraUnlockUsed();

      return extraWordIds;
    } catch (e) {

      return null;
    }
  }

  /// Mark word as completed
  Future<void> markWordAsCompleted(String userId, String wordId) async {
    try {
      final today = _getTodayDateString();
      final path = FirestoreSchema.getDailyWordsPath(userId, today);

      final sanitizedWordIds = sanitizeIdList(
        [wordId],
        context: 'completedWords/$userId/$today',
      );

      if (sanitizedWordIds.isEmpty) {

        return;
      }

      await _firestore.doc(path).update({
        'completedWords': FieldValue.arrayUnion(sanitizedWordIds),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {

    }
  }

  /// Fetch the global Word of the Day stored under /daily_words/{date}.
  /// Returns null when the document is missing or invalid.
  Future<Word?> getGlobalWordOfDay({DateTime? date}) async {
    final target = (date ?? DateTime.now()).toUtc();
    final docId =
        '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';

    try {
      final doc = await _firestore.collection('daily_words').doc(docId).get();

      if (!doc.exists) {

        return null;
      }

      final data = doc.data();
      if (data == null) {
        return null;
      }

      // Support nested wordData payloads as well as flat documents.
      Map<String, dynamic> wordData;
      final dynamicPayload = data['wordData'];
      if (dynamicPayload is Map<String, dynamic>) {
        wordData = Map<String, dynamic>.from(dynamicPayload);
      } else {
        wordData = Map<String, dynamic>.from(data);
      }

      final wordText = (wordData['word'] ?? '').toString().trim();
      if (wordText.isEmpty) {

        return null;
      }

      final meaning = (wordData['meaning'] ?? '').toString();
      final exampleSentence =
          (wordData['exampleSentence'] ?? wordData['example'] ?? '').toString();
      final translation = (wordData['tr'] ?? '').toString();
      final category = (wordData['category'] ?? '').toString();

      return Word(
        word: wordText,
        meaning: meaning,
        example: exampleSentence,
        tr: translation,
        exampleSentence: exampleSentence,
        isFavorite: false,
        nextReviewDate: null,
        interval: 1,
        correctStreak: 0,
        tags: const [],
        srsLevel: 0,
        isCustom: false,
        category: category.isEmpty ? null : category,
        createdAt: null,
      );
    } catch (e) {

      return null;
    }
  }

  /// Get word details by ID (from local JSON)
  Future<Word?> getWordById(String wordId) async {
    try {
      final allWords = await _loadWordsFromJson();
      final word = allWords.firstWhere(
        (w) => w.word.toLowerCase() == wordId.toLowerCase(),
        orElse: () => Word(word: '', meaning: '', example: ''),
      );
      
      if (word.word.isEmpty) {

        return null;
      }
      
      return word;
    } catch (e) {

      return null;
    }
  }

  /// Get multiple words by IDs (from local JSON)
  Future<List<Word>> getWordsByIds(List<String> wordIds) async {
    try {
      final sanitizedIds = sanitizeIdList(
        wordIds,
        context: 'getWordsByIds',
      );
      if (sanitizedIds.isEmpty) {

        return [];
      }

      // Load words from JSON
      final allWords = await _loadWordsFromJson();
      if (allWords.isEmpty) {

        return [];
      }

      // Create a map for fast lookup
      final wordMap = <String, Word>{};
      for (final word in allWords) {
        wordMap[word.word.toLowerCase()] = word;
      }

      // Find requested words
      final words = <Word>[];
      for (final wordId in sanitizedIds) {
        final word = wordMap[wordId.toLowerCase()];
        if (word != null) {
          words.add(word);
        } else {

        }
      }

      return words;
    } catch (e, stackTrace) {

      return [];
    }
  }

  /// Initialize ad service
  Future<void> initializeAdService() async {
    // Geçici reklam devre dışı bırakma: yalnızca etkinse başlat
    if (FeatureFlags.adsEnabled) {
      await AdService.initialize();
      await _adService.loadRewardedAd();
    }
  }

  /// Clear all caches
  void clearCache() {
    _cachedWords = null;
    _cachedUserProgress = null;
    _cachedProgressUserId = null;
    _progressCacheTime = null;
    _cachedDailyWords = null;
    _cachedDailyWordsUserId = null;
    _cachedDailyWordsDate = null;

  }

  /// Dispose
  void dispose() {
    clearCache();
    _adService.dispose();
  }

  bool _listNeedsRepair(dynamic raw, List<String> sanitized) {
    if (raw == null) {
      return sanitized.isNotEmpty;
    }
    if (raw is! List) {
      return sanitized.isNotEmpty;
    }
    if (raw.length != sanitized.length) {
      return true;
    }
    for (int i = 0; i < sanitized.length; i++) {
      final entry = raw[i];
      if (entry is! String) {
        return true;
      }
      if (entry.trim() != sanitized[i]) {
        return true;
      }
    }
    return false;
  }

  Future<void> _repairDailyWordsDoc({
    required String userId,
    required String date,
    required List<String> dailyWords,
    required List<String> extraWords,
    required List<String> completedWords,
  }) async {
    try {
      final path = FirestoreSchema.getDailyWordsPath(userId, date);
      await _firestore.doc(path).update({
        'dailyWords': dailyWords,
        'extraWords': extraWords,
        'completedWords': completedWords,
        'updatedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {

    }
  }
}

