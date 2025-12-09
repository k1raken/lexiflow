import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../services/achievement_service.dart';
import '../providers/profile_stats_provider.dart';
import '../models/aggregated_profile_stats.dart';
import '../models/achievement.dart';
import '../widgets/level_up_banner.dart';
import '../widgets/sync_indicator.dart';
import '../providers/sync_status_provider.dart';
import 'settings_screen.dart';
import '../utils/design_system.dart';
import '../widgets/expandable_profile_card.dart';
import '../widgets/profile_stat_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<String> _availableAvatars = [
    'assets/icons/bear.svg',
    'assets/icons/boy.svg',
    'assets/icons/gamer.svg',
    'assets/icons/girl.svg',
    'assets/icons/hacker.svg',
    'assets/icons/rabbit.svg',
    'assets/icons/woman.svg',
  ];

  // Level-up detection
  int? _lastKnownLevel;

  // Local state for immediate UI updates
  String? _currentUsername;
  String? _currentAvatar;

  @override
  void initState() {
    super.initState();

    // Delay initialization until widget is fully mounted to prevent disposal races
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final profileStatsProvider = context.read<ProfileStatsProvider>();
          profileStatsProvider.initializeForUser(user.uid);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Consumer2<SessionService, ProfileStatsProvider>(
        builder: (context, sessionService, profileStatsProvider, child) {
          // SessionService henüz başlatılmadıysa loading göster
          if (!sessionService.isInitialized) {
            return _buildInitializingState();
          }

          // FirebaseAuth ile kullanıcı doğrulamasını kontrol et
          final user = FirebaseAuth.instance.currentUser;
          final isGuest = user == null || (user.isAnonymous);
          if (isGuest) {
            return _buildGuestLimitedView(context);
          }

          final userId = sessionService.currentUser?.uid;
          if (userId == null) {
            return _buildAuthLoadingState();
          }

          // Use ProfileStatsProvider for unified stats
          final stats = profileStatsProvider.stats;
          final error = profileStatsProvider.error;

          // Show error state with retry option
          if (error != null) {
            return _buildErrorState(error, () {
              if (mounted) {
                profileStatsProvider.retry();
              }
            });
          }

          if (stats.isLoading) {
            return _buildLoadingState();
          }

          // Get user profile data (avatar, username) from SessionService
          // Initialize local state if null
          _currentUsername ??= sessionService.currentUser?.displayName;
          _currentAvatar ??= sessionService.currentUser?.photoURL;

          final username = _currentUsername ?? 'Kullanıcı';
          final avatar = _currentAvatar ?? 'assets/icons/boy.svg';

          return _buildProfileContent(
            context,
            sessionService,
            stats,
            username,
            avatar,
            userId,
          );
        },
      ),
    );
  }

  /// Misafir/anonim kullanıcılar için sınırlı görünüm
  Widget _buildGuestLimitedView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: colorScheme.primary.withOpacity(0.12),
                child: Icon(
                  Icons.person_outline,
                  color: colorScheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Profilinizi görmek için oturum açın.',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppBorderRadius.medium,
                    ),
                  ),
                  child: const Text('Oturum Aç'),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Profil yükleniyor...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.error.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Veriler Yüklenemedi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'İnternet bağlantınızı kontrol edin ve tekrar deneyin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Yeniden Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitializingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Oturum başlatılıyor...'),
        ],
      ),
    );
  }

  Widget _buildAuthLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Kimlik doğrulanıyor...'),
        ],
      ),
    );
  }

  Widget _buildPermissionErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Erişim İzni Gerekli'),
          const SizedBox(height: 8),
          const Text(
            'Profil verilerinize erişim için giriş yapmanız gerekiyor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Çıkış yap ve tekrar giriş yap
              FirebaseAuth.instance.signOut();
            },
            child: const Text('Tekrar GiriÅŸ Yap'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    SessionService sessionService,
    AggregatedProfileStats stats,
    String username,
    String avatar,
    String? userId,
  ) {
    // Get level data from ProfileStatsProvider
    final profileStatsProvider = context.read<ProfileStatsProvider>();
    final levelData = profileStatsProvider.currentLevelData;

    // Use new level system if available, fallback to old system
    final level = levelData?.level ?? stats.level;
    final totalXP = stats.totalXp;
    final learnedCount = stats.learnedWordsCount;
    final quizzesCompleted = stats.totalQuizzesCompleted;
    final favorites = sessionService.favoritesCount;
    final streak = profileStatsProvider.currentStreak;

    // XP values for the progress bar - use new level system if available
    final currentXP =
        levelData?.xpIntoLevel ?? (stats.totalXp % stats.xpToNextLevel);
    final xpToNext = levelData?.xpNeeded ?? stats.xpToNextLevel;
    final totalXPForNextLevel =
        levelData?.levelEndXp ?? (stats.totalXp + stats.xpToNextLevel);

    // Level-up detection and banner trigger
    if (levelData != null &&
        _lastKnownLevel != null &&
        levelData.level > _lastKnownLevel!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          LevelUpBanner.show(context, levelData.level);
        }
      });
    }
    _lastKnownLevel = levelData?.level ?? level;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top padding removed for fullscreen mode
          const SizedBox(height: AppSpacing.md),
          
          // Header Section (Avatar + Name + Level) - 220-240px
          _buildPixelPerfectHeader(context, username, avatar, level, userId),

          const SizedBox(height: 12),

          // Experience Card - max 130px height
          _buildCompactXPCard(
            context,
            currentXP,
            totalXPForNextLevel,
            xpToNext,
          ),

          const SizedBox(height: 16),

          // Expandable Profile Cards with Achievements
          Consumer<AchievementService>(
            builder: (context, achievementService, child) {
              // Filter achievements by category
              final wordAchievements = achievementService.achievements
                  .where((a) => a.id.contains('learned') || a.id.contains('word'))
                  .toList();
              final streakAchievements = achievementService.achievements
                  .where((a) => a.id.contains('streak'))
                  .toList();
              final quizAchievements = achievementService.achievements
                  .where((a) => a.id.contains('quiz'))
                  .toList();

              // Find next target for each category (or use default)
              final wordTarget = _calculateMilestone(learnedCount, [50, 100, 250, 500, 1000]);
              final streakTarget = _calculateMilestone(streak, [25, 50, 75, 100, 150]);
              final quizTarget = _calculateMilestone(quizzesCompleted, [25, 50, 75, 100, 150]);

              return Column(
                children: [
                  ExpandableProfileCard(
                    title: 'Kelime Başarıları',
                    icon: Icons.school_rounded,
                    currentValue: learnedCount,
                    maxValue: wordTarget,
                    color: Colors.blue,
                    achievements: wordAchievements,
                  ),
                  ExpandableProfileCard(
                    title: 'Seri Başarıları',
                    icon: Icons.local_fire_department_rounded,
                    currentValue: streak,
                    maxValue: streakTarget,
                    color: Colors.orange,
                    achievements: streakAchievements,
                  ),
                  ExpandableProfileCard(
                    title: 'Quiz Başarıları',
                    icon: Icons.quiz_rounded,
                    currentValue: quizzesCompleted,
                    maxValue: quizTarget,
                    color: Colors.purple,
                    achievements: quizAchievements,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20), // Bottom padding
          // Bottom padding for navigation bar (fullscreen mode)
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPixelPerfectHeader(
    BuildContext context,
    String username,
    String avatar,
    int level,
    String? userId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Settings icon in top right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Settings icon
              Padding(
                padding: const EdgeInsets.only(right: 20, top: 10),
                child: IconButton(
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.settings_outlined,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),

          // Avatar with camera icon - 90-100px size
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.7),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child:
                        avatar.isNotEmpty
                            ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgPicture.asset(
                                avatar,
                                fit: BoxFit.contain,
                              ),
                            )
                            : Icon(
                              Icons.person,
                              size: 40,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showAvatarPicker(context, userId ?? ''),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18), // 16-20px spacing as specified
          // Name with edit icon
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                username,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => _showUsernameEditor(context, userId ?? ''),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Level chip with star icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_border_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Level $level',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactXPCard(
    BuildContext context,
    int currentXP,
    int totalXPForNextLevel,
    int xpToNext,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deneyim Puanı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currentXP / $totalXPForNextLevel XP',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: currentXP / totalXPForNextLevel,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.outline.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            'Bir sonraki seviyeye $xpToNext XP kaldı!',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancedStatsGrid(
    BuildContext context,
    int learnedCount,
    int quizzesCompleted,
    int favorites,
    int totalXP,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          _buildStatCard(
            context,
            icon: Icons.school_rounded,
            value: learnedCount.toString(),
            label: 'Öğrenilen Kelime',
            color: Colors.green,
          ),
          _buildStatCard(
            context,
            icon: Icons.quiz_rounded,
            value: quizzesCompleted.toString(),
            label: 'Tamamlanan Quiz',
            color: Colors.blue,
          ),
          _buildStatCard(
            context,
            icon: Icons.favorite_rounded,
            value: favorites.toString(),
            label: 'Favori Kelime',
            color: Colors.pink,
          ),
          _buildStatCard(
            context,
            icon: Icons.stars_rounded,
            value: totalXP.toString(),
            label: 'Toplam XP',
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, int streak) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Günlük Seri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$streak gün üst üste!',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  streak.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Username editor dialog method
  void _showUsernameEditor(BuildContext context, String userId) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              const Text(
                'Kullanıcı Adını Düzenle',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Input Alanı
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Yeni kullanıcı adı',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Butonlar
              Row(
                children: [
                  // İptal Butonu
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'İptal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Kaydet Butonu
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          _updateUsername(
                            context,
                            userId,
                            controller.text.trim(),
                            dialogContext: context,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvatarPicker(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Avatar Seç',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _availableAvatars.length,
                    itemBuilder: (context, index) {
                      final avatarPath = _availableAvatars[index];
                      return GestureDetector(
                        onTap:
                            () => _updateAvatar(
                              context,
                              userId,
                              avatarPath,
                              dialogContext: context,
                            ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.3),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: SvgPicture.asset(
                                  avatarPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
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

  void _showUsernameEditDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Kullanıcı Adını Düzenle',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni kullanıcı adınızı girin',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer.withOpacity(0.1),
                      colorScheme.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'örn: kullanici123',
                    hintStyle: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.35),
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary.withOpacity(0.8),
                              colorScheme.primary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.alternate_email_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    counterText: '',
                  ),
                  maxLength: 20,
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Maksimum 20 karakter kullanabilirsiniz',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu özellik şu anda kullanılamıyor',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                // Username update feature is currently disabled
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Bu özellik şu anda kullanılamıyor'),
                        ),
                      ],
                    ),
                    backgroundColor: colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text(
                'Kaydet',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateAvatar(
    BuildContext context,
    String userId,
    String avatarPath, {
    required BuildContext dialogContext,
  }) async {
    // ReferanslarÄ± tanÄ±mla
    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId);

    try {
      // Batch write başlat
      final batch = FirebaseFirestore.instance.batch();

      // 1. users koleksiyonunu güncelle
      batch.update(userDocRef, {'photoURL': avatarPath});

      // 3. FirebaseAuth kullanıcısını güncelle (photoURL alanını avatar path'i olarak kullanıyoruz)
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(avatarPath);

      // Batch iÅŸlemlerini uygula
      await batch.commit();

      // Servisleri ve local state'i yenile
      await FirebaseAuth.instance.currentUser?.reload();
      context.read<SessionService>().refreshUser();

      if (mounted) {
        setState(() {
          _currentAvatar = avatarPath; // Anında UI güncellemesi
        });
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.greenAccent.shade400,
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Avatar başarıyla güncellendi!',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.redAccent,
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Avatar güncellenirken hata oluştu: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _updateUsername(
    BuildContext context,
    String userId,
    String newUsername, {
    required BuildContext dialogContext,
  }) async {
    final trimmedUsername = newUsername.trim();

    if (trimmedUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.redAccent,
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kullanıcı adı boş olamaz!',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    var loaderVisible = false;

    void hideLoader() {
      if (loaderVisible) {
        rootNavigator.pop();
        loaderVisible = false;
      }
    }

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      builder:
          (_) => Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xF21F2937),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Updating username...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
    );
    loaderVisible = true;

    try {
      final query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: trimmedUsername)
              .limit(5)
              .get();

      final otherUsersWithSameUsername =
          query.docs.where((doc) => doc.id != userId).toList();

      if (otherUsersWithSameUsername.isNotEmpty) {
        hideLoader();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.redAccent,
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bu kullanıcı adı zaten alınmış!',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      final userDataRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      // Update user data
      await userDataRef.update({
        'username': trimmedUsername,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update Auth profile
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        trimmedUsername,
      );
      
      // OPTIMIZATION: Close dialog and update UI *before* reloading auth
      // OPTIMIZATION: Close dialog and update UI *before* reloading auth
      
      // 1. Explicitly pop the Loader (Root Navigator)
      // We use the root navigator explicitly to close the loader we opened with useRootNavigator: true
      Navigator.of(context, rootNavigator: true).pop();
      loaderVisible = false; // Update flag so finally block doesn't try to pop again

      if (mounted) {
        setState(() {
          _currentUsername = trimmedUsername;
        });
        
        // 2. Explicitly pop the Name Change Dialog
        // TEST: Commented out to see if dialog remains open
        // Navigator.of(context).pop();
        
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.greenAccent.shade400,
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kullanıcı adı başarıyla güncellendi!',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Background refresh
      Future.microtask(() async {
        try {
          await FirebaseAuth.instance.currentUser?.reload();
          if (context.mounted) {
            context.read<SessionService>().refreshUser();
          }
        } catch (e) {

        }
      });
    } catch (e) {
      hideLoader();
      if (mounted) {
        Navigator.pop(dialogContext);
        // Use the captured messenger reference if still valid, otherwise try to get a new one safely
        try {
          messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.redAccent,
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kullanıcı adı güncellenirken hata oluştu: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        } catch (_) {} // Ignore if scaffold is gone
      }
    } finally {
      hideLoader();
    }
  }

  Widget _buildAchievementsSection(
    BuildContext context,
    AggregatedProfileStats stats,
  ) {
    return Consumer<AchievementService>(
      builder: (context, achievementService, child) {
        if (!achievementService.isInitialized) {
          // Initialize achievement service if not already done
          WidgetsBinding.instance.addPostFrameCallback((_) {
            achievementService.initialize();
          });

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (index) => _buildLoadingAchievement(context),
              ),
            ),
          );
        }

        final achievements = achievementService.achievements;
        if (achievements.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                achievements
                    .map(
                      (achievement) =>
                          _buildExpandableAchievementBadge(context, achievement, stats),
                    )
                    .toList(),
          ),
        );
      },
    );
  }

  Widget _buildLoadingAchievement(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: 10,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableAchievementBadge(
    BuildContext context,
    Achievement achievement,
    AggregatedProfileStats stats,
  ) {
    Color getAchievementColor() {
      switch (achievement.id) {
        case 'learned_words_100':
          return Colors.blue;
        case 'streak_10':
          return Colors.orange;
        case 'quizzes_25':
          return Colors.purple;
        default:
          return Theme.of(context).colorScheme.primary;
      }
    }

    // Determine achievement category and filter
    String getCategoryTitle() {
      switch (achievement.id) {
        case 'learned_words_100':
          return 'Kelime Başarıları';
        case 'streak_10':
          return 'Seri Başarıları';
        case 'quizzes_25':
          return 'Quiz Başarıları';
        default:
          return 'Başarılar';
      }
    }

    IconData getCategoryIcon() {
      switch (achievement.id) {
        case 'learned_words_100':
          return Icons.school_rounded;
        case 'streak_10':
          return Icons.local_fire_department_rounded;
        case 'quizzes_25':
          return Icons.quiz_rounded;
        default:
          return Icons.star;
      }
    }

    List<Achievement> getFilteredAchievements() {
      final achievementService = context.read<AchievementService>();
      switch (achievement.id) {
        case 'learned_words_100':
          return achievementService.achievements
              .where((a) => a.id.contains('learned') || a.id.contains('word'))
              .toList();
        case 'streak_10':
          return achievementService.achievements
              .where((a) => a.id.contains('streak'))
              .toList();
        case 'quizzes_25':
          return achievementService.achievements
              .where((a) => a.id.contains('quiz'))
              .toList();
        default:
          return [achievement];
      }
    }

    int getCurrentValue() {
      switch (achievement.id) {
        case 'learned_words_100':
          return stats.learnedWordsCount;
        case 'streak_10':
          return context.read<ProfileStatsProvider>().currentStreak;
        case 'quizzes_25':
          return stats.totalQuizzesCompleted;
        default:
          return achievement.progress;
      }
    }

    final color = getAchievementColor();
    final isUnlocked = achievement.unlocked;
    final progress = achievement.progressPercentage;
    final categoryTitle = getCategoryTitle();
    final categoryIcon = getCategoryIcon();
    final filteredAchievements = getFilteredAchievements();
    final currentValue = getCurrentValue();

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Show expandable dialog with all achievements in this category
          final achievementService = context.read<AchievementService>();
          _showCategoryAchievementsDialog(
            context,
            categoryTitle,
            categoryIcon,
            color,
            filteredAchievements,
            currentValue,
            achievement.target,
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(isUnlocked ? 1.0 : 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with grayscale/colored effect
              ColorFiltered(
                colorFilter:
                    isUnlocked
                        ? const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        )
                        : const ColorFilter.matrix([
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                child: Icon(
                  achievement.icon,
                  color: color.withOpacity(isUnlocked ? 1.0 : 0.4),
                  size: 28,
                ),
              ),
              const SizedBox(height: 6),

              // Title
              Text(
                achievement.title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Progress text - Use correct data source
              Text(
                '${currentValue}/${achievement.target}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              // Progress bar
              Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.outline.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color.withOpacity(isUnlocked ? 1.0 : 0.7),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Test button for achievement popup (debug mode only)
  Widget _buildTestAchievementButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final achievementService = Provider.of<AchievementService>(
              context,
              listen: false,
            );
            await achievementService.testAchievementPopup(context);
          },
          icon: const Icon(Icons.bug_report, size: 16),
          label: const Text('Test Achievement Popup'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.withOpacity(0.8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  /// Calculate the next milestone for progress cards
  int _calculateMilestone(int currentValue, List<int> milestones) {
    for (final milestone in milestones) {
      if (currentValue < milestone) {
        return milestone;
      }
    }
    // If currentValue exceeds all milestones, return the last one
    return milestones.isNotEmpty ? milestones.last : 100;
  }

  /// Helper method to find the next achievement target
  int? _findNextTarget(List<Achievement> achievements, int currentValue) {
    if (achievements.isEmpty) return null;
    
    // Find the smallest target that is greater than currentValue
    final nextAchievement = achievements
        .where((a) => a.target > currentValue)
        .fold<Achievement?>(null, (prev, curr) {
          if (prev == null) return curr;
          return curr.target < prev.target ? curr : prev;
        });
    
    return nextAchievement?.target;
  }

  /// Show dialog with all achievements in a category
  void _showCategoryAchievementsDialog(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Achievement> achievements,
    int currentValue,
    int targetValue,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$currentValue / $targetValue',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Achievements List
              Flexible(
                child: achievements.isEmpty 
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'Henüz bu kategoride başarım yok.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: achievements.length,
                      itemBuilder: (context, index) {
                        final achievement = achievements[index];
                        final unlocked = achievement.unlocked;
                        final progress = achievement.progress;
                        final target = achievement.target;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: unlocked
                                ? color.withOpacity(0.1)
                                : (isDark ? Colors.grey[800] : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: unlocked
                                ? Border.all(color: color.withOpacity(0.3), width: 2)
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: unlocked
                                      ? color
                                      : (isDark ? Colors.grey[700] : Colors.grey[300]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  achievement.icon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      achievement.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: unlocked
                                            ? (isDark ? Colors.white : Colors.black87)
                                            : (isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600]),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      achievement.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            isDark ? Colors.grey[500] : Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (!unlocked) ...[
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0,
                                          minHeight: 5,
                                          backgroundColor: isDark
                                              ? Colors.grey[700]
                                              : Colors.grey[300],
                                          valueColor: AlwaysStoppedAnimation<Color>(color),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$progress / $target',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? Colors.grey[500]
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (unlocked)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
