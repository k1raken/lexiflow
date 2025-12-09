import 'dart:async';
import 'package:flutter/foundation.dart';

/// Helper class for retrying failed operations
class RetryHelper {
  /// Retry an operation with exponential backoff
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? retryIf,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      attempt++;
      try {

        return await operation();
      } catch (e) {
        // Check if we should retry
        final shouldRetry = retryIf?.call(e) ?? true;
        
        if (attempt >= maxAttempts || !shouldRetry) {

          rethrow;
        }

        await Future.delayed(delay);
        delay *= backoffMultiplier;
      }
    }
  }

  /// Retry with custom error handling
  static Future<T> retryWithFallback<T>(
    Future<T> Function() operation, {
    required T Function() fallback,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    try {
      return await retry(
        operation,
        maxAttempts: maxAttempts,
        initialDelay: initialDelay,
      );
    } catch (e) {

      return fallback();
    }
  }

  /// Check if error is retryable (network errors, timeouts, etc.)
  static bool isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('failed host lookup')) {
      return true;
    }
    
    // Firestore errors
    if (errorString.contains('unavailable') ||
        errorString.contains('deadline-exceeded') ||
        errorString.contains('resource-exhausted')) {
      return true;
    }
    
    return false;
  }
}

/// Extension for easy retry on Future
extension RetryExtension<T> on Future<T> Function() {
  Future<T> withRetry({
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) {
    return RetryHelper.retry(
      this,
      maxAttempts: maxAttempts,
      initialDelay: initialDelay,
      retryIf: RetryHelper.isRetryableError,
    );
  }
}
