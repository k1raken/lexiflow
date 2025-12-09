import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'session_service.dart';

/// Provides premium status with local caching and optional Firestore lookup.
class PremiumService {
  static const String _prefsKey = 'isPremium';

  /// Returns premium status, preferring local cache; attempts Firestore fetch when possible.
  Future<bool> isPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool(_prefsKey);
      if (cached != null) {
        return cached;
      }

      // Try fetching from Firestore if user is authenticated
      try {
        final session = SessionService();
        final user = session.currentUser;
        if (user != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data();
            final remoteValue = (data?['isPremium'] ?? data?['premium'] ?? false) == true;
            await prefs.setBool(_prefsKey, remoteValue);
            return remoteValue;
          }
        }
      } catch (e) {

      }

      // Default: not premium
      await prefs.setBool(_prefsKey, false);
      return false;
    } catch (e) {

      return false;
    }
  }

  /// Allows tests or app flows to set premium locally.
  Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}