import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_model.dart';
import 'srs_service.dart';
import '../models/daily_log.dart';
import 'favorites_cleanup_service.dart';
import 'word_loader.dart';
import 'sync_queue_service.dart';

// compute requires a top-level function; we provide a parser
List<Word> _parseWordsFromJsonString(String jsonString) {
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
}

class WordService {
  static const String _wordsBoxName = 'words';
  static const String _favoritesBoxName = 'favorites';
  static const String _dailyLogBoxName = 'daily_log';

  List<Word> _allWords = [];
  // hızlı tıklamalarda race condition önlemi
  final Set<String> _favoriteLocks = <String>{};

  Box<String> get favoritesBox => Hive.box<String>(_favoritesBoxName);

  Box<Word> get wordsBox => Hive.box<Word>(_wordsBoxName);

  ValueListenable<Box<String>> get favoritesListenable =>
      favoritesBox.listenable();

  Future<void> init() async {
    try {
      await Hive.openBox<Word>(_wordsBoxName);
    } catch (e) {
      // schema değişikliği durumunda eski veriyi temizle
      if (kDebugMode) {
      }
      await Hive.deleteBoxFromDisk(_wordsBoxName);
      await Hive.openBox<Word>(_wordsBoxName);
    }

    await Hive.openBox<String>(_favoritesBoxName);
    await Hive.openBox<DailyLog>(_dailyLogBoxName);

    await _loadWordsFromJson();
    await _hydrateFromFsrsMeta();

    // başlangıçta duplicate favorileri temizle
    final duplicatesRemoved =
        await FavoritesCleanupService.cleanupDuplicateFavorites();
    if (duplicatesRemoved > 0) {
      if (kDebugMode) {
          '🧹 Removed $duplicatesRemoved duplicate favorites during initialization',
        );
      }
    }

