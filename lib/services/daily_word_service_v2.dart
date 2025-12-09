// lib/services/daily_word_service_v2.dart
// New Daily Word System - 1kwords.json based with learned words filtering

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/word_model.dart';
import 'firestore_schema.dart';
import 'learned_words_service.dart';

/// New Daily Word Service V2
/// Uses 1kwords.json as master pool, filters learned words, intelligent selection
class DailyWordServiceV2 {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LearnedWordsService _learnedWordsService = LearnedWordsService();
  
  static const int dailyWordCount = 10;
  static const int bonusWordCount = 5;
  static const int totalMaxWords = dailyWordCount + bonusWordCount;
  
  // Cache for loaded words
  List<Word>? _allWords;

// Top-level parser for compute: parse 1kwords JSON to Word list
List<Word> _parseAllWordsJson(String jsonString) {
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
}
  
  /// Load all words from 1kwords.json
  Future<List<Word>> _loadAllWords() async {
    if (_allWords != null) return _allWords!;
    
    try {

      final String jsonString = await rootBundle.loadString(
        'assets/words/1kwords.json',
      );
      // Parse off-main-thread to avoid blocking UI
      _allWords = await compute(_parseAllWordsJson, jsonString);

      return _allWords!;
    } catch (e) {

      return [];
    }
  }
  
  /// Get today's date string in UTC (YYYY-MM-DD format)
  String _getTodayDateString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Expose current date key for UI layers to stay in sync with backend.
  String getCurrentDateKey() => _getTodayDateString();
  
