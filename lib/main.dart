import 'dart:async';
import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'models/word_model.dart';
import 'models/user_data.dart';
import 'models/daily_log.dart';
import 'models/user_stats_model.dart';
import 'models/sync_operation.dart';
import 'services/cloud_sync_service.dart';
import 'services/word_service.dart';
import 'services/user_service.dart';
import 'services/session_service.dart';
import 'services/migration_integration_service.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/learned_words_service.dart';
import 'services/achievement_service.dart';
import 'services/sync_queue_service.dart';
import 'services/background_sync_manager.dart';
import 'providers/theme_provider.dart';
import 'providers/profile_stats_provider.dart';
import 'providers/cards_provider.dart';
import 'providers/sync_status_provider.dart';
import 'utils/hive_boxes.dart';
import 'themes/lexiflow_theme.dart';
import 'utils/design_system.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/mobile_only_guard.dart';
import 'widgets/immersive_wrapper.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/daily_challenge_screen.dart';
import 'screens/daily_word_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'screens/share_preview_screen.dart';
import 'screens/word_detail_screen.dart';
import 'screens/quiz_center_screen.dart';
import 'screens/category_quiz_play_screen.dart';
import 'screens/general_quiz_screen.dart';
import 'screens/quiz_start_screen.dart';
import 'screens/sign_in_screen.dart';
import 'utils/logger.dart';
import 'widgets/connection_status_widget.dart';
import 'widgets/sync_notification_widget.dart';
import 'di/locator.dart';
import 'debug/connectivity_debug.dart';
import 'utils/feature_flags.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {

    // Detect existing default app created by native provider and reuse it.
    // If none exists, initialize with explicit options.
    try {
      final existingApp = Firebase.app();
      // Existing Firebase app detected, using it
    } on FirebaseException catch (_) {
      try {
        await Firebase.initializeApp();

      } on FirebaseException catch (e) {
        // If native auto-init already created the default app, re-initialization throws.
        final msg = e.message ?? '';
        if (e.code == 'duplicate-app' || msg.contains('already exists')) {
          // Default app already exists; proceeding without re-init
        } else {
          rethrow;
        }
      }
    }

    // Register background message handler AFTER Firebase is initialized
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // System UI configuration - Fully immersive fullscreen
    // immersiveSticky: Hides both status and navigation bars, shows temporarily on swipe
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Empty list = hide all system overlays
    );
    
    // Set transparent colors for when bars appear temporarily
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    await _initializeLocalServices();

    await setupLocator();

    // Safety check: ensure critical services are registered before building the widget tree
    assert(
      locator.isRegistered<SessionService>(),
      'SessionService not registered before runApp! Ensure setupLocator() runs first.',
    );
    assert(
      locator.isRegistered<ThemeProvider>(),
      'ThemeProvider not registered before runApp! Ensure setupLocator() registers it.',
    );
    assert(
      locator.isRegistered<WordService>() &&
          locator.isRegistered<UserService>(),
      'Core services (WordService/UserService) not registered before runApp!',
    );

    await _initializeCriticalServices();

    runApp(const BootApp());
  } catch (e, st) {

    runApp(const _MinimalErrorApp());
  }
}

/// Hızlı ilk frame için minimal uygulama kabuğu
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> with WidgetsBindingObserver {
  // BootApp kendi MaterialApp'ı içinde gezinmek için yerel navigator key
  final GlobalKey<NavigatorState> _bootNavigatorKey =
      GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enforceImmersiveMode();
    
    // Phase-B: start non-critical initializations in background after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {

      // No Firebase re-initialization here; Phase-A already did it.
      unawaited(_initializeNonCriticalServices());
      unawaited(_initializeFirebaseServices());
      unawaited(_initializeFirebaseMessaging());

      // Navigate to the fully initialized app after the first frame
      if (!mounted) return;
      _bootNavigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const InitializedApp()),
      );

    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-enforce immersive mode when app comes back to foreground
      _enforceImmersiveMode();
    }
  }
  
  void _enforceImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _bootNavigatorKey,
      title: 'LexiFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator(),
              ),
              SizedBox(height: 12),
              Text('Yükleniyor...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalErrorApp extends StatelessWidget {
  const _MinimalErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'Initialization failed.\nPlease restart the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

Future<void> _initializeFirebaseServices() async {
  // Phase-B services init: no Firebase core re-initialization here
  if (Firebase.apps.isEmpty) {

    return;
  }

  // Firebase Crashlytics'i başlat
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  if (kDebugMode) {

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      Logger.e(
        'Flutter Error',
        details.exception,
        details.stack,
        'FlutterError',
      );
      Logger.logMemoryUsage('Flutter Error Occurred');
    };
  }

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Firebase Analytics'i başlat
  FirebaseAnalytics.instance;

  // Firebase Remote Config'i başlat

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ),
  );

  await remoteConfig.setDefaults(const {'fsrs_prompt_ratio': 4});

  try {
    await remoteConfig.fetchAndActivate();

  } catch (e) {

  }
}

