import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../di/locator.dart';
import '../models/word_model.dart';
import '../services/daily_word_service.dart';
import '../services/daily_word_service_v2.dart';
import '../services/local_streak_tracker.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  GlobalKey<NavigatorState> get navigatorKey {
    _navigatorKey ??= GlobalKey<NavigatorState>();
    return _navigatorKey!;
  }

  void registerNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // Channel definitions
  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        'lexiflow_general',
        'LexiFlow Bildirimleri',
        description: 'Genel uygulama bildirimleri',
        importance: Importance.defaultImportance,
      );

  // Fixed IDs for scheduled notifications
  static const int idDailyWord = 1001;
  static const int idStreak = 1002;
  static const int idReview = 1003;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // Timezone init (safe-guarded)
      try {
        tz.initializeTimeZones();
        final localName = DateTime.now().timeZoneName;
        try {
          tz.setLocalLocation(tz.getLocation(localName));
        } catch (_) {
          // Fallback to default local if mapping fails
          tz.setLocalLocation(tz.local);
        }
      } catch (e) {
      }

      // Use drawable instead of mipmap for notification icon
      const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (resp) async {
          final payload = resp.payload;
          if (payload != null && payload.isNotEmpty) {
            _handlePayload(payload);
          }
        },
      );

      // Create default channel on Android
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(_defaultChannel);
      }

      _initialized = true;
    } catch (e, stackTrace) {
      // Don't rethrow - allow app to continue without notifications
      _initialized = false;
    }
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidImpl =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final granted =
          await androidImpl?.requestNotificationsPermission() ??
          true; // pre-Android 13 returns null
      return granted;
    } else {
      final ios =
          _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      final result = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }
  }

  Future<void> showInstant({
    required String title,
    required String body,
    String? payload,
  }) async {
    final android = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    String? payload,
    Set<int>? weekdays, // 1=Mon ... 7=Sun
  }) async {
    final android = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);

    if (weekdays == null || weekdays.isEmpty) {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } else {
      // Schedule per weekday with unique IDs (id * 10 + weekday)
      for (final w in weekdays) {
        final scheduled = _nextInstanceOfWeekday(time, w);
        await _plugin.zonedSchedule(
          id * 10 + w,
          title,
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: payload,
        );
      }
    }
  }

  tz.TZDateTime _nextInstanceOfWeekday(TimeOfDay time, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();

  // Preferences helpers
  static const _kDailyWordEnabled = 'notif_daily_word_enabled';
  static const _kDailyWordHour = 'notif_daily_word_hour';
  static const _kDailyWordMin = 'notif_daily_word_min';
  static const _kDailyWordWeekdaysOnly = 'notif_daily_word_weekdays_only';
  static const _kDailyWordScheduledDate = 'notif_daily_word_scheduled_date';
  static const _kDailyWordPayload = 'notif_daily_word_payload';

  static const _kStreakEnabled = 'notif_streak_enabled';
  static const _kStreakHour = 'notif_streak_hour';
  static const _kStreakMin = 'notif_streak_min';
  static const _kStreakWeekdaysOnly = 'notif_streak_weekdays_only';

  static const _kReviewEnabled = 'notif_review_enabled';
  static const _kReviewHour = 'notif_review_hour';
  static const _kReviewMin = 'notif_review_min';
  static const _kReviewWeekdaysOnly = 'notif_review_weekdays_only';

  static const _kQuietStartHour = 'notif_quiet_start_h';
  static const _kQuietStartMin = 'notif_quiet_start_m';
  static const _kQuietEndHour = 'notif_quiet_end_h';
  static const _kQuietEndMin = 'notif_quiet_end_m';

  Future<void> saveDailyWordPref(bool enabled, TimeOfDay time) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kDailyWordEnabled, enabled);
    await sp.setInt(_kDailyWordHour, time.hour);
    await sp.setInt(_kDailyWordMin, time.minute);
  }

  Future<(bool enabled, TimeOfDay time)> loadDailyWordPref() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool(_kDailyWordEnabled) ?? false;
    final hour = sp.getInt(_kDailyWordHour) ?? 9;
    final min = sp.getInt(_kDailyWordMin) ?? 0;
    return (enabled, TimeOfDay(hour: hour, minute: min));
  }

  Future<void> saveDailyWordWeekdaysOnly(bool weekdaysOnly) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kDailyWordWeekdaysOnly, weekdaysOnly);
  }

  Future<bool> loadDailyWordWeekdaysOnly() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kDailyWordWeekdaysOnly) ?? false;
  }

  String _todayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> saveStreakPref(bool enabled, TimeOfDay time) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kStreakEnabled, enabled);
    await sp.setInt(_kStreakHour, time.hour);
    await sp.setInt(_kStreakMin, time.minute);
  }

  Future<(bool enabled, TimeOfDay time)> loadStreakPref() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool(_kStreakEnabled) ?? false;
    final hour = sp.getInt(_kStreakHour) ?? 20;
    final min = sp.getInt(_kStreakMin) ?? 0;
    return (enabled, TimeOfDay(hour: hour, minute: min));
  }

  Future<void> saveStreakWeekdaysOnly(bool weekdaysOnly) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kStreakWeekdaysOnly, weekdaysOnly);
  }

  Future<bool> loadStreakWeekdaysOnly() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kStreakWeekdaysOnly) ?? false;
  }

  Future<void> saveReviewPref(bool enabled, TimeOfDay time) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kReviewEnabled, enabled);
    await sp.setInt(_kReviewHour, time.hour);
    await sp.setInt(_kReviewMin, time.minute);
  }

  Future<(bool enabled, TimeOfDay time)> loadReviewPref() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool(_kReviewEnabled) ?? false;
    final hour = sp.getInt(_kReviewHour) ?? 18;
    final min = sp.getInt(_kReviewMin) ?? 0;
    return (enabled, TimeOfDay(hour: hour, minute: min));
  }

  Future<void> saveReviewWeekdaysOnly(bool weekdaysOnly) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kReviewWeekdaysOnly, weekdaysOnly);
  }

  Future<bool> loadReviewWeekdaysOnly() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kReviewWeekdaysOnly) ?? false;
  }

  Future<void> saveQuietHours(TimeOfDay start, TimeOfDay end) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kQuietStartHour, start.hour);
    await sp.setInt(_kQuietStartMin, start.minute);
    await sp.setInt(_kQuietEndHour, end.hour);
    await sp.setInt(_kQuietEndMin, end.minute);
  }

  Future<(TimeOfDay start, TimeOfDay end)> loadQuietHours() async {
    final sp = await SharedPreferences.getInstance();
    final sh = sp.getInt(_kQuietStartHour) ?? 23;
    final sm = sp.getInt(_kQuietStartMin) ?? 0;
    final eh = sp.getInt(_kQuietEndHour) ?? 7;
    final em = sp.getInt(_kQuietEndMin) ?? 0;
    return (TimeOfDay(hour: sh, minute: sm), TimeOfDay(hour: eh, minute: em));
  }

  Future<void> _scheduleDailyWordNotification({
    required String userId,
    required TimeOfDay time,
    required bool weekdaysOnly,
  }) async {
    try {
      // Use DailyWordServiceV2 to get first word from user's personal daily words
      final dailyWordService = DailyWordServiceV2();
      final wordId = await dailyWordService.getFirstDailyWordForNotification(userId);
      
      if (wordId == null) {
        // No personal daily words for today, skip notification
        await cancel(idDailyWord);
        return;
      }
      
      // Use Turkish notification message
      const body = 'Günün kelimesini hatırladın mı?';
      
      // Create payload to navigate to daily words screen
      final payloadMap = <String, dynamic>{
        'route': '/daily-words',
        'word': wordId,
        'scheduledFor': _todayKey(),
      };
      final payload = jsonEncode(payloadMap);
      
      // Schedule notification with the word as title
      await scheduleDaily(
        id: idDailyWord,
        title: wordId,
        body: body,
        time: time,
        weekdays:
            weekdaysOnly ? const {1, 2, 3, 4, 5} : const {1, 2, 3, 4, 5, 6, 7},
        payload: payload,
      );
      
      
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kDailyWordScheduledDate, _todayKey());
      await sp.setString(_kDailyWordPayload, payload);
    } catch (e) {
    }
  }

  Future<void> applySchedulesFromPrefs({String? userId}) async {
    await init();
    final (dwEnabled, dwTime) = await loadDailyWordPref();
    final (stEnabled, stTime) = await loadStreakPref();
    final (rvEnabled, rvTime) = await loadReviewPref();
    final dwWeekdays = await loadDailyWordWeekdaysOnly();
    final stWeekdays = await loadStreakWeekdaysOnly();
    final rvWeekdays = await loadReviewWeekdaysOnly();

    if (dwEnabled && userId != null) {
      await _scheduleDailyWordNotification(
        userId: userId,
        time: dwTime,
        weekdaysOnly: dwWeekdays,
      );
    } else {
      await cancel(idDailyWord);
    }

    if (stEnabled) {
      // Use smart streak notification instead of generic one
      await scheduleSmartStreakNotification(time: stTime, weekdaysOnly: stWeekdays);
    } else {
      await cancel(idStreak);
    }

    if (rvEnabled) {
      await scheduleDaily(
        id: idReview,
        title: 'Time to Review',
        body: 'Revisit your pending words and keep the flow going.',
        time: rvTime,
        weekdays: rvWeekdays ? {1, 2, 3, 4, 5} : {1, 2, 3, 4, 5, 6, 7},
        payload: '/favorites',
      );
    } else {
      await cancel(idReview);
    }
  }

  /// Schedule smart streak notification with dynamic message
  /// Only schedules if user hasn't studied today
  Future<void> scheduleSmartStreakNotification({
    required TimeOfDay time,
    bool weekdaysOnly = false,
  }) async {
    try {
      final streakTracker = LocalStreakTracker();
      final hasStudied = await streakTracker.hasStudiedToday();
      
      if (hasStudied) {
        // User already studied, cancel notification
        await cancel(idStreak);
        if (kDebugMode) {
        }
        return;
      }
      
      // Get current streak for message
      final streak = await streakTracker.getCurrentStreak();
      final message = _getStreakNotificationBody(streak);
      
      // Check if we should schedule for today
      final now = DateTime.now();
      final scheduledTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      
      if (scheduledTime.isBefore(now)) {
        // Already past scheduled time today, don't schedule
        if (kDebugMode) {
        }
        return;
      }
      
      await scheduleDaily(
        id: idStreak,
        title: 'LexiFlow Streak Alert',
        body: message,
        time: time,
        weekdays: weekdaysOnly ? {1, 2, 3, 4, 5} : {1, 2, 3, 4, 5, 6, 7},
        payload: '/dashboard',
      );
      
      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  /// Get dynamic notification message based on streak count
  String _getStreakNotificationBody(int streak) {
    if (streak > 0) {
      return "🔥 Danger! Your $streak day streak is about to break! Rescue it now!";
    } else {
      return "Time to start a new winning streak! 🚀";
    }
  }

  /// Cancel streak notification (call when user studies)
  Future<void> cancelStreakNotificationIfStudied() async {
    try {
      final streakTracker = LocalStreakTracker();
      final hasStudied = await streakTracker.hasStudiedToday();
      
      if (hasStudied) {
        await cancel(idStreak);
        if (kDebugMode) {
        }
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  void _handlePayload(String payload) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    if (payload.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _handlePayloadMap(decoded);
        return;
      }
    } catch (_) {
      // Fallback to treating payload as a route string.
    }

    try {
      nav.pushNamed(payload);
    } catch (_) {}
  }

  void handleMessageNavigation(Map<String, dynamic> data) {
    _handlePayloadMap(data);
  }

  void _handlePayloadMap(Map<String, dynamic> data) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    final route = (data['route'] ?? data['target'])?.toString();
    if (route == '/word-detail') {
      final word = _wordFromPayload(data);
      if (word != null) {
        try {
          nav.pushNamed('/word-detail', arguments: word);
        } catch (_) {}
        return;
      }
    }

    if (route != null && route.isNotEmpty) {
      try {
        nav.pushNamed(route);
      } catch (_) {}
    }
  }

  Word? _wordFromPayload(Map<String, dynamic> data) {
    final wordText = (data['word'] ?? data['wordText'] ?? '').toString().trim();
    if (wordText.isEmpty) {
      return null;
    }

    final meaning = (data['meaning'] ?? '').toString();
    final translation = (data['tr'] ?? data['translation'] ?? '').toString();
    final exampleSentence =
        (data['exampleSentence'] ?? data['example'] ?? '').toString();
    final category = (data['category'] ?? '').toString().trim();

    return Word(
      word: wordText,
      meaning: meaning,
      example: exampleSentence,
      tr: translation,
      exampleSentence: exampleSentence,
      isFavorite: false,
      nextReviewDate: null,
      interval: 1,
      correctStreak: 0,
      tags: const [],
      srsLevel: 0,
      isCustom: false,
      category: category.isEmpty ? null : category,
      createdAt: null,
    );
  }
}
