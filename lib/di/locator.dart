// lib/di/locator.dart

import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import 'package:lexiflow/services/category_progress_service.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/session_service.dart';
import '../services/ad_service.dart';
import '../services/premium_service.dart';
import '../services/network_monitor_service.dart';
import '../services/migration_integration_service.dart';
import '../services/notification_service.dart';
import '../services/learned_words_service.dart';
import '../services/analytics_service.dart';
import '../services/sync_manager.dart';
import '../services/connectivity_service.dart';
import '../services/enhanced_session_service.dart';
import '../services/offline_storage_manager.dart';
import '../services/offline_auth_service.dart';
import '../services/remote_config_service.dart';
import '../services/statistics_service.dart';
import '../services/daily_word_service.dart';
import '../services/progress_service.dart';
import '../services/activity_service.dart';
import '../services/srs_service.dart';
import '../repositories/auth_repository.dart';

import '../providers/theme_provider.dart';

final GetIt locator = GetIt.instance;

/// Initialize all services in the dependency injection container
Future<void> setupLocator() async {

  // Core services - initialized first (idempotent registration)
  if (!locator.isRegistered<ThemeProvider>()) {
    locator.registerLazySingleton<ThemeProvider>(() => ThemeProvider());

  }

  if (!locator.isRegistered<IAuthRepository>()) {
    locator.registerLazySingleton<IAuthRepository>(() => AuthRepository());

  }

  if (!locator.isRegistered<UserService>()) {
    locator.registerLazySingleton<UserService>(() => UserService());

  }

  if (!locator.isRegistered<SessionService>()) {
    locator.registerLazySingleton<SessionService>(() => SessionService());

  }

  if (!locator.isRegistered<WordService>()) {
    locator.registerLazySingleton<WordService>(() => WordService());

  }

  // Network and connectivity services
  if (!locator.isRegistered<ConnectivityService>()) {
    locator.registerLazySingleton<ConnectivityService>(
      () => ConnectivityService(),
    );

  }
  if (!locator.isRegistered<SyncManager>()) {
    locator.registerLazySingleton<SyncManager>(() => SyncManager());

  }
  if (!locator.isRegistered<NetworkMonitorService>()) {
    locator.registerLazySingleton<NetworkMonitorService>(
      () => NetworkMonitorService(),
    );

  }

  // Storage services
  if (!locator.isRegistered<OfflineStorageManager>()) {
    locator.registerLazySingleton<OfflineStorageManager>(
      () => OfflineStorageManager(),
    );

  }
  if (!locator.isRegistered<OfflineAuthService>()) {
    locator.registerLazySingleton<OfflineAuthService>(() => OfflineAuthService());

  }

  // Enhanced services
  if (!locator.isRegistered<EnhancedSessionService>()) {
    locator.registerLazySingleton<EnhancedSessionService>(
      () => EnhancedSessionService(),
    );

  }

  // Business logic services
  if (!locator.isRegistered<LearnedWordsService>()) {
    locator.registerLazySingleton<LearnedWordsService>(
      () => LearnedWordsService(),
    );

  }
  if (!locator.isRegistered<CategoryProgressService>()) {
    locator.registerLazySingleton<CategoryProgressService>(
      () => CategoryProgressService(),
    );

  }

  if (!locator.isRegistered<AnalyticsService>()) {
    locator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());

  }
  if (!locator.isRegistered<StatisticsService>()) {
    locator.registerLazySingleton<StatisticsService>(() => StatisticsService());

  }
  if (!locator.isRegistered<DailyWordService>()) {
    locator.registerLazySingleton<DailyWordService>(() => DailyWordService());

  }
  if (!locator.isRegistered<ProgressService>()) {
    locator.registerLazySingleton<ProgressService>(() => ProgressService());

  }
  if (!locator.isRegistered<ActivityService>()) {
    locator.registerLazySingleton<ActivityService>(() => ActivityService());

  }
  if (!locator.isRegistered<SRSService>()) {
    locator.registerLazySingleton<SRSService>(() => SRSService());

  }

  // UI services
  if (!locator.isRegistered<PremiumService>()) {
    locator.registerLazySingleton<PremiumService>(() => PremiumService());

  }
  if (!locator.isRegistered<AdService>()) {
    locator.registerLazySingleton<AdService>(() => AdService());

  }
  if (!locator.isRegistered<NotificationService>()) {
    locator.registerLazySingleton<NotificationService>(
      () => NotificationService(),
    );

  }

  // Configuration services
  if (!locator.isRegistered<RemoteConfigService>()) {
    locator.registerLazySingleton<RemoteConfigService>(
      () => RemoteConfigService(),
    );

  }

  // Migration service
  if (!locator.isRegistered<MigrationIntegrationService>()) {
    locator.registerLazySingleton<MigrationIntegrationService>(
      () => MigrationIntegrationService(),
    );

  }

  // Firebase bağımlı servislerin initialization'ı kaldırıldı
  // Bu servisler ilk kullanımda otomatik olarak initialize edilecek

}

/// Reset all services (useful for testing)
void resetLocator() {
  locator.reset();
}