// Helper functions for category metadata
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Do not re-initialize Firebase here to avoid duplicate-app errors.
  // In background isolate, if Firebase isn't available, skip handling.
  if (Firebase.apps.isEmpty) {
    // Firebase not initialized in background isolate; skipping handler
    return;
  }
}

Future<void> _initializeFirebaseMessaging() async {
  // Phase-B messaging init: Firebase is already initialized in Phase-A
  if (Firebase.apps.isEmpty) {

    return;
  }
  await NotificationService().init();
  final messaging = FirebaseMessaging.instance;
  try {
    final settings = await messaging.requestPermission();

  } catch (e) {

  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;
    final payload = message.data.isNotEmpty ? jsonEncode(message.data) : null;
    if (notification != null) {
      await NotificationService().showInstant(
        title: notification.title ?? 'LexiFlow',
        body: notification.body ?? '',
        payload: payload,
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (message.data.isNotEmpty) {
      NotificationService().handleMessageNavigation(message.data);
    }
  });

  try {
    final token = await messaging.getToken();
    if (token != null) {

    }
  } catch (e) {

  }

  try {
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && initialMessage.data.isNotEmpty) {
      NotificationService().handleMessageNavigation(initialMessage.data);
    }
  } catch (e) {

  }
}

String _getCategoryName(String categoryKey) {
  const categoryNames = {
    'biology': 'Biyoloji',
    'business': 'İş Dünyası',
    'chemistry': 'Kimya',
    'computer': 'Bilgisayar',
    'economics': 'Ekonomi',
    'geography': 'Coğrafya',
    'history': 'Tarih',
    'literature': 'Edebiyat',
    'mathematics': 'Matematik',
    'medicine': 'Tıp',
    'philosophy': 'Felsefe',
    'physics': 'Fizik',
    'politics': 'Politika',
    'psychology': 'Psikoloji',
    'sociology': 'Sosyoloji',
    'technology': 'Teknoloji',
  };
  return categoryNames[categoryKey] ?? categoryKey.toUpperCase();
}

String _getCategoryIcon(String categoryKey) {
  const categoryIcons = {
    'biology': '🧬',
    'business': '💼',
    'chemistry': '⚗️',
    'computer': '💻',
    'economics': '📈',
    'geography': '🌍',
    'history': '📜',
    'literature': '📚',
    'mathematics': '🔢',
    'medicine': '⚕️',
    'philosophy': '🤔',
    'physics': '⚛️',
    'politics': '🏛️',
    'psychology': '🧠',
    'sociology': '👥',
    'technology': '🔧',
  };
  return categoryIcons[categoryKey] ?? '📖';
}

Future<void> _initializeLocalServices() async {
  // intl paketi için yerel veri formatlarını başlat

  await initializeDateFormatting('tr_TR', null);

  // Hive'ı başlat

  await Hive.initFlutter();

  Hive.registerAdapter(WordAdapter());
  Hive.registerAdapter(DailyLogAdapter());
  Hive.registerAdapter(UserDataAdapter());
  Hive.registerAdapter(CachedUserDataAdapter());
  
  // Register Silent Sync adapter
  Hive.registerAdapter(SyncOperationAdapter());

  await ensureFlashcardsCacheBox();

  // Initialize Silent Sync services

  await SyncQueueService().init();
  await BackgroundSyncManager().init();

  // Trigger background sync (fire and forget - non-blocking)
  unawaited(BackgroundSyncManager().syncOnAppStart());

}

Future<void> _initializeCriticalServices() async {
  // Kritik servisler artık DI locator tarafından yönetiliyor

  final wordService = locator<WordService>();
  await wordService.init();

  final userService = locator<UserService>();
  await userService.init();

  final sessionService = locator<SessionService>();
  sessionService.setUserService(userService);
  await sessionService.initialize();

}