    final stats = FavoritesCleanupService.getFavoritesStats();
    if (kDebugMode) {
        '📊 Favorites stats: ${stats['total']} total, ${stats['unique']} unique, ${stats['duplicates']} duplicates',
      );
    }
  }

  Future<void> _loadWordsFromJson() async {
    try {
      if (kDebugMode) {
      }
      final String jsonString = await rootBundle.loadString(
        'assets/words/1kwords.json',
      );
      if (kDebugMode) {
      }
      // Parse on a background isolate to avoid main-thread jank
      _allWords = await compute(_parseWordsFromJsonString, jsonString);
      if (kDebugMode) {
      }
      if (kDebugMode) {
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
      }
      _allWords = [];
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // günlük 5 kelime (yeni veya bugün için mevcut olanlar)
  Future<List<Word>> getDailyWords() async {
    final todayKey = _getTodayKey();
    final dailyLogBox = Hive.box<DailyLog>(_dailyLogBoxName);

    final todayLog = dailyLogBox.get(todayKey);

    if (todayLog != null) {
      return todayLog.wordIndices
          .where((index) => index < _allWords.length)
          .map((index) => _allWords[index])
          .toList();
    }

    // bugün için yeni kelimeler oluştur
    final seenIndices = _getAllSeenWordIndices();
    final newWords = _getRandomUnseenWords(5, seenIndices);

    final newLog = DailyLog(
      date: todayKey,
      wordIndices: newWords.map((w) => _allWords.indexOf(w)).toList(),
    );
    await dailyLogBox.put(todayKey, newLog);

    return newWords;
  }

  // reklam sonrası +5 kelime daha
  Future<List<Word>> getExtendedDailyWords() async {
    final todayKey = _getTodayKey();
    final dailyLogBox = Hive.box<DailyLog>(_dailyLogBoxName);
    final todayLog = dailyLogBox.get(todayKey);

    if (todayLog == null) return [];

    final seenIndices = _getAllSeenWordIndices();
    final newWords = _getRandomUnseenWords(5, seenIndices);

    todayLog.wordIndices.addAll(newWords.map((w) => _allWords.indexOf(w)));
    todayLog.extended = true;
    await todayLog.save();

    return newWords;
  }

  Set<int> _getAllSeenWordIndices() {
    final dailyLogBox = Hive.box<DailyLog>(_dailyLogBoxName);
    final allIndices = <int>{};

    for (var log in dailyLogBox.values) {
      allIndices.addAll(log.wordIndices);
    }

    return allIndices;
  }

  List<Word> _getRandomUnseenWords(int count, Set<int> seenIndices) {
    final unseenIndices =
        List.generate(
          _allWords.length,
          (i) => i,
        ).where((i) => !seenIndices.contains(i)).toList();

    if (unseenIndices.isEmpty) {
      // tüm kelimeler görüldüyse baştan başla
      unseenIndices.addAll(List.generate(_allWords.length, (i) => i));
    }

    unseenIndices.shuffle(Random());
    final selectedIndices = unseenIndices.take(count).toList();

    return selectedIndices.map((i) => _allWords[i]).toList();
  }

  Future<void> toggleFavorite(Word word) async {
    final favBox = Hive.box<String>(_favoritesBoxName);
    final wordKey = word.word;

    if (favBox.values.contains(wordKey)) {
      // favorilerden çıkar - duplicate'ları önlemek için tümünü sil
      final keys = favBox.keys.toList();
      final keysToDelete = <dynamic>[];

      for (final key in keys) {
        if (favBox.get(key) == wordKey) {
          keysToDelete.add(key);
        }
      }

      for (final key in keysToDelete) {
        await favBox.delete(key);
      }

      word.isFavorite = false;
    } else {
      // favorilere ekle - duplicate kontrolü yap
      if (!favBox.values.contains(wordKey)) {
        await favBox.add(wordKey);
      }
      word.isFavorite = true;
    }

    if (word.isInBox) {
      await word.save();
    }
  }

  bool isFavorite(Word word) {
    final favBox = Hive.box<String>(_favoritesBoxName);
    return favBox.values.contains(word.word) || word.isFavorite;
  }

  // DEPRECATED - getFavoriteWordsFirestore kullan
  List<Word> getFavoriteWords() {
    if (kDebugMode) {
        '⚠️ WARNING: getFavoriteWords() is deprecated, use getFavoriteWordsFirestore()',
      );
    }
    final favBox = Hive.box<String>(_favoritesBoxName);
    final favoriteWordTexts = favBox.values.toSet();

    final favoriteWords =
        _allWords.where((word) {
          return favoriteWordTexts.contains(word.word) || word.isFavorite;
        }).toList();

    return favoriteWords;
  }

  Future<List<Word>> getFavoriteWordsFirestore(String userId) async {
    try {
      if (kDebugMode) {
      }

      final snapshot =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .get();

      final favoriteKeys = snapshot.docs.map((doc) => doc.id).toSet();
      if (kDebugMode) {
      }

      final words = mapFavoriteKeysToWords(favoriteKeys);
      if (kDebugMode) {
      }

      if (words.isEmpty && favoriteKeys.isNotEmpty) {
        if (kDebugMode) {
            '⚠️ [FIX] Keys exist but no words mapped. Checking _allWords...',
          );

          // DEBUG: key'lerin kelimelerle eşleşip eşleşmediğini kontrol et
          for (final key in favoriteKeys.take(3)) {
            final matchingWords =
                _allWords.where((w) => w.word == key).toList();
          }
        }
      }

      // FALLBACK: hiç kelime bulunamazsa public kelimeler döndür
      if (words.isEmpty) {
        if (kDebugMode) {
            '⚠️ [FIX] No favorite words found, trying public words fallback...',
          );
        }
        final publicWords = await getPublicWords(limit: 10);
        if (kDebugMode) {
        }
        return publicWords.take(7).toList();
      }

      return words;
    } catch (e) {
      if (kDebugMode) {
      }
      return [];
    }
  }

  // DEPRECATED - getRandomFavoritesFirestore kullan
  List<Word> getRandomFavorites(int count) {
    if (kDebugMode) {
        '⚠️ WARNING: getRandomFavorites() is deprecated, use getRandomFavoritesFirestore()',
      );
    }
    final favorites = getFavoriteWords();
    if (favorites.length <= count) return favorites;

    favorites.shuffle(Random());
    return favorites.take(count).toList();
  }

  Future<List<Word>> getRandomFavoritesFirestore(
    String userId,
    int count,
  ) async {
    try {
      if (kDebugMode) {
      }

      final favorites = await getFavoriteWordsFirestore(userId);
      if (kDebugMode) {
      }

      if (favorites.isEmpty) {
        if (kDebugMode) {
        }
        return [];
      }

      if (favorites.length <= count) {
        if (kDebugMode) {
        }
        return favorites;
      }

      favorites.shuffle(Random());
      final selected = favorites.take(count).toList();
      if (kDebugMode) {
      }
      return selected;
    } catch (e) {
      if (kDebugMode) {
      }
      return [];
    }
  }

  // Daily Challenge için veritabanından rastgele kelimeler
  List<Word> getRandomWordsFromDatabase(int count) {
    // sadece orijinal 1000+ kelimelik veritabanından (custom değil)
    final databaseWords = _allWords.where((word) => !word.isCustom).toList();

    if (databaseWords.length <= count) return databaseWords;

    databaseWords.shuffle(Random());
    return databaseWords.take(count).toList();
  }

  // rastgele kelimeler getir (async wrapper)
  Future<List<Word>> getRandomWords(int count) async {
    return getRandomWordsFromDatabase(count);
  }

  bool isTodayExtended() {
    final todayKey = _getTodayKey();
    final dailyLogBox = Hive.box<DailyLog>(_dailyLogBoxName);
    final todayLog = dailyLogBox.get(todayKey);
    return todayLog?.extended ?? false;
  }

  // özel kelime ekle (otomatik favorilere eklenir)
  Future<void> addCustomWord(Word word) async {
    try {
      if (word.word.trim().isEmpty) {
        throw Exception('validation: Kelime boş olamaz');
      }
      if (word.meaning.trim().isEmpty) {
        throw Exception('validation: Kelime anlamı boş olamaz');
      }

      // kelime zaten var mı kontrol et
      final existingWord = _allWords.firstWhere(
        (w) => w.word.toLowerCase() == word.word.toLowerCase(),
        orElse: () => Word(word: '', meaning: '', example: ''),
      );

      if (existingWord.word.isNotEmpty) {
        throw Exception('duplicate: Bu kelime zaten mevcut');
      }

      word.isCustom = true;
      word.isFavorite = true;

      final wordsBox = Hive.box<Word>(_wordsBoxName);
      await wordsBox.add(word);
      _allWords.add(word);

      // favorilere ekle - duplicate kontrolü yap
      final favoritesBox = Hive.box<String>(_favoritesBoxName);
      if (!favoritesBox.values.contains(word.word)) {
        await favoritesBox.add(word.word);
      }

    } catch (e) {
      rethrow;
    }
  }

  // özel kelime sil (sadece custom ise)
  Future<bool> removeCustomWord(Word word) async {
    if (!word.isCustom) return false;

    final favoritesBox = Hive.box<String>(_favoritesBoxName);
    final index = favoritesBox.values.toList().indexOf(word.word);
    if (index != -1) {
      await favoritesBox.deleteAt(index);
    }

    await word.delete();
    _allWords.remove(word);

    return true;
  }

  List<Word> getAllWords() {
    return _allWords;
  }

  // bugün review edilmesi gereken kelime sayısı (SRS)
  int getDueReviewCount() {
    int count = 0;
    for (final w in _allWords) {
      if (SRSService.needsReview(w)) count++;
    }
    return count;
  }

  Future<void> _hydrateFromFsrsMeta() async {
    try {
      for (final w in _allWords) {
        final meta = await SRSService.getFsrsMeta(w);
        final stability = (meta['stability'] as num?)?.toDouble();
        if (stability != null && stability > 0) {
          final interval = stability.clamp(1.0, 3650.0).round();
          w.interval = interval;
          w.nextReviewDate = DateTime.now().add(Duration(days: interval));
          if (w.isInBox) {
            await w.save();
          }
        }
      }
    } catch (e) {
    }
  }

  // SRS (Spaced Repetition System) tabanlı günlük kelimeler
  List<Word> getDailyWordsWithSRS() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // öncelik 1: bugün review edilmesi gerekenler
    final wordsNeedingReview =
        _allWords.where((word) {
          if (word.nextReviewDate == null) return false;
          final reviewDate = DateTime(
            word.nextReviewDate!.year,
            word.nextReviewDate!.month,
            word.nextReviewDate!.day,
          );
          return reviewDate.isBefore(today) ||
              reviewDate.isAtSameMomentAs(today);
        }).toList();

    // öncelik 2: yeni kelimeler (srsLevel == 0)
    final newWords = _allWords.where((word) => word.srsLevel == 0).toList();
    newWords.shuffle(Random());

    // birleştir: toplamda 5 kelime
    final dailyWords = <Word>[];

    dailyWords.addAll(wordsNeedingReview.take(5));

    // kalan slotları yeni kelimelerle doldur
    if (dailyWords.length < 5) {
      final remaining = 5 - dailyWords.length;
      dailyWords.addAll(newWords.take(remaining));
    }

    return dailyWords;
  }

  // ============================================================================
  // FIRESTORE METHODS FOR CUSTOM WORDS (Personal Decks)
  // ============================================================================

  FirebaseFirestore? _firestore;
  FirebaseFirestore get firestore => _firestore ??= FirebaseFirestore.instance;

  // ============================================================================
  // FIRESTORE FAVORITES (users/{uid}/favorites/{wordId})
  // ============================================================================

  /// favori kelime ID'lerinin stream'i (kelime metni document ID olarak kullanılır)
  Stream<Set<String>> favoritesKeysStream(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// öğrenilen kelime ID'lerinin stream'i
  Stream<Set<String>> learnedWordsKeysStream(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('learned_words')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// favori key'leri memory'deki Word objelerine eşle
  List<Word> mapFavoriteKeysToWords(Set<String> keys) {
    if (keys.isEmpty) return [];

    // duplicate'ları önlemek için Map kullan
    final Map<String, Word> uniqueWords = {};

    for (final word in _allWords) {
      if (keys.contains(word.word) && !uniqueWords.containsKey(word.word)) {
        uniqueWords[word.word] = word;
      }
    }

    return uniqueWords.values.toList();
  }

  /// öğrenilen kelime key'lerini memory'deki Word objelerine eşle
  List<Word> mapLearnedKeysToWords(Set<String> keys) {
    if (keys.isEmpty) return [];

    final normalizedKeys =
        keys
            .map((key) => key.trim().toLowerCase())
            .where((key) => key.isNotEmpty)
            .toSet();

    final Map<String, Word> uniqueWords = {};
    for (final word in _allWords) {
      final normalizedWord = word.word.trim().toLowerCase();
      if (normalizedKeys.contains(normalizedWord) &&
          !uniqueWords.containsKey(normalizedWord)) {
        uniqueWords[normalizedWord] = word;
      }
    }

    return uniqueWords.values.toList();
  }

  Word? findWordByText(String wordText) {
    final normalized = wordText.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final word in _allWords) {
      if (word.word.trim().toLowerCase() == normalized) {
        return word;
      }
    }
    return null;
  }

  Future<List<Word>> getLearnedWordsFirestore(String userId) async {
    try {

      final snapshot =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('learned_words')
              .orderBy('learnedAt', descending: true)
              .get();

      final learnedKeys = snapshot.docs.map((doc) => doc.id).toSet();

      final words = mapLearnedKeysToWords(learnedKeys);

      return words;
    } catch (e) {
      return [];
    }
  }

  Future<void> addToLearnedWords(Word word, String userId) async {
    try {
      final learnedRef = firestore
          .collection('users')
          .doc(userId)
          .collection('learned_words')
          .doc(word.word);

      // duplicate'ları önlemek için kontrol et
      final existingDoc = await learnedRef.get();
      if (existingDoc.exists) {
        return;
      }

      await learnedRef.set({
        'word': word.word,
        'meaning': word.meaning,
        'tr': word.tr,
        'example': word.example,
        'isCustom': word.isCustom,
        'learnedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
    }
  }

  Future<List<Word>> getRandomLearnedWordsFirestore(
    String userId,
    int count,
  ) async {
    try {
        '🎯 [LEARNED] Getting $count random learned words for user: $userId',
      );

      final learnedWords = await getLearnedWordsFirestore(userId);
        '🎯 [LEARNED] Total learned words available: ${learnedWords.length}',
      );

      if (learnedWords.isEmpty) {
        return [];
      }

      if (learnedWords.length <= count) {
        return learnedWords;
      }

      learnedWords.shuffle(Random());
      final selected = learnedWords.take(count).toList();
      return selected;
    } catch (e) {
      return [];
    }
  }

  /// Firestore'da favori toggle (transaction + local lock ile)
  Future<void> toggleFavoriteFirestore(Word word, String userId) async {
    final key = '$userId|${word.word}';
    if (_favoriteLocks.contains(key)) return; // debounce/lock
    _favoriteLocks.add(key);

    final favRef = firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(word.word);

    final statsRef = firestore.collection('users').doc(userId);

    try {
      await firestore.runTransaction((tx) async {
        final favSnap = await tx.get(favRef);
        final statsSnap = await tx.get(statsRef);

        final currentCount = (statsSnap.data()?['favoritesCount'] ?? 0) as int;
        int nextCount = currentCount;

        if (favSnap.exists) {
          // favoriyi kaldır, ama hiçbir zaman 0'ın altına düşme
          tx.delete(favRef);
          nextCount = currentCount > 0 ? currentCount - 1 : 0;
        } else {
          tx.set(favRef, {
            'word': word.word,
            'meaning': word.meaning,
            'tr': word.tr,
            'example': word.example,
            'isCustom': word.isCustom,
            'addedAt': FieldValue.serverTimestamp(),
          });
          nextCount = currentCount + 1;
        }

        if (nextCount < 0) nextCount = 0; // savunma amaçlı clamp
        tx.set(statsRef, {
          'favoritesCount': nextCount,
        }, SetOptions(merge: true));
      });
    } finally {
      // ekstra tıklamaları absorbe etmek için kısa debounce
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _favoriteLocks.remove(key);
    }
  }

  /// OPTIMISTIC UI: Toggle favorite with instant local update and background sync
  /// This is the recommended method for better UX (no blocking, no loading spinners)
  Future<void> toggleFavoriteOptimistic(Word word, String userId) async {
    // Step 1: Update local state IMMEDIATELY (< 16ms)
    await toggleFavorite(word);
    
    // Step 2: Queue Firestore sync in background (no await = non-blocking)
    unawaited(_queueFavoriteSync(word, userId));
  }

  /// Background sync for favorite toggle
  Future<void> _queueFavoriteSync(Word word, String userId) async {
    final isFav = isFavorite(word);
    
    try {
      // Try to sync to Firestore immediately
      await _syncFavoriteToFirestore(word, userId, isFav);
      
      if (kDebugMode) {
      }
    } catch (e) {
      // Offline or error → Queue for later (silent, no user notification)
      if (kDebugMode) {
      }
      
      await SyncQueueService().addOperation(
        type: isFav ? 'favorite_add' : 'favorite_remove',
        data: {
          'userId': userId,
          'word': word.word,
          'meaning': word.meaning,
          'tr': word.tr,
          'example': word.example,
          'isCustom': word.isCustom,
        },
      );
    }
  }

  /// Sync favorite to Firestore (extracted for reuse)
  Future<void> _syncFavoriteToFirestore(Word word, String userId, bool isAdding) async {
    final favRef = firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(word.word);

    final statsRef = firestore.collection('users').doc(userId);

    await firestore.runTransaction((tx) async {
      final favSnap = await tx.get(favRef);
      final statsSnap = await tx.get(statsRef);

      final currentCount = (statsSnap.data()?['favoritesCount'] ?? 0) as int;
      int nextCount = currentCount;

      if (isAdding) {
        // Add favorite
        if (!favSnap.exists) {
          tx.set(favRef, {
            'word': word.word,
            'meaning': word.meaning,
            'tr': word.tr,
            'example': word.example,
            'isCustom': word.isCustom,
            'addedAt': FieldValue.serverTimestamp(),
          });
          nextCount = currentCount + 1;
        }
      } else {
        // Remove favorite
        if (favSnap.exists) {
          tx.delete(favRef);
          nextCount = currentCount > 0 ? currentCount - 1 : 0;
        }
      }

      if (nextCount < 0) nextCount = 0;
      tx.set(statsRef, {
        'favoritesCount': nextCount,
      }, SetOptions(merge: true));
    });
  }

  Stream<List<Map<String, dynamic>>> getCustomWordsStream(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('custom_words')
        // NOTE: index gereksinimi olmaması için orderBy kaldırıldı
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Firestore'a özel kelime ekle (Personal Decks için)
  Future<void> addCustomWordToFirestore({
    required String userId,
    required String word,
    required String meaning,
    required String example,
    String? deckId,
  }) async {
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('custom_words')
          .add({
            'word': word,
            'meaning': meaning,
            'example': example,
            'deckId': deckId ?? 'default',
            'createdAt': FieldValue.serverTimestamp(),
            'srsLevel': 0,
            'nextReviewDate': null,
          });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCustomWord(String userId, String wordId) async {
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('custom_words')
          .doc(wordId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getDecksStream(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('decks')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  Future<void> createDeck({
    required String userId,
    required String name,
    String? description,
  }) async {
    try {
      await firestore.collection('users').doc(userId).collection('decks').add({
        'name': name,
        'description': description ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'wordCount': 0,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDeck(String userId, String deckId) async {
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('decks')
          .doc(deckId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  /// ana veritabanından public kelimeler al (favoriler için fallback)
  Future<List<Word>> getPublicWords({int limit = 10}) async {
    try {

      final randomWords = getRandomWordsFromDatabase(limit);

      return randomWords;
    } catch (e) {
      return [];
    }
  }

  // ============================================================================
  // UNIFIED QUIZ DATA ACCESS METHODS
  // ============================================================================

  /// Get all words from local 1kwords.json for general quiz
  Future<List<Word>> getAllWordsFromLocal() async {
    try {
      // _allWords zaten 1kwords.json'dan yüklendi
      return List<Word>.from(_allWords);
    } catch (e) {
      return [];
    }
  }

  /// Get category-specific words using WordLoader
  Future<List<Word>> getCategoryWords(String categoryKey) async {
    try {
      final categoryWords = await WordLoader.loadCategoryWords(categoryKey);
        '📚 Loaded ${categoryWords.length} words for category: $categoryKey',
      );
      return categoryWords;
    } catch (e) {
      return [];
    }
  }
}
