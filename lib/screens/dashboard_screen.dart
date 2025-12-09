import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/ad_service.dart';
import '../services/session_service.dart';
import '../services/daily_word_service.dart';
import '../services/statistics_service.dart';
import '../services/local_streak_tracker.dart';
import '../utils/design_system.dart';
import '../utils/app_icons.dart';
import 'package:flutter/services.dart';
import '../utils/feature_flags.dart';
import '../services/notification_service.dart';
import 'word_detail_screen.dart';
import 'statistics_screen.dart';
// import 'leaderboard_screen.dart';
import '../widgets/lexiflow_toast.dart';
import 'daily_challenge_screen.dart';
import '../providers/profile_stats_provider.dart';
import '../utils/id_list_sanitizer.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/streak_debug.dart';
import '../widgets/countdown_widget.dart';

class DashboardScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;
  static final ValueNotifier<int> _refreshNotifier = ValueNotifier<int>(0);

  const DashboardScreen({
    super.key,
    required this.wordService,
    required this.userService,
    required this.adService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();

  static void requestFreshLoad() {
    _refreshNotifier.value++;
  }
}

// removed old pinned header delegate in favor of FAB coach UI

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final DailyWordService _dailyWordService = DailyWordService();
  final StatisticsService _statisticsService = StatisticsService();
  final NotificationService _notificationService = NotificationService();

  // Service references from widget
  late final WordService _wordService;
  late final UserService _userService;
  late final AdService _adService;
  late final SessionService _sessionService;

  List<Word> _dailyWords = [];
  bool _isLoading = false; // Start as false, only show skeleton on first load
  bool _hasLoadedOnce = false;
  bool _isFetchingDailyWords = false;
  bool _hasExtraWords = false; // Track if user has unlocked extra words today

  Timer? _midnightCheckTimer;
  DateTime? _lastBuildLog;
  bool _midnightTriggered = false;
  late int _lastExternalRefreshSignal;
  late final VoidCallback _refreshListener;
  String? _lastLoadedDate; // Track the date of last loaded words

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Initialize service references from widget
    _wordService = widget.wordService;
    _userService = widget.userService;
    _adService = widget.adService;
    _sessionService = Provider.of<SessionService>(context, listen: false);

    _lastExternalRefreshSignal = DashboardScreen._refreshNotifier.value;
    _refreshListener = () {
      final signal = DashboardScreen._refreshNotifier.value;
      if (signal != _lastExternalRefreshSignal && mounted) {
        _lastExternalRefreshSignal = signal;
        _checkAndLoadDailyWords();
      }
    };
    DashboardScreen._refreshNotifier.addListener(_refreshListener);

    // Only load on first init
    if (!_hasLoadedOnce) {
      // Show skeleton for first load
      setState(() => _isLoading = true);
      _checkAndLoadDailyWords();
    }
    
    // Record study session for streak tracking
    Future.microtask(() async {
      await LocalStreakTracker().recordStudySession();
      // Cancel streak notification if user studied today
      await NotificationService().cancelStreakNotificationIfStudied();
    });
    
    Future.microtask(_scheduleNotifications);
    _startMidnightCheckTimer();
    
    // Debug: Verify streak data and check increment
    if (kDebugMode) {
      Future.delayed(const Duration(seconds: 2), () async {
        final userId = _sessionService.currentUser?.uid;
        if (userId != null) {

          await StreakDebug.verifyStreakData(userId);
          await StreakDebug.checkStreakReset(userId);

        }
      });
    }
  }

  @override
  void dispose() {
    _midnightCheckTimer?.cancel();
    DashboardScreen._refreshNotifier.removeListener(_refreshListener);
    _dailyWordService.dispose();
    super.dispose();
  }

  /// Check if we need to load new daily words based on date
  Future<void> _checkAndLoadDailyWords() async {
    final today = _dailyWordService.getCurrentDateKey();
    
    // If we haven't loaded yet or the date has changed, load new words
    if (_lastLoadedDate == null || _lastLoadedDate != today) {

      _lastLoadedDate = today;
      
      // Always load silently - skeleton is controlled separately
      await _loadDailyWords(silent: true);
    } else if (_dailyWords.isEmpty) {
      // If words are empty but date is same, reload silently
      await _loadDailyWords(silent: true);
    }
    // Else: Same day and words already loaded, do nothing (keep alive)
  }

  void _scheduleNotifications() async {
    try {
      final userId = _sessionService.currentUser?.uid;
      await _notificationService.applySchedulesFromPrefs(userId: userId);
    } catch (e) {

    }
  }

  Future<void> _loadDailyWords({bool silent = false}) async {
    if (_isFetchingDailyWords) return;

    _isFetchingDailyWords = true;

    if (!mounted) {
      _isFetchingDailyWords = false;
      return;
    }

    // Don't set _isLoading here - it's controlled by initState
    // This prevents skeleton from showing on tab switches

    try {
      final user = _sessionService.currentUser;
      List<Word> words = [];
      if (user == null) {
        words = await _wordService.getRandomWords(DailyWordService.dailyWordCount);
      } else {
        final dailyWordsData = await _dailyWordService.getTodaysWords(user.uid);
        
        // Verify that the returned data is for today
        final today = _dailyWordService.getCurrentDateKey();
        final returnedDate = dailyWordsData['date'] as String?;
        
        if (returnedDate != null && returnedDate != today) {

          // Force regenerate for today
          final newDailyWordsData = await _dailyWordService.generateDailyWords(user.uid);
          final sanitizedDailyWordIds = sanitizeIdList(
            newDailyWordsData['dailyWords'],
            context: 'dashboard/dailyWords/regenerated',
          );
          words = await _dailyWordService.getWordsByIds(sanitizedDailyWordIds);
        } else {
          // Load both daily words and extra words
          final sanitizedDailyWordIds = sanitizeIdList(
            dailyWordsData['dailyWords'],
            context: 'dashboard/dailyWords',
          );
          final sanitizedExtraWordIds = sanitizeIdList(
            dailyWordsData['extraWords'],
            context: 'dashboard/extraWords',
          );
          
          // Combine daily and extra words
          final allWordIds = [...sanitizedDailyWordIds, ...sanitizedExtraWordIds];

          words = await _dailyWordService.getWordsByIds(allWordIds);
        }
        
        if (words.isEmpty) {

          final fallback = await _wordService.getCategoryWords('general') ?? [];
          words = fallback.take(10).toList();
        }
      }

      if (!mounted) return;

      // Update last loaded date on successful load
      _lastLoadedDate = _dailyWordService.getCurrentDateKey();

      setState(() {
        _dailyWords = words;
        // Update extra words flag if we have the info
        if (user != null) {
          _hasExtraWords = words.length > DailyWordService.dailyWordCount;

        }
        // Only update _isLoading on first load
        if (!_hasLoadedOnce) {
          _isLoading = false;
        }
        _hasLoadedOnce = true;
      });
    } catch (e) {

      try {
        var words = await _wordService.getRandomWords(DailyWordService.dailyWordCount);
        if (words.isEmpty) {

          final generalWords = await _wordService.getCategoryWords('general') ?? [];
          words = generalWords.take(10).toList();
        }
        if (!mounted) return;
        setState(() {
          _dailyWords = words;
          // Only update _isLoading on first load
          if (!_hasLoadedOnce) {
            _isLoading = false;
          }
          _hasLoadedOnce = true;
        });
      } catch (fallbackError) {

        if (!mounted) return;
        setState(() {
          // Only update _isLoading on first load
          if (!_hasLoadedOnce) {
            _isLoading = false;
          }
          _hasLoadedOnce = true;
        });
      }
    } finally {
      _isFetchingDailyWords = false;
      _midnightTriggered = false;
    }
  }

  Future<void> _loadMoreWords() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final userId = sessionService.currentUser?.uid;

    if (userId == null) {
      _showSnackBar('Giriş yapmalısınız', Icons.error_outline);
      return;
    }

    try {

      // Check if services are initialized
      if (!mounted) {

        return;
      }
      
      // Check if user already watched ad today

      final canWatch = await _dailyWordService.canWatchAdForExtraWords(userId);

      if (!canWatch) {
        _showSnackBar('Bugün zaten +5 kelime aldınız!', Icons.info_outline);
        return;
      }

      // Ensure rewarded ad is ready
      if (FeatureFlags.adsEnabled) {

        if (!_adService.isRewardedReady) {
          _showSnackBar('Reklam yükleniyor, lütfen birkaç saniye bekleyin...', Icons.info_outline);

          try {
            await _adService.preloadRewarded();

            // Wait a bit for the ad to load
            await Future.delayed(const Duration(seconds: 3));

            if (!_adService.isRewardedReady) {
              _showSnackBar('Reklam yüklenemedi, lütfen tekrar deneyin', Icons.error_outline);
              return;
            }
          } catch (e, stackTrace) {

            // In debug mode, allow skipping ad if it fails to load
            if (kDebugMode) {

              _showSnackBar('Debug: Reklam atlandı, kelimeler ekleniyor...', Icons.info_outline);
              // Continue to generate words without watching ad
            } else {
              _showSnackBar('Reklam yüklenemedi', Icons.error_outline);
              return;
            }
          }
        }
      }

      // Show ad and get extra words

      bool adWatched = false;
      
      if (FeatureFlags.adsEnabled && _adService.isRewardedReady) {
        try {
          adWatched = await _adService.showRewardedAd();

        } catch (e) {

          if (kDebugMode) {

            adWatched = true; // In debug, treat error as success
          } else {
            _showSnackBar('Reklam gösterilemedi', Icons.error_outline);
            return;
          }
        }
      } else {
        // Ads disabled or not ready - in debug mode, allow anyway
        if (kDebugMode) {

          adWatched = true;
        }
      }

      if (!adWatched) {

        _showSnackBar('Reklam izlenmedi', Icons.error_outline);
        return;
      }

      // Generate 5 random extra words
      final extraWordIds = await _dailyWordService.generateExtraWords(userId);
      
      if (extraWordIds.isEmpty) {
        _showSnackBar('Ekstra kelime oluşturulamadı', Icons.error_outline);
        return;
      }

      // Reload daily words (now includes extra words)
      // _hasExtraWords will be automatically set in _loadDailyWords based on word count
      await _loadDailyWords(silent: false);

      // Award XP
      final prevLevel = sessionService.level;
      await sessionService.addXp(10);
      final leveledUpResult = sessionService.level > prevLevel;

      try {
        await _statisticsService.recordActivity(
          userId: userId,
          xpEarned: 10,
          learnedWordsCount: 5,
          quizzesCompleted: 0,
        );

      } catch (e) {

      }

      if (leveledUpResult) {
        _showLevelUpDialog(sessionService.level);
      } else {
        _showSnackBar(
          '🎉 +${extraWordIds.length} kelime eklendi! +10 XP',
          Icons.celebration,
          color: Colors.green,
        );
      }
    } catch (e, stackTrace) {

      String errorMessage = 'Bir hata oluştu';
      if (e.toString().contains('NotInitializedError')) {
        errorMessage = 'Servisler henüz hazır değil, lütfen birkaç saniye bekleyin';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Reklam izleme izni gerekli';
      }
      
      _showSnackBar(errorMessage, Icons.error_outline);
    }
  }

  Future<void> _maybeScheduleDailyReminder() async {
    if (!FeatureFlags.dailyCoachEnabled) return;
    try {
      final svc = NotificationService();
      await svc.init();
      await svc.requestPermission();
      final due = widget.wordService.getDueReviewCount();
      await svc.scheduleDaily(
        id: NotificationService.idReview,
        title: 'Gözden Geçirme Zamanı',
        body: 'Bekleyen $due kelimen var',
        time: const TimeOfDay(hour: 20, minute: 0),
        payload: '/favorites',
      );
    } catch (_) {
      // Best-effort: ignore notification errors
    }
  }

  void _startMidnightCheckTimer() {
    // Check every 10 seconds for midnight
    _midnightCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final remaining = _dailyWordService.getTimeUntilReset();
      if (remaining.inSeconds <= 0 && !_midnightTriggered) {
        _midnightTriggered = true;

        // Reset for new day
        _lastLoadedDate = null;
        _hasExtraWords = false;
        Future.microtask(() async {
          await _checkAndLoadDailyWords();
        });
      } else if (remaining.inSeconds > 0) {
        _midnightTriggered = false;
      }
    });
  }

  void _showSnackBar(String message, IconData icon, {Color? color}) {
    if (!mounted) return;
    ToastType toastType = ToastType.info;
    if (color == Colors.green) {
      toastType = ToastType.success;
    } else if (icon == Icons.error_outline) {
      toastType = ToastType.error;
    }

    showLexiflowToast(context, toastType, message);
  }

  void _showLevelUpDialog(int newLevel) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tebrikler!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Seviye $newLevel\'e ulaştın!',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '🎉 Harika gidiyorsun! 🎉',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Devam Et',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  /// Returns time-based Turkish greeting with title and subtitle
  Map<String, String> _getGreetingData() {
    final hour = DateTime.now().hour;
    
    // Morning (06:00 - 11:59)
    if (hour >= 6 && hour < 12) {
      return {
        'title': 'Günaydın! ☀️',
        'subtitle': 'Güne zinde başlamak için birkaç kelime öğrenelim.',
      };
    }
    
    // Afternoon (12:00 - 17:59)
    if (hour >= 12 && hour < 18) {
      return {
        'title': 'Tünaydın! 👋',
        'subtitle': 'Kahve molasında kısa bir pratik yapmaya ne dersin?',
      };
    }
    
    // Evening (18:00 - 22:59)
    if (hour >= 18 && hour < 23) {
      return {
        'title': 'İyi Akşamlar! 🌙',
        'subtitle': 'Günü verimli bitir, hedeflerini tamamla.',
      };
    }
    
    // Night (23:00 - 05:59)
    return {
      'title': 'Selam Gece Kuşu! 🦉',
      'subtitle': 'Uyumadan önce son bir tekrar harika olur.',
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin gereksinimi
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Build loglarını azaltmak için basit throttle
    final now = DateTime.now();
    if (kDebugMode &&
        (_lastBuildLog == null ||
            now.difference(_lastBuildLog!) > const Duration(seconds: 3))) {

      _lastBuildLog = now;
    }

    // Ana içerik: veriler hazırsa göster, değilse boş
    final Widget content = RefreshIndicator(
      onRefresh: _loadDailyWords,
      child: CustomScrollView(
        // Preserve scroll position across tab switches
        key: const PageStorageKey<String>('dashboard_scroll'),
        slivers: [
          // Modern Header with Gradient
          SliverToBoxAdapter(child: _buildModernHeader(isDark)),

          // Modern Word Cards Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.lg,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Show word cards
                  if (index < _dailyWords.length) {
                    return _buildModernWordCard(
                      _dailyWords[index],
                      index,
                      isDark,
                    );
                  }
                  // Show "Get More Words" card at the end if applicable
                  if (index == _dailyWords.length && !_hasExtraWords) {
                    return _buildModernMoreWordsCard(isDark);
                  }
                  return const SizedBox.shrink();
                },
                childCount: _dailyWords.length + (_hasExtraWords ? 0 : 1),
              ),
            ),
          ),
        ],
      ),
    );

    // Skeleton loader for better UX
    const loadingState = DashboardSkeleton();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder:
            (child, animation) => FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            ),
        child: (_isLoading && !_hasLoadedOnce) ? loadingState : content,
      ),
    );
  }

  // Modern Header
  Widget _buildModernHeader(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? [
                    const Color(0xFF1E293B), // Dark mode ilk renk
                    const Color(0xFF334155), // Dark mode ikinci renk
                  ]
                  : [
                    const Color(0xFFF8FAFC), // Light mode ilk renk
                    const Color(0xFFE2E8F0), // Light mode ikinci renk
                  ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.lg,
          AppSpacing.screenPadding,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // App Title with Streak
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LexiFlow',
                    style: AppTextStyles.title1.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final colorScheme = Theme.of(context).colorScheme;

                      BoxDecoration decoration() => BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.9),
                        borderRadius: AppBorderRadius.medium,
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      );

                      Widget decoratedIconButton({
                        required Icon icon,
                        required VoidCallback onPressed,
                        required String tooltip,
                      }) {
                        return Container(
                          decoration: decoration(),
                          child: IconButton(
                            icon: icon,
                            onPressed: onPressed,
                            tooltip: tooltip,
                          ),
                        );
                      }

                      return Row(
                        children: [
                          // Streak Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: decoration().copyWith(
                              borderRadius: AppBorderRadius.large,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Selector<ProfileStatsProvider, int>(
                                  selector: (_, provider) => provider.currentStreak,
                                  builder: (context, streak, _) {
                                    return Text(
                                      '$streak',
                                      style: AppTextStyles.title3.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Analytics Button
                          decoratedIconButton(
                            icon: Icon(
                              Icons.bar_chart_rounded,
                              color: colorScheme.onSurface,
                              size: 24,
                            ),
                            tooltip: 'İstatistikler',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const StatisticsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Leaderboard Button (hidden)
                          // decoratedIconButton(
                          //   icon: const Icon(
                          //     Icons.emoji_events_rounded,
                          //     color: Color(0xFFFFC107),
                          //     size: 26,
                          //   ),
                          //   tooltip: 'Liderlik Tablosu',
                          //   onPressed: () {
                          //     Navigator.push(
                          //       context,
                          //       MaterialPageRoute(
                          //         builder:
                          //             (context) => const LeaderboardScreen(),
                          //       ),
                          //     );
                          //   },
                          // ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Greeting Section
              Builder(
                builder: (context) {
                  final greetingData = _getGreetingData();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetingData['title']!,
                          style: AppTextStyles.headline3.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          greetingData['subtitle']!,
                          style: AppTextStyles.body1.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Countdown Timer (small, subtle)
              _buildCountdownTimer(),
              const SizedBox(height: AppSpacing.md),

              // Modern Stats Card
              ModernCard(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withOpacity(0.9),
                shadows: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
                showBorder: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Selector<ProfileStatsProvider, int>(
                        selector: (_, provider) => provider.learnedCount,
                        builder: (context, learnedCount, _) {
                          return _buildModernStatItem(
                            Icons.school,
                            '$learnedCount',
                            'Öğrenilen Kelime',
                          );
                        },
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: Selector<SessionService, int>(
                        selector: (_, service) => service.favoritesCount,
                        builder: (context, favCount, _) {
                          return _buildModernStatItem(
                            Icons.favorite_rounded,
                            '$favCount',
                            'Favorites',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }

  /*
  Widget _buildCoachFab(BuildContext context) {
    final due = widget.wordService.getDueReviewCount();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors =
        isDark
            ? AppDarkColors.successGradient
            : AppColors.successGradient; // turkuaz-yeşil degrade

    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}
          _showCoachSheet(context, due);
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            shape: BoxShape.circle,
          ),
          width: 56,
          height: 56,
          child: const Center(
            child: Icon(AppIcons.sparkles, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
  */

  /*
  Future<void> _showCoachSheet(BuildContext context, int due) async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.sparkles,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Günlük Koç',
                    style: AppTextStyles.title2.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                due > 0
                    ? 'Bugün $due kart hazır. Kısa bir tekrar öneriyoruz.'
                    : 'Yeni kelimeler seni bekliyor. Başlayalım mı?',
                style: AppTextStyles.body2.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // What it does (explanatory bullets)
              Row(
                children: [
                  Icon(
                    AppIcons.zap,
                    size: 18,
                    color: theme.colorScheme.secondary.withOpacity(0.9),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Doğru aralıklarla tekrar planlar (FSRS).',
                      style: AppTextStyles.body3.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    AppIcons.clock,
                    size: 18,
                    color: theme.colorScheme.secondary.withOpacity(0.9),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Günlük hedefini tek akışta tamamlarsın.',
                      style: AppTextStyles.body3.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    AppIcons.brain,
                    size: 18,
                    color: theme.colorScheme.secondary.withOpacity(0.9),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Cevap kalitesine göre kişiselleştirir (Zordu/İyiydi/Çok kolay).',
                      style: AppTextStyles.body3.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        try {
                          HapticFeedback.mediumImpact();
                        } catch (_) {}
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => DailyChallengeScreen(
                                  wordService: widget.wordService,
                                  userService: widget.userService,
                                  adService: widget.adService,
                                ),
                          ),
                        );
                      },
                      icon: const Icon(AppIcons.play),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Devam Et',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  */

  /*
  Widget _buildDailyCoachCard(BuildContext context) {
    final dueCount = widget.wordService.getDueReviewCount();
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: AppBorderRadius.large,
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Günlük Koç',
                  style: AppTextStyles.title2.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dueCount > 0
                      ? 'Hazır kartlar: $dueCount • Devam edelim mi?'
                      : 'Yeni kelimeler seni bekliyor',
                  style: AppTextStyles.body2.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            onPressed: () {
              // Navigate to Daily Challenge as the single flow
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => DailyChallengeScreen(
                        wordService: widget.wordService,
                        userService: widget.userService,
                        adService: widget.adService,
                      ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Devam Et',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
  */

  // Modern Stat Item
  Widget _buildModernStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 24),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: AppTextStyles.title2.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Modern Word Card
  Widget _buildModernWordCard(Word word, int index, bool isDark) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: ModernCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shadows: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        showBorder: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WordDetailScreen(word: word),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and favorite button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: AppBorderRadius.medium,
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    word.word,
                    style: AppTextStyles.title1.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Modern Favorite Button
                Consumer<SessionService>(
                  builder: (context, sessionService, _) {
                    final isGuest =
                        sessionService.isGuest || sessionService.isAnonymous;
                    if (isGuest) return const SizedBox.shrink();

                    return StreamBuilder<Set<String>>(
                      stream: widget.wordService.favoritesKeysStream(
                        sessionService.currentUser!.uid,
                      ),
                      builder: (context, snapshot) {
                        final keys = snapshot.data ?? <String>{};
                        final isFav = keys.contains(word.word);
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isFav
                                    ? AppColors.error.withOpacity(0.1)
                                    : AppColors.surfaceVariant,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color:
                                  isFav
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed:
                                () =>
                                    widget.wordService.toggleFavoriteFirestore(
                                      word,
                                      sessionService.currentUser!.uid,
                                    ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Meaning
            Text(
              word.meaning,
              style: AppTextStyles.body1.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),

            // Turkish Translation
            if (word.tr.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: AppBorderRadius.medium,
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇹🇷', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        word.tr,
                        style: AppTextStyles.body2.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        maxLines: 2,
                        textScaleFactor: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Example Sentence
            if (word.exampleSentence.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppBorderRadius.medium,
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 20,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.7),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        word.exampleSentence,
                        style: AppTextStyles.body2.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Modern More Words Card
  Widget _buildModernMoreWordsCard(bool isDark) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shadows: [
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withOpacity(0.15),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      showBorder: true,
      onTap: _loadMoreWords,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '+5 Kelime Daha',
            style: AppTextStyles.title1.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Reklam izle, 5 kelime daha gör',
            style: AppTextStyles.body2.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // Countdown Timer Widget (small and subtle)
  Widget _buildCountdownTimer() {
    // Widget now handles theme-aware colors internally
    return const CountdownWidget();
  }
}