Future<void> _initializeNonCriticalServices() async {
  try {
    if (!locator.isRegistered<UserService>()) {

      return;
    }
    final userService = locator<UserService>();
    userService.updateStreak();

    // AdMob'u başlat (opsiyonel, kritik değil)
    if (FeatureFlags.adsEnabled) {
      try {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(),
        );

        await AdService.initialize();

        // Preload a rewarded ad to reduce latency on first gate (silent)
        final adService = locator<AdService>();
        try {
          await adService.loadRewardedAd();
        } catch (_) {}
      } catch (_) {}
    }

    // Bildirim planlarını uygula (init dahili olarak çağrılır)

    final notificationService = NotificationService();
    final currentUserId = locator<SessionService>().currentUser?.uid;
    await notificationService.applySchedulesFromPrefs(userId: currentUserId);

    // LearnedWordsService'i başlat

    final learnedWordsService = LearnedWordsService();
    await learnedWordsService.initialize();

    // SessionService handles its own non-critical initialization (LeaderboardService, real-time listeners)

  } catch (e) {

  }
}

class InitializedApp extends StatefulWidget {
  const InitializedApp({super.key});

  @override
  State<InitializedApp> createState() => _InitializedAppState();
}

class _InitializedAppState extends State<InitializedApp> with WidgetsBindingObserver {
  late final ThemeProvider _themeProvider;
  late final SessionService _sessionService;
  late final WordService _wordService;
  late final UserService _userService;
  late final MigrationIntegrationService _migrationIntegrationService;
  late final AdService _adService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enforceImmersiveMode();
    
