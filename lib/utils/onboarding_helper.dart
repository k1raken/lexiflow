import 'package:shared_preferences/shared_preferences.dart';

class OnboardingHelper {
  /// Reset onboarding status for a specific user (for testing)
  static Future<void> resetOnboarding(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed_$userId');
    await prefs.remove('tutorial_completed_$userId');
  }

  /// Reset onboarding for all users (for testing)
  static Future<void> resetAllOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('onboarding_completed_') || 
          key.startsWith('tutorial_completed_')) {
        await prefs.remove(key);
      }
    }
  }

  /// Check if onboarding is completed for a user
  static Future<bool> isOnboardingCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed_$userId') ?? false;
  }

  /// Check if tutorial is completed for a user
  static Future<bool> isTutorialCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('tutorial_completed_$userId') ?? false;
  }
}
