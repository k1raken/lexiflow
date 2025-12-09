import 'package:flutter/material.dart';
import '../services/streak_service.dart';
import '../services/session_service.dart';
import '../providers/profile_stats_provider.dart';
import '../utils/logger.dart';

/// Service to handle app lifecycle events
class AppLifecycleService with WidgetsBindingObserver {
  final SessionService _sessionService;
  final ProfileStatsProvider _profileStatsProvider;
  
  bool _isInitialized = false;
  DateTime? _lastCheckedDate;

  AppLifecycleService({
    required SessionService sessionService,
    required ProfileStatsProvider profileStatsProvider,
  })  : _sessionService = sessionService,
        _profileStatsProvider = profileStatsProvider;

  void initialize() {
    if (_isInitialized) return;
    
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    
    // Check streak on first init
    _checkAndIncrementStreak();
    
    Logger.i('[AppLifecycle] Service initialized', 'AppLifecycleService');
  }

  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logger.i('[AppLifecycle] State changed: $state', 'AppLifecycleService');
    
    if (state == AppLifecycleState.resumed) {
      // User returned to app
      _checkAndIncrementStreak();
    }
  }

  Future<void> _checkAndIncrementStreak() async {
    try {
      final userId = _sessionService.currentUser?.uid;
      if (userId == null) {
        Logger.i('[AppLifecycle] No user, skipping streak check', 'AppLifecycleService');
        return;
      }

      // Check if we already checked today
      final now = DateTime.now();
      if (_lastCheckedDate != null &&
          _lastCheckedDate!.year == now.year &&
          _lastCheckedDate!.month == now.month &&
          _lastCheckedDate!.day == now.day) {
        Logger.i('[AppLifecycle] Already checked streak today', 'AppLifecycleService');
        return;
      }

      Logger.i('[AppLifecycle] Checking streak for user $userId', 'AppLifecycleService');

      // Check if streak needs reset
      await StreakService.checkAndResetStreakIfNeeded(userId);

      // Try to increment streak
      final wasIncremented = await StreakService.incrementIfNewDay(userId);

      if (wasIncremented) {
        Logger.i('[AppLifecycle] ✅ Streak incremented!', 'AppLifecycleService');
        
        // Refresh profile stats to show new streak
        await _profileStatsProvider.refresh();
      } else {
        Logger.i('[AppLifecycle] Streak already updated today', 'AppLifecycleService');
      }

      _lastCheckedDate = now;
    } catch (e) {
      Logger.e('[AppLifecycle] Error checking streak', e, null, 'AppLifecycleService');
    }
  }

  /// Manually trigger streak check (for testing)
  Future<void> forceCheckStreak() async {
    _lastCheckedDate = null;
    await _checkAndIncrementStreak();
  }
}
