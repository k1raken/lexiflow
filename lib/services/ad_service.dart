import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/config/env_config.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/lexiflow_toast.dart';
import '../di/locator.dart';
import 'user_service.dart';
import 'analytics_service.dart';
import 'premium_service.dart';
import 'ad_cooldown_manager.dart';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool get isRewardedReady => _isAdLoaded && _rewardedAd != null;
  int _loadRetryAttempt = 0;

  // Google Test ID as final fallback
  static const String _googleRewardedTestId = 'ca-app-pub-3940256099942544/5224354917';

  static const String _adsBoxName = 'ads_state';
  static const String _lastRewardedKey = 'last_rewarded_at';
  static const String _quizCountKey = 'quiz_count_since_last_rewarded';
  static const Duration _cooldown = Duration(minutes: 20);

  // Initialize Mobile Ads SDK
  static Future<void> initialize() async {
    // Skip on web builds
    if (kIsWeb) return;

    // Apply safe request configuration before init
    try {
      List<String> testDeviceIds = [];
      final envIds = EnvConfig.admobTestDeviceIds;
      if (envIds.isNotEmpty) {
        testDeviceIds = envIds.split(',').map((e) => e.trim()).toList();
      }

      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: MaxAdContentRating.pg,
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
          testDeviceIds: testDeviceIds,
        ),
      );
    } catch (_) {}

    // Initialize MobileAds; App ID is read from AndroidManifest via placeholders
    await MobileAds.instance.initialize();
    // Preload one rewarded ad in the background for smoother playback
    try {
      await locator<AdService>().loadRewardedAd();
    } catch (_) {}
  }

  Future<Box<dynamic>> _ensureAdsBox() async {
    if (Hive.isBoxOpen(_adsBoxName)) {
      return Hive.box<dynamic>(_adsBoxName);
    }
    return Hive.openBox<dynamic>(_adsBoxName);
  }

  Future<DateTime?> getLastRewardedAt() async {
    final box = await _ensureAdsBox();
    final value = box.get(_lastRewardedKey);
    if (value is DateTime) return value;
    return null;
  }

  Future<void> _markRewardedWatched() async {
    final box = await _ensureAdsBox();
    await box.put(_lastRewardedKey, DateTime.now());
    await box.put(_quizCountKey, 0); // reset quiz counter on ad show
  }

  Future<bool> isCooldownActive({Duration? override}) async {
    final last = await getLastRewardedAt();
    if (last == null) return false;
    final diff = DateTime.now().difference(last);
    final usedCooldown = override ?? _cooldown;
    return diff < usedCooldown;
  }

  Future<int> getQuizCountSinceLastAd() async {
    final box = await _ensureAdsBox();
    final value = box.get(_quizCountKey);
    if (value is int) return value;
    return 0;
  }

  Future<String?> _resolveRewardedAdUnitId() async {
    try {
      // 1. Force Test Ads in Debug Mode
      if (kDebugMode) {

        try {
          final testId = EnvConfig.admobAndroidRewardedTestId;
          if (testId.isNotEmpty) {

            return testId;
          }
        } catch (e) {

        }

        return _googleRewardedTestId;
      }

      // 2. Check Remote Config (Release Mode - Dynamic Override)
      try {
        final config = FirebaseRemoteConfig.instance;
        // Check if Remote Config is initialized
        await config.ensureInitialized();
        final remoteValue = config.getString('admob_rewarded_unit_id').trim();
        if (remoteValue.isNotEmpty) {

          return remoteValue;
        }
      } catch (e) {

        // Continue to fallback options
      }
      
      // 3. Check EnvConfig Production ID
      try {
        final prodId = EnvConfig.admobAndroidRewardedProdId;
        if (prodId.isNotEmpty) {

          return prodId;
        }
      } catch (e) {

      }

      // 4. Fallback to EnvConfig Test ID
      try {
        final testId = EnvConfig.admobAndroidRewardedTestId;
        if (testId.isNotEmpty) {

          return testId;
        }
      } catch (e) {

      }

      // 5. Final Fallback: Google Test ID

      return _googleRewardedTestId;
    } catch (e, stackTrace) {

      // Return Google test ID as absolute fallback
      return _googleRewardedTestId;
    }
  }

  Future<void> incrementQuizCount() async {
    final box = await _ensureAdsBox();
    final current = await getQuizCountSinceLastAd();
    await box.put(_quizCountKey, current + 1);
  }

  Future<void> resetQuizCount() async {
    final box = await _ensureAdsBox();
    await box.put(_quizCountKey, 0);
  }

  /// Decide if we are allowed to show a rewarded ad right now based on
  /// cooldown (20 minutes) OR number of quizzes since last ad (>= 3).
  Future<bool> canShowAd({Duration? override}) async {
    final cooldownActive = await isCooldownActive(override: override);
    final quizCount = await getQuizCountSinceLastAd();
    if (!cooldownActive) {
      // Cooldown expired → allowed to show an ad regardless of quiz count
      return true;
    }
    // Cooldown active → only allow if user has started >=3 quizzes since last ad
    return quizCount >= 3;
  }

  // Load rewarded ad
  Future<void> loadRewardedAd() async {
    try {
      final adUnitId = await _resolveRewardedAdUnitId();
      if (adUnitId == null || adUnitId.isEmpty) {

        _isAdLoaded = false;
        return;
      }

      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isAdLoaded = true;
            _loadRetryAttempt = 0;

          },
          onAdFailedToLoad: (error) {

            _isAdLoaded = false;
            // Exponential backoff retry to keep an ad ready
            _loadRetryAttempt = (_loadRetryAttempt + 1).clamp(1, 10);
            final delaySeconds = _computeBackoffSeconds(_loadRetryAttempt);
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (!_isAdLoaded) {
                loadRewardedAd();
              }
            });
          },
        ),
      );
    } catch (e, stackTrace) {

      _isAdLoaded = false;
      // Don't retry on exception, just mark as failed
    }
  }

  int _computeBackoffSeconds(int attempt) {
    // 1->5s, 2->10s, 3->20s, 4->40s, >=5->60s cap
    if (attempt <= 1) return 5;
    if (attempt == 2) return 10;
    return math.min(60, 5 * (1 << (attempt - 2)));
  }

  // Convenience alias reflecting the requested API naming
  Future<void> preloadRewarded() async {
    try {

      await loadRewardedAd();

    } catch (e, stackTrace) {

      rethrow; // Re-throw so caller can handle it
    }
  }

  // Show rewarded ad; returns true if user earned reward
  Future<bool> showRewardedAd() async {
    if (!_isAdLoaded || _rewardedAd == null) {

      // Kick off a preload so the next attempt is ready
      Future.microtask(() => loadRewardedAd());
      return false;
    }

    final completer = Completer<bool>();
    bool rewardEarned = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {

        ad.dispose();
        _isAdLoaded = false;
        
        // Complete with the reward status
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
        
        // Preload next ad after a short delay to avoid rapid chaining
        Future.delayed(const Duration(seconds: 5), () {
          if (!_isAdLoaded) {
            loadRewardedAd();
          }
        });
      },
      onAdFailedToShowFullScreenContent: (ad, error) {

        ad.dispose();
        _isAdLoaded = false;
        
        // Complete with false on error
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        
        Future.delayed(const Duration(seconds: 5), () {
          if (!_isAdLoaded) {
            loadRewardedAd();
          }
        });
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;

      },
    );

    // Wait for the ad to be dismissed
    return completer.future;
  }

  /// Enforce rewarded ad gate with 20-minute cooldown.
  /// Returns true when quiz should proceed.
  Future<bool> enforceRewardedGateIfNeeded({
    required BuildContext context,
    bool grantXpOnReward = false,
    int? chillMs,
  }) async {
    try {
      // Premium-aware gate: if premium, skip all ads entirely
      final premiumService = locator<PremiumService>();
      final isPremium = await premiumService.isPremium();
      if (isPremium) {

        // Track start count for analytics but never show ads
        try {
          final prefs = await SharedPreferences.getInstance();
          final count = (prefs.getInt('quizStartCount') ?? 0) + 1;
          await prefs.setInt('quizStartCount', count);
        } catch (_) {}
        return true;
      }

      // Increment per-session quiz start count
      final prefs = await SharedPreferences.getInstance();
      final quizStartCount = (prefs.getInt('quizStartCount') ?? 0) + 1;
      await prefs.setInt('quizStartCount', quizStartCount);

      // First quiz → no ads
      if (quizStartCount == 1) {

        try {
          await AnalyticsService.logEvent(name: 'quiz_start_no_ad_first', parameters: {'count': quizStartCount});
        } catch (_) {}
        return true;
      }

      // From second quiz onward, show one rewarded ad if cooldown allows; otherwise skip
      final override = chillMs != null ? Duration(milliseconds: chillMs) : null;
      final cooldownActive = await isCooldownActive(override: override);
      if (cooldownActive) {

        try {
          await AnalyticsService.logEvent(name: 'quiz_start_skip_cooldown', parameters: {'count': quizStartCount});
        } catch (_) {}
        return true;
      }

      // Ensure ad is ready
      if (!_isAdLoaded || _rewardedAd == null) {
        await loadRewardedAd();
      }

      final rewarded = await showRewardedAd();
      if (rewarded) {
        // Mark cooldown and reset old Hive counter for compatibility
        AdCooldownManager.markShown();
        await _markRewardedWatched();

        try {
          await AnalyticsService.logEvent(name: 'quiz_start_rewarded_shown', parameters: {'count': quizStartCount});
        } catch (_) {}
        if (context.mounted) {
          showLexiflowToast(context, ToastType.success, 'Quiz açıldı, iyi şanslar! 🎯');
        }
        if (grantXpOnReward) {
          try {
            final userService = locator<UserService>();
            userService.addXp(10);
          } catch (e) {

          }
        }
      } else {

        try {
          await AnalyticsService.logEvent(name: 'quiz_start_rewarded_unavailable', parameters: {'count': quizStartCount});
        } catch (_) {}
      }

      return true;
    } catch (e) {

      try {
        await AnalyticsService.logEvent(name: 'quiz_start_gate_error', parameters: {'error': e.toString()});
      } catch (_) {}
      return true;
    }
  }

  // Dispose
  void dispose() {
    _rewardedAd?.dispose();
  }
}
