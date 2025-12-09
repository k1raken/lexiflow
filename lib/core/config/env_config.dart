class EnvConfig {
  EnvConfig._();

  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const String admobAndroidRewardedTestId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_TEST_ID',
    defaultValue: '',
  );

  static const String admobAndroidRewardedProdId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_PROD_ID',
    defaultValue: '',
  );

  static const String admobTestDeviceIds = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_IDS',
    defaultValue: '',
  );

  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
}