  /// Get next reset time (midnight UTC)
  DateTime getNextResetTime() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    return tomorrow;
  }
  
  /// Get time remaining until reset
  Duration getTimeUntilReset() {
    final now = DateTime.now().toUtc();
    final nextReset = getNextResetTime();
    return nextReset.difference(now);
  }
  
  /// Get today's words for a user
  Future<Map<String, dynamic>> getTodaysWords(String userId) async {
    try {
      final today = _getTodayDateString();

      // Check if daily words already exist for today
      final existingWords = await _getDailyWordsFromCache(userId, today);
      if (existingWords != null) {
        // Verify the cached date matches today
        final cachedDate = existingWords['date'] as String?;
        if (cachedDate != null && cachedDate == today) {

          return existingWords;
        } else {

        }
      }
      
      // Generate new daily words

      return await generateDailyWords(userId);
    } catch (e) {

      rethrow;
    }
  }
  
  /// Generate daily words for a user
  Future<Map<String, dynamic>> generateDailyWords(String userId) async {
    try {
      final today = _getTodayDateString();

      // 1. Load all words from JSON
      final allWords = await _loadAllWords();
      if (allWords.isEmpty) {

        return _createEmptyDailyWords(today);
      }
      
      // 2. Get user's learned words
      final learnedWordIds = await _getLearnedWordIds(userId);

      // 3. Filter out learned words
      final unlearnedWords = allWords.where(
        (word) => !learnedWordIds.contains(word.word.toLowerCase())
      ).toList();

      // 4. Check if we have enough words
      if (unlearnedWords.length < dailyWordCount) {

        if (unlearnedWords.isEmpty) {
          // User completed all words!
          return _createCompletedDailyWords(today);
        }
        
        // Return remaining words
        final selectedWords = unlearnedWords.map((w) => w.word).toList();
        return await _saveDailyWords(userId, today, selectedWords);
      }
      
      // 5. Smart selection from unlearned words
      final selectedWords = await _selectRandomUnlearnedWords(
        unlearnedWords, 
        dailyWordCount,
        userId,
      );

      // 6. Save daily selection
      return await _saveDailyWords(userId, today, selectedWords);
      
    } catch (e) {

      rethrow;
    }
  }
  
  /// Select random unlearned words with smart filtering
  Future<List<String>> _selectRandomUnlearnedWords(
    List<Word> unlearnedWords, 
    int count,
    String userId,
  ) async {
    try {
      // Get recently used words (last 3 days to avoid immediate repetition)
      final recentlyUsed = await _getRecentlyUsedWords(userId, 3);
      
      // Filter out recently used words
      final availableWords = unlearnedWords.where(
        (word) => !recentlyUsed.contains(word.word.toLowerCase())
      ).toList();
      
      // If not enough available words, use all unlearned words
      final wordsToSelect = availableWords.isNotEmpty ? availableWords : unlearnedWords;
      
      // Shuffle and select
      final random = Random();
      wordsToSelect.shuffle(random);
      
      final selectedCount = count.clamp(0, wordsToSelect.length);
      return wordsToSelect.take(selectedCount).map((w) => w.word).toList();
      
    } catch (e) {

      return [];
    }
  }
  
  /// Get user's learned word IDs
  Future<Set<String>> _getLearnedWordIds(String userId) async {
    try {
      // Use LearnedWordsService to get learned words
      final learnedWords = await _learnedWordsService.getLearnedWords(userId);
      return learnedWords.map((word) => word.toLowerCase()).toSet();
    } catch (e) {

      return <String>{};
    }
  }
  
  /// Get recently used words from daily selections
  Future<Set<String>> _getRecentlyUsedWords(String userId, int days) async {
    try {
      final recentWords = <String>{};
      final now = DateTime.now().toUtc();
      
      for (int i = 1; i <= days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        final cachedWords = await _getDailyWordsFromCache(userId, dateString);
        if (cachedWords != null) {
          final dailyWords = List<String>.from(cachedWords['dailyWords'] ?? []);
          recentWords.addAll(dailyWords.map((w) => w.toLowerCase()));
        }
      }
      
      return recentWords;
    } catch (e) {

      return <String>{};
    }
  }
  
  /// Save daily words to both Firestore and local cache
  Future<Map<String, dynamic>> _saveDailyWords(
    String userId, 
    String date, 
    List<String> selectedWords,
  ) async {
    try {
      final dailyWordsData = {
        'date': date,
        'dailyWords': selectedWords,
        'extraWords': <String>[],
        'completedWords': <String>[],
        'hasWatchedAd': false,
        'generatedAt': FieldValue.serverTimestamp(),
      };
      
      // Save to Firestore
      final path = FirestoreSchema.getDailyWordsPath(userId, date);
      await _firestore.doc(path).set(dailyWordsData);
      
      // Save to local cache (Hive)
      await _saveDailyWordsToCache(userId, date, dailyWordsData);
      
      return {
        'date': date,
        'dailyWords': selectedWords,
        'extraWords': <String>[],
        'completedWords': <String>[],
        'hasWatchedAd': false,
      };
    } catch (e) {

      rethrow;
    }
  }
  
  /// Get daily words from local cache (Hive)
  Future<Map<String, dynamic>?> _getDailyWordsFromCache(String userId, String date) async {
    try {
      final box = await Hive.openBox('daily_words_cache');
      final key = '${userId}_$date';
      final cachedData = box.get(key);
      
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
      
      return null;
    } catch (e) {

      return null;
    }
  }
  
  /// Save daily words to local cache (Hive)
  Future<void> _saveDailyWordsToCache(String userId, String date, Map<String, dynamic> data) async {
    try {
      final box = await Hive.openBox('daily_words_cache');
      final key = '${userId}_$date';
      
      // Remove serverTimestamp for local storage
      final cacheData = Map<String, dynamic>.from(data);
      cacheData.remove('generatedAt');
      cacheData['cachedAt'] = DateTime.now().toIso8601String();
      
      await box.put(key, cacheData);
    } catch (e) {

    }
  }
  
  /// Create empty daily words response
  Map<String, dynamic> _createEmptyDailyWords(String date) {
    return {
      'date': date,
      'dailyWords': <String>[],
      'extraWords': <String>[],
      'completedWords': <String>[],
      'hasWatchedAd': false,
    };
  }
  
  /// Create completed daily words response (user learned all words)
  Map<String, dynamic> _createCompletedDailyWords(String date) {
    return {
      'date': date,
      'dailyWords': <String>[],
      'extraWords': <String>[],
      'completedWords': <String>[],
      'hasWatchedAd': false,
      'allWordsCompleted': true,
    };
  }
  
  /// Generate bonus words after watching ad
  Future<List<String>> generateBonusWords(String userId) async {
    try {

      // Load all words
      final allWords = await _loadAllWords();
      if (allWords.isEmpty) return [];
      
      // Get learned words
      final learnedWordIds = await _getLearnedWordIds(userId);
      
      // Get today's already selected words
      final today = _getTodayDateString();
      final todayWords = await _getDailyWordsFromCache(userId, today);
      final alreadySelected = <String>{};
      
      if (todayWords != null) {
        alreadySelected.addAll(List<String>.from(todayWords['dailyWords'] ?? []));
        alreadySelected.addAll(List<String>.from(todayWords['extraWords'] ?? []));
      }
      
      // Filter available words
      final availableWords = allWords.where((word) {
        final wordId = word.word.toLowerCase();
        return !learnedWordIds.contains(wordId) && 
               !alreadySelected.contains(word.word);
      }).toList();
      
      if (availableWords.isEmpty) {

        return [];
      }
      
      // Select bonus words
      final random = Random();
      availableWords.shuffle(random);
      
      final bonusCount = bonusWordCount.clamp(0, availableWords.length);
      final bonusWords = availableWords.take(bonusCount).map((w) => w.word).toList();

      return bonusWords;
      
    } catch (e) {

      return [];
    }
  }
  
  /// Mark word as completed for today
  Future<void> markWordCompleted(String userId, String wordId) async {
    try {
      final today = _getTodayDateString();
      final path = FirestoreSchema.getDailyWordsPath(userId, today);
      
      await _firestore.doc(path).update({
        'completedWords': FieldValue.arrayUnion([wordId]),
      });
      
      // Update cache as well
      final cachedData = await _getDailyWordsFromCache(userId, today);
      if (cachedData != null) {
        final completedWords = List<String>.from(cachedData['completedWords'] ?? []);
        if (!completedWords.contains(wordId)) {
          completedWords.add(wordId);
          cachedData['completedWords'] = completedWords;
          await _saveDailyWordsToCache(userId, today, cachedData);
        }
      }
      
    } catch (e) {

    }
  }
  
  /// Get learning statistics
  Future<Map<String, dynamic>> getLearningStatistics(String userId) async {
    try {
      final allWords = await _loadAllWords();
      final learnedWords = await _getLearnedWordIds(userId);
      
      final totalWords = allWords.length;
      final learnedCount = learnedWords.length;
      final remainingWords = totalWords - learnedCount;
      final progressPercentage = totalWords > 0 ? (learnedCount / totalWords) : 0.0;
      
      return {
        'totalWords': totalWords,
        'learnedWords': learnedCount,
        'remainingWords': remainingWords,
        'progressPercentage': progressPercentage,
        'isCompleted': remainingWords == 0,
      };
    } catch (e) {

      return {
        'totalWords': 0,
        'learnedWords': 0,
        'remainingWords': 0,
        'progressPercentage': 0.0,
        'isCompleted': false,
      };
    }
  }
  
  /// Get the first word from today's personal daily words for notifications
  /// Returns null if no words available for today
  Future<String?> getFirstDailyWordForNotification(String userId) async {
    try {
      final today = _getTodayDateString();

      // Try cache first for better performance
      final cachedWords = await _getDailyWordsFromCache(userId, today);
      if (cachedWords != null) {
        final dailyWords = List<String>.from(cachedWords['dailyWords'] ?? []);
        if (dailyWords.isNotEmpty) {

          return dailyWords[0];
        }
      }
      
      // Fallback to Firestore
      final path = FirestoreSchema.getDailyWordsPath(userId, today);
      final doc = await _firestore.doc(path).get();
      
      if (doc.exists) {
        final data = doc.data();
        final dailyWords = List<String>.from(data?['dailyWords'] ?? []);
        if (dailyWords.isNotEmpty) {

          return dailyWords[0];
        }
      }

      return null; // No words for today
    } catch (e) {

      return null;
    }
  }
}