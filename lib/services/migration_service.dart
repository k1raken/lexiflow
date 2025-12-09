// lib/services/migration_service.dart
// Hive'dan Firestore'a Tam Migration Servisi

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'firestore_schema.dart';
import '../models/word_model.dart';

/// Migration ilerleme veri sınıfı
class MigrationProgress {
  final int totalWords;
  final int migratedWords;
  final int totalProgress;
  final int migratedProgress;
  final int totalActivities;
  final int migratedActivities;
  final String currentStep;
  final double percentage;
  final String? error;

  const MigrationProgress({
    required this.totalWords,
    required this.migratedWords,
    required this.totalProgress,
    required this.migratedProgress,
    required this.totalActivities,
    required this.migratedActivities,
    required this.currentStep,
    required this.percentage,
    this.error,
  });
}

/// Hive'dan Firestore'a migration için Migration Servisi
/// İlerleme takibi ve hata yönetimi ile tam veri migration'ını yönetir
class MigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Migration ilerleme takibi
  int _totalWords = 0;
  int _migratedWords = 0;
  int _totalProgress = 0;
  int _migratedProgress = 0;
  int _totalActivities = 0;
  int _migratedActivities = 0;

  // İlerleme callback'i
  Function(MigrationProgress)? onProgress;

  Future<bool> isMigrationNeeded(String userId) async {
    try {

      final migrationPath = FirestoreSchema.getMigrationStatusPath(userId);

      final migrationDoc = await _firestore.doc(migrationPath).get();

      if (!migrationDoc.exists) {

        return true;
      }

      final data = migrationDoc.data() as Map<String, dynamic>;
      final isCompleted = data['isCompleted'] as bool? ?? false;

      return !isCompleted;
    } catch (e, stackTrace) {

      return true; // hata durumunda migration gerekli varsay
    }
  }

  Future<bool> migrateHiveToFirestore(String userId) async {
    try {

      await _initializeMigrationStatus(userId);

      // Step 1: Migrate public words
      await _migratePublicWords();

      // Step 2: Migrate user progress
      await _migrateUserProgress(userId);

      // Step 3: Migrate user activities
      await _migrateUserActivities(userId);

      // Step 4: Update user stats
      await _updateUserStats(userId);

      // Step 5: Complete migration
      await _completeMigration(userId);

      return true;
    } catch (e) {

      await _recordMigrationError(userId, e.toString());
      return false;
    }
  }

  Future<void> _initializeMigrationStatus(String userId) async {
    try {

      final migrationPath = FirestoreSchema.getMigrationStatusPath(userId);

      final migrationData = FirestoreSchema.createMigrationStatus(
        isCompleted: false,
        version: FirestoreSchema.currentMigrationVersion,
      );

      await _firestore.doc(migrationPath).set(migrationData);

      _updateProgress('Initializing migration...', 0.0);
    } catch (e, stackTrace) {

      rethrow;
    }
  }

  Future<void> _migratePublicWords() async {
    try {
      _updateProgress('Migrating words...', 0.1);

      final wordsBox = await Hive.openBox<Word>('words');
      final words = wordsBox.values.toList();
      wordsBox.close();

      _totalWords = words.length;
      _migratedWords = 0;

      // batch'ler halinde migrate et
      for (
        int i = 0;
        i < words.length;
        i += FirestoreSchema.migrationBatchSize
      ) {
        final batch = _firestore.batch();
        final endIndex = (i + FirestoreSchema.migrationBatchSize).clamp(
          0,
          words.length,
        );

        for (int j = i; j < endIndex; j++) {
          final word = words[j];
          final wordId = _generateWordId(word.word);

          try {
            final wordPath = FirestoreSchema.getPublicWordPath(wordId);

            final wordData = FirestoreSchema.createPublicWord(
              wordId: wordId,
              word: word.word,
              meaning: word.meaning,
              tr: word.tr,
              exampleSentence: word.exampleSentence,
              tags: word.tags,
              isCustom: word.isCustom,
              createdBy: word.isCustom ? 'system' : null,
            );

            batch.set(_firestore.doc(wordPath), wordData);

            _migratedWords++;
          } catch (e) {
            if (kDebugMode) {

            }
            rethrow;
          }
        }

        await batch.commit();

        final progress = 0.1 + (0.3 * (_migratedWords / _totalWords));
        _updateProgress(
          'Migrating words... ($_migratedWords/$_totalWords)',
          progress,
        );

        // Firestore'u yormamak için küçük gecikme
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (kDebugMode) {

      }
    } catch (e) {
      if (kDebugMode) {

      }
      rethrow;
    }
  }

  Future<void> _migrateUserProgress(String userId) async {
    try {
      _updateProgress('Migrating progress...', 0.4);

      final progressBox = await Hive.openBox('user_progress');
      final progressData = progressBox.toMap();
      progressBox.close();

      _totalProgress = progressData.length;
      _migratedProgress = 0;

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final entry in progressData.entries) {
        final wordId = entry.key;
        final progress = entry.value as Map<String, dynamic>;

        try {
          final progressPath = FirestoreSchema.getUserWordProgressPath(
            userId,
            wordId,
          );

          final progressData = FirestoreSchema.createUserWordProgress(
            wordId: wordId,
            srsLevel: progress['srsLevel'] ?? 0,
            nextReview:
                progress['nextReview'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                      progress['nextReview'],
                    )
                    : null,
            correctAnswers: progress['correctAnswers'] ?? 0,
            wrongAnswers: progress['wrongAnswers'] ?? 0,
            lastReviewed:
                progress['lastReviewed'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                      progress['lastReviewed'],
                    )
                    : null,
            mastered: progress['mastered'] ?? false,
            streak: progress['streak'] ?? 0,
            confidence: (progress['confidence'] ?? 0.0).toDouble(),
          );

          batch.set(_firestore.doc(progressPath), progressData);

          _migratedProgress++;
          batchCount++;
        } catch (e) {
          if (kDebugMode) {

          }
          rethrow;
        }

        // batch boyutuna ulaştığında commit et
        if (batchCount >= FirestoreSchema.migrationBatchSize) {
          await batch.commit();
          batchCount = 0;

          final progress = 0.4 + (0.3 * (_migratedProgress / _totalProgress));
          _updateProgress(
            'Migrating progress... ($_migratedProgress/$_totalProgress)',
            progress,
          );

          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // kalan öğeleri commit et
      if (batchCount > 0) {
        await batch.commit();
      }

      if (kDebugMode) {

      }
    } catch (e) {
      if (kDebugMode) {

      }
      rethrow;
    }
  }

  Future<void> _migrateUserActivities(String userId) async {
    try {
      _updateProgress('Migrating activities...', 0.7);

      final activityBox = await Hive.openBox('user_activities');
      final activities = activityBox.values.toList();
      activityBox.close();

      _totalActivities = activities.length;
      _migratedActivities = 0;

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final activity in activities) {
        final activityData = activity as Map<String, dynamic>;
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

        try {
          final activityPath = FirestoreSchema.getUserActivityPath(
            userId,
            timestamp,
          );
          if (kDebugMode) {

          }

          final activityDoc = FirestoreSchema.createUserActivity(
            type: activityData['type'] ?? 'unknown',
            xpEarned: activityData['xpEarned'] ?? 0,
            learnedWordsCount: activityData['learnedWordsCount'] ?? activityData['wordsLearned'] ?? 0, // fallback for migration
            quizType: activityData['quizType'],
            correctAnswers: activityData['correctAnswers'] ?? 0,
            totalQuestions: activityData['totalQuestions'] ?? 0,
            wordId: activityData['wordId'],
            metadata: activityData['metadata'],
          );

          batch.set(_firestore.doc(activityPath), activityDoc);

          _migratedActivities++;
          batchCount++;
        } catch (e) {
          if (kDebugMode) {

          }
          rethrow;
        }

        if (batchCount >= FirestoreSchema.migrationBatchSize) {
          await batch.commit();
          batchCount = 0;

          final progress =
              0.7 + (0.2 * (_migratedActivities / _totalActivities));
          _updateProgress(
            'Migrating activities... ($_migratedActivities/$_totalActivities)',
            progress,
          );

          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      if (kDebugMode) {

      }
    } catch (e) {
      if (kDebugMode) {

      }
      rethrow;
    }
  }

  Future<void> _updateUserStats(String userId) async {
    try {
      _updateProgress('Updating stats...', 0.9);

      final statsDoc =
          await _firestore.doc(FirestoreSchema.getUserStatsPath(userId)).get();

      if (statsDoc.exists) {
        final currentStats = statsDoc.data() as Map<String, dynamic>;

        final updatedStats = FirestoreSchema.createUserStats(
          xp: currentStats['xp'] ?? 0,
          level: currentStats['level'] ?? 1,
          streak: currentStats['streak'] ?? 0,
          learnedWordsCount: _migratedProgress, // migrate edilen progress sayısını kullan
          totalWordsStudied: _migratedProgress,
          totalQuizzesCompleted: _migratedActivities,
          totalCorrectAnswers: 0, // progress'ten hesaplanacak
          totalWrongAnswers: 0, // progress'ten hesaplanacak
          accuracy: 0.0, // hesaplanacak
          lastActivityDate: DateTime.now(),
        );

        await _firestore
            .doc(FirestoreSchema.getUserStatsPath(userId))
            .update(updatedStats);
      }

    } catch (e) {

      rethrow;
    }
  }

  Future<void> _completeMigration(String userId) async {
    try {
      _updateProgress('Completing migration...', 0.95);

      final migrationData = FirestoreSchema.createMigrationStatus(
        isCompleted: true,
        version: FirestoreSchema.currentMigrationVersion,
        completedAt: DateTime.now(),
        totalWordsMigrated: _migratedWords,
        totalProgressMigrated: _migratedProgress,
        totalActivitiesMigrated: _migratedActivities,
      );

      await _firestore
          .doc(FirestoreSchema.getMigrationStatusPath(userId))
          .update(migrationData);

      _updateProgress('Migration completed!', 1.0);

      // başarılı migration sonrası Hive verilerini temizle
      await _cleanupHiveData();

    } catch (e) {

      rethrow;
    }
  }

  Future<void> _recordMigrationError(String userId, String error) async {
    try {
      final migrationData = FirestoreSchema.createMigrationStatus(
        isCompleted: false,
        version: FirestoreSchema.currentMigrationVersion,
        errors: {'error': error, 'timestamp': DateTime.now().toIso8601String()},
        totalWordsMigrated: _migratedWords,
        totalProgressMigrated: _migratedProgress,
        totalActivitiesMigrated: _migratedActivities,
      );

      await _firestore
          .doc(FirestoreSchema.getMigrationStatusPath(userId))
          .update(migrationData);
    } catch (e) {

    }
  }

  Future<void> _cleanupHiveData() async {
    try {

      final boxes = ['words', 'user_progress', 'user_activities'];

      for (final boxName in boxes) {
        try {
          // box açık mı kontrol et
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.close();

          }

          // diskten sil (box kapalı olsa da çalışır)
          await Hive.deleteBoxFromDisk(boxName);

        } catch (e) {

          // bir box silinmezse diğerleriyle devam et
        }
      }

    } catch (e) {

    }
  }

  String _generateWordId(String word) {
    return word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  void _updateProgress(String step, double percentage) {
    final progress = MigrationProgress(
      totalWords: _totalWords,
      migratedWords: _migratedWords,
      totalProgress: _totalProgress,
      migratedProgress: _migratedProgress,
      totalActivities: _totalActivities,
      migratedActivities: _migratedActivities,
      currentStep: step,
      percentage: percentage,
    );

    onProgress?.call(progress);
  }

  Future<bool> retryMigration(String userId) async {
    try {
      if (kDebugMode) {

      }

      // sayaçları sıfırla
      _migratedWords = 0;
      _migratedProgress = 0;
      _migratedActivities = 0;

      return await migrateHiveToFirestore(userId);
    } catch (e) {
      if (kDebugMode) {

      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMigrationStatus(String userId) async {
    try {
      final doc =
          await _firestore
              .doc(FirestoreSchema.getMigrationStatusPath(userId))
              .get();

      return doc.data();
    } catch (e) {
      if (kDebugMode) {

      }
      return null;
    }
  }
}
