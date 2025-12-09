import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../utils/design_system.dart';
import '../services/notification_service.dart';
import '../di/locator.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../services/feedback_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool _notificationsEnabled = true;
  bool _dailyWordEnabled = false;
  TimeOfDay _dailyWordTime = const TimeOfDay(hour: 9, minute: 0);
  bool _dailyWordWeekdaysOnly = false;
  bool _isUpdatingDailyWord = false;
  late AnimationController _feedbackButtonController;
  late Animation<double> _feedbackButtonScale;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _setupAnimations();
  }

  void _setupAnimations() {
    _feedbackButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _feedbackButtonScale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _feedbackButtonController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationService = NotificationService();
      final (dailyEnabled, dailyTime) =
          await notificationService.loadDailyWordPref();
      final dailyWeekdaysOnly =
          await notificationService.loadDailyWordWeekdaysOnly();

      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _dailyWordEnabled = dailyEnabled;
        _dailyWordTime = dailyTime;
        _dailyWordWeekdaysOnly = dailyWeekdaysOnly;
      });
    } catch (e) {
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);

      final notificationService = NotificationService();
      final userId = locator<SessionService>().currentUser?.uid;
      if (value) {
        await notificationService.requestPermission();
        await notificationService.applySchedulesFromPrefs(userId: userId);
      } else {
        await notificationService.cancelAll();
      }

      HapticFeedback.lightImpact();
    } catch (e) {
    }
  }

  Future<void> _onDailyWordToggle(bool value) async {
    if (_isUpdatingDailyWord) return;
    HapticFeedback.lightImpact();
    setState(() {
      _dailyWordEnabled = value;
      _isUpdatingDailyWord = true;
    });

    try {
      final notificationService = NotificationService();
      await notificationService.saveDailyWordPref(value, _dailyWordTime);
      if (_notificationsEnabled) {
        final userId = locator<SessionService>().currentUser?.uid;
        await notificationService.applySchedulesFromPrefs(userId: userId);
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isUpdatingDailyWord = false);
      }
    }
  }

  Future<void> _onDailyWordWeekdaysToggle(bool value) async {
    if (_isUpdatingDailyWord) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dailyWordWeekdaysOnly = value;
      _isUpdatingDailyWord = true;
    });

    try {
      final notificationService = NotificationService();
      await notificationService.saveDailyWordWeekdaysOnly(value);
      if (_notificationsEnabled && _dailyWordEnabled) {
        final userId = locator<SessionService>().currentUser?.uid;
        await notificationService.applySchedulesFromPrefs(userId: userId);
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isUpdatingDailyWord = false);
      }
    }
  }

  Future<void> _pickDailyWordTime() async {
    if (!_notificationsEnabled || !_dailyWordEnabled || _isUpdatingDailyWord) {
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyWordTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dailyWordTime = picked;
      _isUpdatingDailyWord = true;
    });

    try {
      final notificationService = NotificationService();
      await notificationService.saveDailyWordPref(_dailyWordEnabled, picked);
      if (_notificationsEnabled && _dailyWordEnabled) {
        final userId = locator<SessionService>().currentUser?.uid;
        await notificationService.applySchedulesFromPrefs(userId: userId);
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isUpdatingDailyWord = false);
      }
    }
  }

  void _showFeedbackDialog() {
    HapticFeedback.mediumImpact();
    // Capture parent ScaffoldMessenger to pass to dialog
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FeedbackDialog(parentMessenger: parentMessenger),
    );
  }

  void _navigateToPrivacyPolicy() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => _LegalDocumentScreen(
              title: 'Privacy Policy',
              assetPath: 'assets/legal/privacy_policy.txt',
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _navigateToTermsOfService() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => _LegalDocumentScreen(
              title: 'Terms of Service',
              assetPath: 'assets/legal/terms_of_service.txt',
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _feedbackButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor:
          isDark ? AppDarkColors.background : const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color:
                isDark
                    ? AppDarkColors.textPrimary
                    : Colors.black.withOpacity(0.85),
            size: screenWidth * 0.06,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Ayarlar',
          style: AppTextStyles.title1.copyWith(
            color:
                isDark
                    ? AppDarkColors.textPrimary
                    : Colors.black.withOpacity(0.85),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        flexibleSpace: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (isDark ? AppDarkColors.surface : const Color(0xFFF6F8FC))
                    .withOpacity(0.9),
                (isDark ? AppDarkColors.surface : const Color(0xFFF6F8FC))
                    .withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;

            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: availableHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05, // 5% of screen width
                    vertical: availableHeight * 0.02, // 2% of available height
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: availableHeight * 0.02), // 2% spacing
                      // Theme Selector Card
                      _buildThemeCard(isDark, screenHeight, screenWidth),

                      SizedBox(height: availableHeight * 0.03), // 3% spacing
                      // Notification Toggle
                      _buildNotificationCard(isDark, screenHeight, screenWidth),

                      SizedBox(height: availableHeight * 0.03), // 3% spacing
                      _buildDailyWordCard(context, isDark, screenWidth),

                      SizedBox(height: availableHeight * 0.03), // 3% spacing
                      // Privacy & Terms Row
                      _buildLegalRow(isDark, screenHeight, screenWidth),

                      SizedBox(height: availableHeight * 0.03), // 3% spacing
                      // Feedback Button
                      _buildFeedbackButton(isDark, screenHeight, screenWidth),

                      SizedBox(height: availableHeight * 0.03), // 3% spacing
                      // Logout Button
                      _buildLogoutButton(isDark, screenHeight, screenWidth),

                      SizedBox(height: availableHeight * 0.03), // 3% spacing
                      // Delete Account Button (Danger Zone)
                      _buildDeleteAccountButton(isDark, screenHeight, screenWidth),

                      SizedBox(height: availableHeight * 0.02), // 2% spacing
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildThemeCard(bool isDark, double screenHeight, double screenWidth) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(minHeight: 85, maxHeight: 130),
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [const Color(0xFF2D3748), const Color(0xFF4A5568)]
                  : [const Color(0xFF4A56E2), const Color(0xFF8093F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.25)
                    : Colors.black.withOpacity(0.08),
            blurRadius: isDark ? 10 : 12,
            offset: isDark ? const Offset(0, 4) : const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow:
                          isDark
                              ? []
                              : [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                    ),
                    child: Icon(
                      Icons.dark_mode_rounded,
                      color: Colors.white,
                      size: screenWidth * 0.065, // Responsive icon size
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'App Theme',
                            style: AppTextStyles.title2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, _) {
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                themeProvider.getThemeModeName(
                                  themeProvider.themeMode,
                                ),
                                style: AppTextStyles.body3.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 2,
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final selected = await showModalBottomSheet<ThemeMode>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) {
                          return Container(
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? AppDarkColors.surface
                                      : const Color(0xFFF6F8FC),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Handle bar
                                  Container(
                                    margin: const EdgeInsets.only(
                                      top: 12,
                                      bottom: 8,
                                    ),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  // Title
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      'Tema Seçin',
                                      style: AppTextStyles.title2.copyWith(
                                        color:
                                            isDark
                                                ? AppDarkColors.textPrimary
                                                : Colors.black.withOpacity(
                                                  0.85,
                                                ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  // Theme options
                                  ...ThemeMode.values.map((mode) {
                                    final isSelected =
                                        themeProvider.themeMode == mode;
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? (isDark
                                                    ? Colors.white.withOpacity(
                                                      0.1,
                                                    )
                                                    : Colors.blue.withOpacity(
                                                      0.1,
                                                    ))
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border:
                                            isSelected
                                                ? Border.all(
                                                  color:
                                                      isDark
                                                          ? Colors.white
                                                              .withOpacity(0.3)
                                                          : Colors.blue
                                                              .withOpacity(0.3),
                                                  width: 1,
                                                )
                                                : null,
                                      ),
                                      child: ListTile(
                                        leading: Icon(
                                          mode == ThemeMode.light
                                              ? Icons.light_mode_rounded
                                              : mode == ThemeMode.dark
                                              ? Icons.dark_mode_rounded
                                              : Icons
                                                  .settings_system_daydream_rounded,
                                          color:
                                              isSelected
                                                  ? (isDark
                                                      ? Colors.white
                                                      : Colors.blue)
                                                  : (isDark
                                                      ? AppDarkColors
                                                          .textSecondary
                                                      : Colors.black
                                                          .withOpacity(0.6)),
                                        ),
                                        title: Text(
                                          themeProvider.getThemeModeName(mode),
                                          style: AppTextStyles.body1.copyWith(
                                            color:
                                                isSelected
                                                    ? (isDark
                                                        ? Colors.white
                                                        : Colors.blue)
                                                    : (isDark
                                                        ? AppDarkColors
                                                            .textPrimary
                                                        : Colors.black
                                                            .withOpacity(0.85)),
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                        trailing:
                                            isSelected
                                                ? Icon(
                                                  Icons.check_circle,
                                                  color:
                                                      isDark
                                                          ? Colors.white
                                                          : Colors.blue,
                                                )
                                                : null,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          Navigator.pop(context, mode);
                                        },
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                      if (selected != null) {
                        themeProvider.setThemeMode(selected);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                themeProvider.getThemeModeName(
                                  themeProvider.themeMode,
                                ),
                                style: AppTextStyles.body2.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    bool isDark,
    double screenHeight,
    double screenWidth,
  ) {
    final cardHeight = screenHeight * 0.1; // 10% of screen height

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: cardHeight.clamp(70.0, 100.0), // Min 70, Max 100
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              _notificationsEnabled
                  ? isDark
                      ? [
                        AppDarkColors.primary.withOpacity(0.8),
                        AppDarkColors.secondary.withOpacity(0.8),
                      ]
                      : [const Color(0xFF4CC9F0), const Color(0xFF4895EF)]
                  : [
                    Colors.grey.withOpacity(0.3),
                    Colors.grey.withOpacity(0.2),
                  ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08),
            blurRadius: isDark ? 8 : 12,
            offset: isDark ? const Offset(0, 3) : const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        _notificationsEnabled ? 0.1 : 0.05,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow:
                          isDark || !_notificationsEnabled
                              ? []
                              : [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                    ),
                    child: Icon(
                      Icons.notifications_rounded,
                      color:
                          _notificationsEnabled
                              ? Colors.white
                              : Colors.grey.shade600,
                      size: screenWidth * 0.06, // Responsive icon size
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Push Notifications',
                            style: AppTextStyles.title3.copyWith(
                              color:
                                  _notificationsEnabled
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Enable to receive updates',
                            style: AppTextStyles.caption.copyWith(
                              color:
                                  _notificationsEnabled
                                      ? Colors.white.withOpacity(0.8)
                                      : (isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 1,
              child: Transform.scale(
                scale:
                    screenWidth < 350
                        ? 0.8
                        : 1.0, // Scale down on very small screens
                child: CupertinoSwitch(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    _toggleNotifications(value);
                  },
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyWordCard(
    BuildContext context,
    bool isDark,
    double screenWidth,
  ) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;
    final titleColor =
        isDark ? AppDarkColors.textPrimary : Colors.black.withOpacity(0.85);
    final subtitleColor =
        isDark ? Colors.white70 : Colors.black.withOpacity(0.65);
    final disabled = !_notificationsEnabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: disabled ? 0.5 : 1.0,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppDarkColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.25)
                      : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: accent,
                    size: screenWidth * 0.06,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Word Reminder',
                        style: AppTextStyles.title3.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Receive the Word of the Day with meaning and details.',
                        style: AppTextStyles.caption.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _dailyWordEnabled && _notificationsEnabled,
                  onChanged:
                      (!disabled && !_isUpdatingDailyWord)
                          ? (value) => _onDailyWordToggle(value)
                          : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.access_time, color: accent, size: 18),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed:
                      (!disabled && _dailyWordEnabled && !_isUpdatingDailyWord)
                          ? _pickDailyWordTime
                          : null,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: Text(
                    _dailyWordTime.format(context),
                    style: AppTextStyles.button.copyWith(
                      color:
                          (!disabled && _dailyWordEnabled)
                              ? accent
                              : subtitleColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Weekdays only',
                  style: AppTextStyles.caption.copyWith(
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _dailyWordWeekdaysOnly,
                  onChanged:
                      (!disabled && _dailyWordEnabled && !_isUpdatingDailyWord)
                          ? (value) => _onDailyWordWeekdaysToggle(value)
                          : null,
                ),
              ],
            ),
            if (_isUpdatingDailyWord)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Updating preferences...',
                      style: AppTextStyles.caption.copyWith(
                        color: subtitleColor,
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

  Widget _buildLegalRow(bool isDark, double screenHeight, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: _buildLegalCard(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                onTap: _navigateToPrivacyPolicy,
                isDark: isDark,
                screenHeight: screenHeight,
                screenWidth: screenWidth,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: _buildLegalCard(
                icon: Icons.article_outlined,
                title: 'Terms of Service',
                onTap: _navigateToTermsOfService,
                isDark: isDark,
                screenHeight: screenHeight,
                screenWidth: screenWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    required double screenHeight,
    required double screenWidth,
  }) {
    final cardHeight = screenHeight * 0.1; // 10% of screen height

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: cardHeight.clamp(70.0, 100.0), // Min 70, Max 100
        decoration: BoxDecoration(
          color:
              isDark
                  ? AppDarkColors.surface.withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark
                    ? AppDarkColors.border.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppDarkColors.primary.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow:
                      isDark
                          ? []
                          : [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                ),
                child: Icon(
                  icon,
                  color: isDark ? AppDarkColors.primary : AppColors.primary,
                  size: screenWidth * 0.06, // Responsive icon size
                ),
              ),
              SizedBox(height: screenHeight * 0.008),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: AppTextStyles.body3.copyWith(
                      color:
                          isDark
                              ? AppDarkColors.textPrimary
                              : Colors.black.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: screenWidth < 350 ? 12 : 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackButton(
    bool isDark,
    double screenHeight,
    double screenWidth,
  ) {
    final buttonHeight = screenHeight * 0.065; // 6.5% of screen height

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      child: AnimatedBuilder(
        animation: _feedbackButtonScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _feedbackButtonScale.value,
            child: GestureDetector(
              onTapDown: (_) => _feedbackButtonController.forward(),
              onTapUp: (_) => _feedbackButtonController.reverse(),
              onTapCancel: () => _feedbackButtonController.reverse(),
              onTap: () {
                HapticFeedback.lightImpact();
                _showFeedbackDialog();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: buttonHeight.clamp(45.0, 65.0), // Min 45, Max 65
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isDark
                            ? [AppDarkColors.primary, AppDarkColors.secondary]
                            : [
                              const Color(0xFF4361EE),
                              const Color(0xFF7209B7),
                            ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? AppDarkColors.primary.withOpacity(0.3)
                              : const Color(0xFF4361EE).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Geri Bildirim Gönder',
                      style: AppTextStyles.button.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth < 350 ? 14 : 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoutButton(
    bool isDark,
    double screenHeight,
    double screenWidth,
  ) {
    final buttonHeight = screenHeight * 0.06;

    Future<void> handleLogout() async {
      HapticFeedback.lightImpact();
      final sessionService = locator<SessionService>();
      await sessionService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight.clamp(44.0, 60.0),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color:
                  isDark
                      ? AppDarkColors.textSecondary
                      : Colors.black.withOpacity(0.2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor:
                isDark
                    ? AppDarkColors.surface
                    : Colors.white,
          ),
          onPressed: handleLogout,
          icon: Icon(
            Icons.logout_rounded,
            color:
                isDark
                    ? AppDarkColors.textPrimary
                    : Colors.black.withOpacity(0.7),
          ),
          label: Text(
            'Oturumu Kapat',
            style: AppTextStyles.button.copyWith(
              color:
                  isDark
                      ? AppDarkColors.textPrimary
                      : Colors.black.withOpacity(0.85),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(
    bool isDark,
    double screenHeight,
    double screenWidth,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      child: TextButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showDeleteConfirmation(context);
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.red.withOpacity(0.5),
              width: 1,
            ),
          ),
          backgroundColor: Colors.red.withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Hesabımı Sil',
              style: AppTextStyles.body1.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext parentContext) {
    final confirmationController = TextEditingController();
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;

    // Capture Root Navigator for explicit dialog dismissal
    final rootNav = Navigator.of(parentContext, rootNavigator: true);

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
        title: Text(
          'Hesabı Sil?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bu işlem geri alınamaz. Tüm verileriniz (ilerleme, kelimeler, istatistikler) kalıcı olarak silinecektir.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmationController,
              decoration: InputDecoration(
                labelText: "Onaylamak için kutuya 'SIL' yazın",
                labelStyle: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'İptal',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // 1. Validation
              if (confirmationController.text.trim().toUpperCase() != 'SIL') {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text("Lütfen doğrulamak için 'SIL' yazın"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // 2. Close the confirmation dialog
              Navigator.of(dialogContext).pop();

              // 3. Show loading dialog using PARENT context
              showDialog(
                context: parentContext,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // 4. Try to delete account
                await locator<UserService>().deleteUserAccount();

                // Happy Path: Success
                if (parentContext.mounted) {
                  // Explicitly pop the loading dialog using root navigator
                  try {
                    rootNav.pop();
                  } catch (_) {}
                  
                  Navigator.of(parentContext).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                // Error Handling
                final msg = e.toString();
                
                // Check for Security/Re-login Error
                if (msg.contains('Güvenlik gereği') || msg.contains('requires-recent-login')) {
                  if (parentContext.mounted) {
                    // Explicitly pop the loading dialog using root navigator
                    try {
                      rootNav.pop();
                    } catch (_) {}
                    
                    // Show warning
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Güvenlik gereği tekrar giriş yapmalısınız. Yönlendiriliyorsunuz...'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );

                    // Allow user to read message briefly
                    await Future.delayed(const Duration(seconds: 2));

                    // Aggressive Logout Strategy with Timeout
                    try {
                      await locator<SessionService>().signOut().timeout(
                        const Duration(seconds: 2),
                        onTimeout: () {
                          // Just return null to proceed
                        },
                      );
                    } catch (_) {
                      // Ignore all errors (network, timeout, etc.)
                    }

                    // Force Navigation to Login
                    if (parentContext.mounted) {
                      Navigator.of(parentContext).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  }
                } else {
                  // Other Errors (e.g. Network)
                  if (parentContext.mounted) {
                    // Explicitly pop the loading dialog using root navigator
                    try {
                      rootNav.pop();
                    } catch (_) {}
                    
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text('Hata: ${msg.replaceAll("Exception: ", "")}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('SİL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  final ScaffoldMessengerState parentMessenger;

  const _FeedbackDialog({required this.parentMessenger});

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    // Use the parent messenger passed from the Settings screen
    // This ensures SnackBar shows on the main screen, not the dialog
    final messenger = widget.parentMessenger;
    final navigator = Navigator.of(context);
    final feedbackText = _feedbackController.text;

    // Unfocus keyboard before async operations
    FocusScope.of(context).unfocus();

    if (!mounted) return;

    // Show loading indicator
    setState(() {
      _isSubmitting = true;
    });

    try {
      final session = locator<SessionService>();
      final feedbackService = FeedbackService();

      // Perform async Firestore write
      final result = await feedbackService.submitFeedback(
        message: feedbackText,
        uid: session.currentUser?.uid ?? session.offlineUser?.uid,
        email: session.currentUser?.email,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        // Success flow (order is critical):
        // 1. Clear the text field for next time
        _feedbackController.clear();
        
        // 2. Close the dialog FIRST using captured navigator
        navigator.pop();
        
        // 3. THEN show success message using captured messenger
        // This works because messenger was captured before dialog context was destroyed
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Geri bildiriminiz gönderildi. Görüşleriniz dikkate alınacaktır.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Error - keep dialog open so user can retry
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Bir hata oluştu.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Keep dialog open on error so user can retry
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Gönderim sırasında bir hata oluştu. Lütfen tekrar dene.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Hide loading indicator
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppDarkColors.surface : const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
              blurRadius: isDark ? 10 : 12,
              offset: Offset(0, isDark ? 4 : 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Geri Bildirim Gönder',
              style: AppTextStyles.title2.copyWith(
                color:
                    isDark
                        ? AppDarkColors.textPrimary
                        : Colors.black.withOpacity(0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Düşüncelerini paylaş...',
                hintStyle: AppTextStyles.body2.copyWith(
                  color:
                      isDark
                          ? AppDarkColors.textSecondary
                          : Colors.black.withOpacity(0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color:
                        isDark
                            ? AppDarkColors.border
                            : Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppDarkColors.primary : AppColors.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor:
                    isDark
                        ? AppDarkColors.background.withOpacity(0.5)
                        : Colors.white.withOpacity(0.8),
              ),
              style: AppTextStyles.body2.copyWith(
                color:
                    isDark
                        ? AppDarkColors.textPrimary
                        : Colors.black.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'İptal',
                      style: AppTextStyles.button.copyWith(
                        color:
                            isDark
                                ? AppDarkColors.textSecondary
                                : Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : () {
                              HapticFeedback.lightImpact();
                              _submitFeedback();
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? AppDarkColors.primary : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              'Gönder',
                              style: AppTextStyles.button.copyWith(
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const _LegalDocumentScreen({required this.title, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppDarkColors.background : const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color:
                isDark
                    ? AppDarkColors.textPrimary
                    : Colors.black.withOpacity(0.85),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          title,
          style: AppTextStyles.title1.copyWith(
            color:
                isDark
                    ? AppDarkColors.textPrimary
                    : Colors.black.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppDarkColors.primary : AppColors.primary,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading document',
                style: AppTextStyles.body1.copyWith(
                  color:
                      isDark
                          ? AppDarkColors.textSecondary
                          : Colors.black.withOpacity(0.6),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              snapshot.data ?? 'Document not found',
              style: AppTextStyles.body2.copyWith(
                color:
                    isDark
                        ? AppDarkColors.textPrimary
                        : Colors.black.withOpacity(0.85),
                height: 1.6,
              ),
            ),
          );
        },
      ),
    );
  }
}
