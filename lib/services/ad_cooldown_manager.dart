/// Simple in-memory cooldown manager for rewarded ads.
class AdCooldownManager {
  static const Duration cooldown = Duration(minutes: 20);
  static DateTime? _lastRewardedAt;

  static bool canShowRewarded() {
    if (_lastRewardedAt == null) return true;
    return DateTime.now().difference(_lastRewardedAt!) > cooldown;
  }

  static bool canShowRewardedWithOverride(Duration override) {
    if (_lastRewardedAt == null) return true;
    return DateTime.now().difference(_lastRewardedAt!) > override;
  }

  static void markShown() => _lastRewardedAt = DateTime.now();
}