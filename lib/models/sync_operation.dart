import 'package:hive/hive.dart';

part 'sync_operation.g.dart';

/// Represents a pending sync operation that needs to be sent to Firestore
/// Used for offline-first architecture to queue operations when offline
@HiveType(typeId: 11)
class SyncOperation extends HiveObject {
  /// Unique identifier for this operation
  @HiveField(0)
  String id;

  /// Type of operation: 'favorite_add', 'favorite_remove', 'custom_word_add', etc.
  @HiveField(1)
  String type;

  /// Operation-specific data (e.g., word, userId, etc.)
  @HiveField(2)
  Map<String, dynamic> data;

  /// When this operation was created
  @HiveField(3)
  DateTime createdAt;

  /// Number of times we've tried to sync this operation
  @HiveField(4)
  int retryCount;

  /// Last error message (for debugging)
  @HiveField(5)
  String? lastError;

  SyncOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  /// Create a unique ID for deduplication
  static String generateId(String type, Map<String, dynamic> data) {
    // For favorites: type + userId + word
    if (type.startsWith('favorite_')) {
      return '$type|${data['userId']}|${data['word']}';
    }
    // For custom words: type + userId + timestamp
    return '$type|${data['userId']}|${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Check if this operation is stale (older than 7 days)
  bool get isStale {
    final age = DateTime.now().difference(createdAt);
    return age.inDays > 7;
  }

  /// Increment retry count
  void incrementRetry([String? error]) {
    retryCount++;
    lastError = error;
  }

  @override
  String toString() {
    return 'SyncOperation(id: $id, type: $type, retryCount: $retryCount, age: ${DateTime.now().difference(createdAt).inMinutes}min)';
  }
}
