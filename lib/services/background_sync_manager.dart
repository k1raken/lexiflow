import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sync_operation.dart';
import 'sync_queue_service.dart';
import 'connectivity_service.dart';

/// Orchestrates all background sync operations
/// Runs silently without blocking UI or showing errors to users
class BackgroundSyncManager {
  BackgroundSyncManager._();
  static final BackgroundSyncManager _instance = BackgroundSyncManager._();
  factory BackgroundSyncManager() => _instance;

  final SyncQueueService _queueService = SyncQueueService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Initialize the background sync manager
  Future<void> init() async {
    await _queueService.init();
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivityService.onlineStatusStream.listen(
      (isOnline) {
        if (isOnline) {
          _onConnectivityRestored();
        }
      },
    );
    
    if (kDebugMode) {
    }
  }

  /// Sync on app start (silent, no UI blocking)
  Future<void> syncOnAppStart() async {
    if (kDebugMode) {
    }
    
    // Run in background, don't await
    unawaited(_performSync());
  }

  /// Sync when connectivity is restored
  void _onConnectivityRestored() {
    if (kDebugMode) {
    }
    
    unawaited(_performSync());
  }

  /// Perform the actual sync operation
  Future<void> _performSync() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      if (kDebugMode) {
      }
      return;
    }

    // Check connectivity
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) {
      if (kDebugMode) {
      }
      return;
    }

    _isSyncing = true;

    try {
      // Step 1: Process sync queue
      await _processSyncQueue();

      // Step 2: Remove stale operations
      await _queueService.removeStaleOperations();

      if (kDebugMode) {
        final stats = _queueService.getStats();
      }
    } catch (e) {
      // Silent error - just log, don't show to user
      if (kDebugMode) {
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Process all pending operations in the queue
  Future<void> _processSyncQueue() async {
    final operations = _queueService.getPendingOperations();
    
    if (operations.isEmpty) {
      if (kDebugMode) {
      }
      return;
    }

    if (kDebugMode) {
    }

    for (final operation in operations) {
      try {
        await _processOperation(operation);
        await _queueService.removeOperation(operation);
      } catch (e) {
        // Update retry count but don't fail
        await _queueService.updateRetryCount(operation, e.toString());
        
        if (kDebugMode) {
        }
      }
    }
  }

  /// Process a single sync operation
  Future<void> _processOperation(SyncOperation operation) async {
    switch (operation.type) {
      case 'favorite_add':
        await _syncFavoriteAdd(operation.data);
        break;
      case 'favorite_remove':
        await _syncFavoriteRemove(operation.data);
        break;
      case 'custom_word_add':
        await _syncCustomWordAdd(operation.data);
        break;
      default:
        if (kDebugMode) {
        }
    }
  }

  /// Sync favorite add to Firestore
  Future<void> _syncFavoriteAdd(Map<String, dynamic> data) async {
    final userId = data['userId'] as String;
    final word = data['word'] as String;
    final meaning = data['meaning'] as String?;
    final tr = data['tr'] as String?;
    final example = data['example'] as String?;
    final isCustom = data['isCustom'] as bool? ?? false;

    final favRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(word);

    final statsRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((tx) async {
      final favSnap = await tx.get(favRef);
      
      // Only add if doesn't exist (avoid duplicates)
      if (!favSnap.exists) {
        tx.set(favRef, {
          'word': word,
          'meaning': meaning ?? '',
          'tr': tr ?? '',
          'example': example ?? '',
          'isCustom': isCustom,
          'addedAt': FieldValue.serverTimestamp(),
        });

        // Update count
        final statsSnap = await tx.get(statsRef);
        final currentCount = (statsSnap.data()?['favoritesCount'] ?? 0) as int;
        tx.set(statsRef, {
          'favoritesCount': currentCount + 1,
        }, SetOptions(merge: true));
      }
    });

    if (kDebugMode) {
    }
  }

  /// Sync favorite remove to Firestore
  Future<void> _syncFavoriteRemove(Map<String, dynamic> data) async {
    final userId = data['userId'] as String;
    final word = data['word'] as String;

    final favRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(word);

    final statsRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((tx) async {
      final favSnap = await tx.get(favRef);
      
      // Only remove if exists
      if (favSnap.exists) {
        tx.delete(favRef);

        // Update count
        final statsSnap = await tx.get(statsRef);
        final currentCount = (statsSnap.data()?['favoritesCount'] ?? 0) as int;
        tx.set(statsRef, {
          'favoritesCount': currentCount > 0 ? currentCount - 1 : 0,
        }, SetOptions(merge: true));
      }
    });

    if (kDebugMode) {
    }
  }

  /// Sync custom word add to Firestore
  Future<void> _syncCustomWordAdd(Map<String, dynamic> data) async {
    final userId = data['userId'] as String;
    final word = data['word'] as String;
    final meaning = data['meaning'] as String;
    final example = data['example'] as String;
    final deckId = data['deckId'] as String?;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('custom_words')
        .add({
      'word': word,
      'meaning': meaning,
      'example': example,
      'deckId': deckId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
    }
  }

  /// Manually trigger sync (for testing or user action)
  Future<void> triggerSync() async {
    await _performSync();
  }

  /// Get sync status
  bool get isSyncing => _isSyncing;

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
