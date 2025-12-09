// lib/services/migration_integration_service.dart
// Integration Service to connect migration with existing app flow

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'migration_service.dart';
import 'firestore_word_service.dart';
import 'progress_service.dart';
import 'activity_service.dart';

/// Migration Integration Service
/// Handles the integration between migration and existing app services
class MigrationIntegrationService {
  static final MigrationService _migrationService = MigrationService();
  static final FirestoreWordService _firestoreWordService =
      FirestoreWordService();
  static final ProgressService _progressService = ProgressService();
  static final ActivityService _activityService = ActivityService();

  /// Check if migration is needed and start it if necessary
  Future<bool> checkAndStartMigrationIfNeeded() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {

        }
        return false;
      }

      final isNeeded = await _migrationService.isMigrationNeeded(user.uid);

      if (isNeeded) {
        if (kDebugMode) {

        }
        return true; // Migration screen should be shown
      } else {
        if (kDebugMode) {

        }
        return false; // Continue to normal app flow
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return false; // Continue to normal app flow on error
    }
  }

  /// Get migration status for current user
  Future<Map<String, dynamic>?> getMigrationStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      return await _migrationService.getMigrationStatus(user.uid);
    } catch (e) {
      if (kDebugMode) {

      }
      return null;
    }
  }

  /// Start migration process
  Future<bool> startMigration() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {

        }
        return false;
      }

      return await _migrationService.migrateHiveToFirestore(user.uid);
    } catch (e) {
      if (kDebugMode) {

      }
      return false;
    }
  }

  /// Retry failed migration
  Future<bool> retryMigration() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {

        }
        return false;
      }

      return await _migrationService.retryMigration(user.uid);
    } catch (e) {
      if (kDebugMode) {

      }
      return false;
    }
  }

  /// Get the appropriate word service based on migration status
  Future<dynamic> getWordService() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {

        }
        return null;
      }

      final migrationStatus = await _migrationService.getMigrationStatus(
        user.uid,
      );

      if (migrationStatus != null && migrationStatus['isCompleted'] == true) {
        if (kDebugMode) {

        }
        return _firestoreWordService;
      } else {
        if (kDebugMode) {

        }
        // Return fallback service or handle appropriately
        return _firestoreWordService; // Use Firestore service as fallback
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return _firestoreWordService; // Use Firestore service as fallback
    }
  }

  /// Get the appropriate progress service based on migration status
  Future<dynamic> getProgressService() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {

        }
        return null;
      }

      final migrationStatus = await _migrationService.getMigrationStatus(
        user.uid,
      );

      if (migrationStatus != null && migrationStatus['isCompleted'] == true) {
        if (kDebugMode) {

        }
        return _progressService;
      } else {
        if (kDebugMode) {

        }
        return _progressService; // Use Firestore service as fallback
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return _progressService; // Use Firestore service as fallback
    }
  }

  /// Get the appropriate activity service based on migration status
  Future<dynamic> getActivityService() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {

        }
        return null;
      }

      final migrationStatus = await _migrationService.getMigrationStatus(
        user.uid,
      );

      if (migrationStatus != null && migrationStatus['isCompleted'] == true) {
        if (kDebugMode) {

        }
        return _activityService;
      } else {
        if (kDebugMode) {

        }
        return _activityService; // Use Firestore service as fallback
      }
    } catch (e) {
      if (kDebugMode) {

      }
      return _activityService; // Use Firestore service as fallback
    }
  }

  /// Check if user should see migration screen
  Future<bool> shouldShowMigrationScreen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {

        }
        return false;
      }

      if (kDebugMode) {

      }

      final migrationStatus = await _migrationService.getMigrationStatus(
        user.uid,
      );

      // Eğer migration status alınamazsa (null), ana ekrana geç
      if (migrationStatus == null) {
        if (kDebugMode) {

        }
        return false;
      }

      // Migration tamamlanmışsa ana ekrana geç
      final isCompleted = migrationStatus['isCompleted'] as bool? ?? false;
      if (isCompleted) {
        if (kDebugMode) {

        }
        return false;
      }

      // Migration tamamlanmamışsa migration screen göster
      if (kDebugMode) {

      }
      return true;

    } catch (e) {
      if (kDebugMode) {

        // Firestore permission-denied veya diğer hatalar durumunda
        if (e.toString().contains('permission-denied') || 
            e.toString().contains('PERMISSION_DENIED')) {

        } else {

        }
      }
      // Hata durumunda kesinlikle migration screen'i atla ve ana ekrana geç
      return false;
    }
  }

  /// Get migration progress callback
  Function(MigrationProgress)? getMigrationProgressCallback() {
    return _migrationService.onProgress;
  }

  /// Set migration progress callback
  void setMigrationProgressCallback(Function(MigrationProgress)? callback) {
    _migrationService.onProgress = callback;
  }

  /// Clear migration progress callback
  void clearMigrationProgressCallback() {
    _migrationService.onProgress = null;
  }

  /// Get migration service instance
  MigrationService get migrationService => _migrationService;

  /// Get firestore word service instance
  FirestoreWordService get firestoreWordService => _firestoreWordService;

  /// Get progress service instance
  ProgressService get progressService => _progressService;

  /// Get activity service instance
  ActivityService get activityService => _activityService;
}
