import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for handling user feedback submissions with validation and rate limiting
class FeedbackService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const int maxMessageLength = 500;
  static const Duration rateLimitDuration = Duration(minutes: 5);
  static const String collectionName = 'feedbacks';

  FeedbackService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Submit feedback with validation and rate limiting
  /// 
  /// Returns a [FeedbackResult] indicating success or failure with error message
  Future<FeedbackResult> submitFeedback({
    required String message,
    String? uid,
    String? email,
  }) async {
    try {
      // Get current user if not provided
      final currentUser = _auth.currentUser;
      final userId = uid ?? currentUser?.uid;
      final userEmail = email ?? currentUser?.email ?? '';

      // Validate user is authenticated
      if (userId == null || userId.isEmpty) {
        return FeedbackResult.error(
          'Geri bildirim göndermek için giriş yapmalısınız.',
        );
      }

      // Validate input
      final validationResult = _validateMessage(message);
      if (!validationResult.isSuccess) {
        return validationResult;
      }

      final trimmedMessage = message.trim();

      // Check rate limiting
      final rateLimitResult = await _checkRateLimit(userId);
      if (!rateLimitResult.isSuccess) {
        return rateLimitResult;
      }

      // Get app version
      String appVersion = '';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (e) {

        appVersion = 'unknown';
      }

      // Submit feedback to Firestore
      await _firestore.collection(collectionName).add({
        'uid': userId,
        'email': userEmail,
        'message': trimmedMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'version': appVersion,
        'createdAt': DateTime.now().toIso8601String(),
      });

      return FeedbackResult.success();
    } catch (e, stackTrace) {

      return FeedbackResult.error(
        'Gönderim sırasında bir hata oluştu. Lütfen tekrar dene.',
      );
    }
  }

  /// Validate message meets requirements
  FeedbackResult _validateMessage(String message) {
    // Check if empty after trimming
    if (message.trim().isEmpty) {
      return FeedbackResult.error('Geri bildirim alanı boş bırakılamaz.');
    }

    // Check length
    if (message.length > maxMessageLength) {
      return FeedbackResult.error(
        'Geri bildirim en fazla $maxMessageLength karakter olabilir.',
      );
    }

    return FeedbackResult.success();
  }

  /// Check if user has submitted feedback recently (rate limiting)
  Future<FeedbackResult> _checkRateLimit(String uid) async {
    try {
      final now = DateTime.now();
      final cutoffTime = now.subtract(rateLimitDuration);

      // Query for the most recent feedback from this user
      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // No previous feedback, allow submission
        return FeedbackResult.success();
      }

      final lastFeedback = querySnapshot.docs.first;
      final lastTimestamp = lastFeedback.data()['timestamp'] as Timestamp?;

      if (lastTimestamp == null) {
        // No timestamp, allow submission
        return FeedbackResult.success();
      }

      final lastSubmissionTime = lastTimestamp.toDate();

      if (lastSubmissionTime.isAfter(cutoffTime)) {
        // Too soon, rate limit exceeded
        final remainingMinutes = rateLimitDuration.inMinutes -
            now.difference(lastSubmissionTime).inMinutes;
        
        return FeedbackResult.error(
          'Lütfen bir sonraki geri bildirim göndermeden önce birkaç dakika bekleyin. '
          '(Yaklaşık $remainingMinutes dakika)',
        );
      }

      // Enough time has passed, allow submission
      return FeedbackResult.success();
    } catch (e, stackTrace) {

      // On error, allow submission (fail open)
      return FeedbackResult.success();
    }
  }
}

/// Result of a feedback submission attempt
class FeedbackResult {
  final bool isSuccess;
  final String? errorMessage;

  FeedbackResult._({
    required this.isSuccess,
    this.errorMessage,
  });

  factory FeedbackResult.success() {
    return FeedbackResult._(isSuccess: true);
  }

  factory FeedbackResult.error(String message) {
    return FeedbackResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}
