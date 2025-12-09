import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/sync_operation.dart';

/// Service to manage pending sync operations for offline-first architecture
/// Queues operations when offline and processes them when connectivity is restored
class SyncQueueService {
  SyncQueueService._();
  static final SyncQueueService _instance = SyncQueueService._();
  factory SyncQueueService() => _instance;

  static const String _boxName = 'sync_queue';
  Box<SyncOperation>? _box;

  /// Initialize the sync queue
  Future<void> init() async {
    // If already initialized, skip
    if (_box != null && _box!.isOpen) {
      return;
    }
    
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<SyncOperation>(_boxName);
        if (kDebugMode) {
        }
      } else {
        _box = Hive.box<SyncOperation>(_boxName);
        if (kDebugMode) {
        }
      }
    } catch (e) {
      if (kDebugMode) {
      }
      // Try to recover by deleting corrupted box
      try {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox<SyncOperation>(_boxName);
        if (kDebugMode) {
        }
      } catch (recoveryError) {
        if (kDebugMode) {
        }
        rethrow;
      }
    }
  }

  /// Add a new operation to the queue
  Future<void> addOperation({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    await init();
    
    final id = SyncOperation.generateId(type, data);
    
    // Check if operation already exists (deduplication)
    final existing = _box!.values.firstWhere(
      (op) => op.id == id,
      orElse: () => SyncOperation(
        id: '',
        type: '',
        data: {},
        createdAt: DateTime.now(),
      ),
    );
    
    if (existing.id.isNotEmpty) {
      if (kDebugMode) {
      }
      return;
    }
    
    final operation = SyncOperation(
      id: id,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );
    
    await _box!.add(operation);
    
    if (kDebugMode) {
    }
  }

  /// Get all pending operations
  List<SyncOperation> getPendingOperations() {
    if (_box == null || !_box!.isOpen) return [];
    return _box!.values.toList();
  }

  /// Remove an operation from the queue
  Future<void> removeOperation(SyncOperation operation) async {
    if (_box == null || !_box!.isOpen) return;
    
    try {
      await operation.delete();
      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  /// Update operation retry count
  Future<void> updateRetryCount(SyncOperation operation, [String? error]) async {
    if (_box == null || !_box!.isOpen) return;
    
    try {
      operation.incrementRetry(error);
      await operation.save();
      
      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  /// Clear all operations (for testing or reset)
  Future<void> clearAll() async {
    if (_box == null || !_box!.isOpen) return;
    
    await _box!.clear();
    if (kDebugMode) {
    }
  }

  /// Remove stale operations (older than 7 days)
  Future<int> removeStaleOperations() async {
    if (_box == null || !_box!.isOpen) return 0;
    
    final staleOps = _box!.values.where((op) => op.isStale).toList();
    
    for (final op in staleOps) {
      await op.delete();
    }
    
    if (kDebugMode && staleOps.isNotEmpty) {
    }
    
    return staleOps.length;
  }

  /// Get queue statistics
  Map<String, dynamic> getStats() {
    if (_box == null || !_box!.isOpen) {
      return {'total': 0, 'byType': {}};
    }
    
    final operations = _box!.values.toList();
    final byType = <String, int>{};
    
    for (final op in operations) {
      byType[op.type] = (byType[op.type] ?? 0) + 1;
    }
    
    return {
      'total': operations.length,
      'byType': byType,
      'oldestAge': operations.isEmpty
          ? 0
          : DateTime.now()
              .difference(
                operations
                    .map((op) => op.createdAt)
                    .reduce((a, b) => a.isBefore(b) ? a : b),
              )
              .inMinutes,
    };
  }

  /// Check if queue has pending operations
  bool get hasPendingOperations {
    if (_box == null || !_box!.isOpen) return false;
    return _box!.isNotEmpty;
  }

  /// Get count of pending operations
  int get pendingCount {
    if (_box == null || !_box!.isOpen) return 0;
    return _box!.length;
  }
}