    // Resolve DI dependencies in initState to avoid locator access during build
    if (!locator.isRegistered<ThemeProvider>()) {
      // ThemeProvider not registered; showing error UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const _MinimalErrorApp()),
        );
      });
      return;
    }
    _themeProvider = locator<ThemeProvider>();
    _sessionService = locator<SessionService>();
    _wordService = locator<WordService>();
    _userService = locator<UserService>();
    _migrationIntegrationService = locator<MigrationIntegrationService>();
    _adService = locator<AdService>();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-enforce immersive mode when app comes back to foreground
      _enforceImmersiveMode();
    }
  }
  
  void _enforceImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  Widget build(BuildContext context) {

    // App is considered initialized because main() performed
    // critical initialization before runApp.
    return _buildInitializedApp();
  }

  Widget _buildErrorApp() {
    return MaterialApp(
      title: 'LexiFlow',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('LexiFlow')),
        body: Center(
          child: Text(
            'Initialization failed. Please restart the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildInitializedApp() {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightSchemeBase =
            lightDynamic ?? lexiflowFallbackLightScheme;
        final ColorScheme darkSchemeBase =
            darkDynamic ?? lexiflowFallbackDarkScheme;

        final lightScheme = blendWithLexiFlowAccent(lightSchemeBase);
        final darkScheme = blendWithLexiFlowAccent(darkSchemeBase);

        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _themeProvider),
            ChangeNotifierProvider.value(value: _sessionService),
            ChangeNotifierProvider(create: (_) => ProfileStatsProvider()),
            ChangeNotifierProvider(create: (_) => AchievementService()),
            ChangeNotifierProvider(create: (_) => SyncStatusProvider()),
            ChangeNotifierProvider(create: (_) => CardsProvider()..loadSets()),
            Provider.value(value: _wordService),
            Provider.value(value: _userService),
            Provider.value(value: _migrationIntegrationService),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                title: 'LexiFlow',
                debugShowCheckedModeBanner: false,
                navigatorKey: NotificationService().navigatorKey,
                theme: buildLexiFlowTheme(lightScheme),
                darkTheme: buildLexiFlowTheme(darkScheme),
                themeMode: themeProvider.themeMode,
                home: MobileOnlyGuard(
                  child: AuthWrapper(
                    wordService: _wordService,
                    userService: _userService,
                    migrationIntegrationService: _migrationIntegrationService,
                    adService: _adService,
                  ),
                ),
                routes: {
                  '/splash':
                      (context) => SplashScreen(
                        wordService: _wordService,
                        userService: _userService,
                        migrationIntegrationService:
                            _migrationIntegrationService,
                        adService: _adService,
                      ),
                  '/dashboard':
                      (context) => DashboardScreen(
                        wordService: _wordService,
                        userService: _userService,
                        adService: _adService,
                      ),
                  '/favorites':
                      (context) => FavoritesScreen(
                        wordService: _wordService,
                        userService: _userService,
                        adService: _adService,
                      ),
                  '/daily-challenge':
                      (context) => DailyChallengeScreen(
                        wordService: _wordService,
                        userService: _userService,
                        adService: _adService,
                      ),
                  '/daily-word': (context) => const DailyWordScreen(),
                  '/word-detail': (context) {
                    final args = ModalRoute.of(context)?.settings.arguments;
                    if (args is Word) {
                      return WordDetailScreen(word: args);
                    }
                    return const Scaffold(
                      body: Center(child: Text('Word not found')),
                    );
                  },
                  '/profile': (context) => const ProfileScreen(),
                  '/login': (context) => const SignInScreen(),
                  '/privacy-policy': (context) => const PrivacyPolicyScreen(),
                  '/terms-of-service':
                      (context) => const TermsOfServiceScreen(),
                  '/share-preview':
                      (context) => SharePreviewScreen(
                        userStats: UserStatsModel(
                          level: 1,
                          xp: 0,
                          longestStreak: 0,
                          learnedWords: 0,
                          quizzesCompleted: 0,
                        ),
                      ),
                  '/quiz-center': (context) => const QuizCenterScreen(),
                  '/quiz/general': (context) => const GeneralQuizScreen(),
                  '/quiz/start': (context) {
                    final args =
                        ModalRoute.of(context)?.settings.arguments
                            as Map<String, dynamic>?;
                    return QuizStartScreen(
                      categoryKey: args?['categoryKey'] as String?,
                      categoryName: args?['categoryName'] as String?,
                      categoryIcon: args?['categoryIcon'] as String?,
                    );
                  },
                  '/quiz/play':
                      (context) => CategoryQuizPlayScreen(
                        wordService: _wordService,
                        userService: _userService,
                      ),
                  if (kDebugMode)
                    '/connectivity-debug':
                        (context) => const ConnectivityDebugWidget(),
                },
                onGenerateRoute: (settings) {
                  // Handle dynamic routes like /quiz/category/:key
                  // Commented out - now using QuizTypeSelectScreen flow
                  // if (settings.name?.startsWith('/quiz/category/') == true) {
                  //   final categoryKey = settings.name!.split('/').last;
                  //   return MaterialPageRoute(
                  //     builder: (context) => CategoryQuizScreen(
                  //       category: categoryKey,
                  //       categoryName: _getCategoryName(categoryKey),
                  //       categoryIcon: _getCategoryIcon(categoryKey),
                  //     ),
                  //     settings: settings,
                  //   );
                  // }
                  return null;
                },
                builder: (context, child) {
                  final content = child ?? const SizedBox.shrink();
                  // Wrap with ImmersiveWrapper to enforce fullscreen and remove padding
                  // Then wrap with ConnectionStatusWidget for network status
                  return ImmersiveWrapper(
                    child: ConnectionStatusWidget(
                      child: content,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class AppInitializationController extends ChangeNotifier {
  bool _isReady = false;
  bool _isInitializing = false;
  Object? _error;
  StackTrace? _stackTrace;

  bool get isReady => _isReady;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  Future<void> initialize() async {
    if (_isReady || _isInitializing) {
      return;
    }
    _isInitializing = true;

    try {
      // Yield to the scheduler so the first frame can render before heavy work.
      await Future<void>.delayed(Duration.zero);

      // Phase-A already handled Firebase, locator, and critical services.
      // Here we only verify readiness and surface any issues.
      if (Firebase.apps.isEmpty) {
        throw StateError('Firebase not initialized before AppInit');
      }
      if (!locator.isRegistered<UserService>() ||
          !locator.isRegistered<ThemeProvider>() ||
          !locator.isRegistered<SessionService>()) {
        throw StateError('DI not fully configured before AppInit');
      }

      _error = null;
      _stackTrace = null;
      _isReady = true;
      notifyListeners();

      // Non-critical tasks are already handled in BootApp Phase-B.
    } catch (e, stack) {
      _error = e;
      _stackTrace = stack;

      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }
}

