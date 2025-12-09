class FeatureFlags {
  // Yeni Daily Coach deneyimini aç/kapat
  static const bool dailyCoachEnabled = true;

  // Gelecekteki FSRS motor dağıtımı için placeholder
  static const bool fsrsEnabled = true; // FSRS-Lite motorunu etkinleştir

  // Kullanıcıdan doğru cevapları derecelendirmesini iste (zor/iyi/kolay)
  static const bool fsrsQualityPromptEnabled = true;

  // Geçici reklam/AdMob kontrolü
  // Yayın öncesi temel UI/akış testleri için reklamları tamamen devre dışı bırakmak üzere false yapın
  static const bool adsEnabled = true;

  // Global log kontrolleri
  // Üretimde çoğu print/debugPrint gürültüsünü susturmak için false yap
  static const bool enableLogs = false;
  // true olduğunda, enableLogs true olsa bile verbose logları izin ver
  static const bool verboseLogs = false;

  // Transition policy toggles
  static const bool enableGlobalFadeThrough = true; // via theme
  static const bool useSharedAxisForDrillIn = true; // list → detail flows
  static const bool useSharedAxisVerticalForModals = true; // terms/privacy, results

  // Bottom nav animation controls
  static const bool enableTabCrossFade = true;
  static const int tabCrossFadeMs = 120; // 100–150ms
}
