import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lexiflow/services/word_loader.dart';
import 'package:lexiflow/screens/quiz_type_select_screen.dart';
import 'package:lexiflow/screens/category_quiz_screen.dart';
import 'package:lexiflow/services/category_progress_service.dart';
import 'package:lexiflow/di/locator.dart';
import 'package:lexiflow/services/session_service.dart';
import 'package:lexiflow/services/ad_service.dart';
import 'package:lexiflow/utils/feature_flags.dart';

class QuizCenterScreen extends StatefulWidget {
  const QuizCenterScreen({super.key});

  @override
  State<QuizCenterScreen> createState() => _QuizCenterScreenState();
}

class _QuizCenterScreenState extends State<QuizCenterScreen> {
  Map<String, int> categoryWordCounts = {};
  bool isLoading = true;

  // Category data with Turkish names, emojis, and colors
  static const Map<String, Map<String, dynamic>> categories = {
    'biology': {
      'name': 'Biyoloji',
      'icon': '🧬',
      'color': Color(0xFF4CAF50), // Green
      'lightColor': Color(0xFFE8F5E8),
    },
    'technology': {
      'name': 'Teknoloji',
      'icon': '⚙️',
      'color': Color(0xFF607D8B), // Blue Grey
      'lightColor': Color(0xFFECEFF1),
    },
    'history': {
      'name': 'Tarih',
      'icon': '📜',
      'color': Color(0xFF8D6E63), // Brown
      'lightColor': Color(0xFFF3E5AB),
    },
    'geography': {
      'name': 'Coğrafya',
      'icon': '🌍',
      'color': Color(0xFF00BCD4), // Cyan
      'lightColor': Color(0xFFE0F7FA),
    },
    'psychology': {
      'name': 'Psikoloji',
      'icon': '🧠',
      'color': Color(0xFF9C27B0), // Purple
      'lightColor': Color(0xFFF3E5F5),
    },
    'business': {
      'name': 'İş Dünyası',
      'icon': '💼',
      'color': Color(0xFF795548), // Brown
      'lightColor': Color(0xFFEFEBE9),
    },
    'communication': {
      'name': 'İletişim',
      'icon': '💬',
      'color': Color(0xFF2196F3), // Blue
      'lightColor': Color(0xFFE3F2FD),
    },
    'everyday_english': {
      'name': 'Günlük İngilizce',
      'icon': '🗣️',
      'color': Color(0xFFFF9800), // Orange
      'lightColor': Color(0xFFFFF3E0),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadCategoryWordCounts();
  }

  // Kategoriye göre renk belirleyen yardımcı fonksiyon
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'biology':
        return Colors.greenAccent;
      case 'history':
        return Colors.brown;
      case 'technology':
        return Colors.blueAccent;
      case 'psychology':
        return Colors.purpleAccent;
      case 'business':
        return Colors.orangeAccent;
      case 'communication':
        return Colors.tealAccent;
      case 'everyday_english':
        return Colors.amberAccent;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadCategoryWordCounts() async {
    final Map<String, int> counts = {};

    for (String category in categories.keys) {
      counts[category] = await WordLoader.getCategoryWordCount(category);
    }

    if (mounted) {
      setState(() {
        categoryWordCounts = counts;
        isLoading = false;
      });
    }
  }

  void _startCategoryQuiz(String categoryKey) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizTypeSelectScreen(category: categoryKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use contrast strategy: light grey background in light mode for card separation
    final backgroundColor = isDark
        ? colorScheme.surface
        : const Color(0xFFF5F7FA); // Very light grey for light mode

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Title
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Kelime Pratikleri',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // General Quiz Card
              _buildGeneralQuizCard(colorScheme, textTheme),
              const SizedBox(height: 32),

              // Categories Section Title
              Text(
                'Kategorilere Göre Quizler',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Categories Grid
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _buildCategoriesGrid(colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralQuizCard(ColorScheme colorScheme, TextTheme textTheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      // Pure white in light mode for contrast
      color: isDark ? null : Colors.white,
      elevation: 6,
      shadowColor: colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: () async {
          final adService = locator<AdService>();
          final proceed =
              FeatureFlags.adsEnabled
                  ? await adService.enforceRewardedGateIfNeeded(
                    context: context,
                    grantXpOnReward: true,
                  )
                  : true;
          if (!proceed) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CategoryQuizScreen(
                    category: 'common_1k',
                    categoryName: '1K Kelime',
                    categoryIcon: '🎯',
                    categoryColor: Colors.deepOrange,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer,
                colorScheme.surfaceTint.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.book_solid,
                  size: 40,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'İngilizcede En Fazla Kullanılan 1000 Kelime',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Genel İngilizce kelimelerle rastgele quiz oluştur.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(ColorScheme colorScheme, TextTheme textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid columns
        int crossAxisCount = 2;
        if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 24,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final categoryKey = categories.keys.elementAt(index);
              final categoryData = categories[categoryKey]!;
              final wordCount = categoryWordCounts[categoryKey] ?? 0;

              return _buildCategoryCard(
                context,
                categoryKey,
                categoryData,
                wordCount,
                colorScheme,
                textTheme,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String categoryKey,
    Map<String, dynamic> categoryData,
    int wordCount,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final categoryColor = categoryData['color'] as Color;
    final session = locator<SessionService>();
    final userId = session.currentUser?.uid;
    final cps = locator<CategoryProgressService>();
    final bool isDark = colorScheme.brightness == Brightness.dark;

    return SizedBox(
      height: 180,
      child: Card(
        // Pure white background in light mode for contrast against grey background
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        clipBehavior: Clip.hardEdge,
        elevation: 4, // Keep elevation for shadow effect
        shadowColor: colorScheme.shadow.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // Remove border in light mode - rely on shadow and background contrast
          side: isDark
              ? BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.2),
                width: 1,
              )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () async {
            final categoryData = categories[categoryKey]!;
            final adService = locator<AdService>();
            final proceed =
                FeatureFlags.adsEnabled
                    ? await adService.enforceRewardedGateIfNeeded(
                      context: context,
                      grantXpOnReward: true,
                    )
                    : true;
            if (!proceed) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => CategoryQuizScreen(
                      category: categoryKey,
                      categoryName: categoryData['name']!,
                      categoryIcon: categoryData['icon']!,
                      categoryColor: categoryData['color'],
                    ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // mevcut emoji tabanlı ikon kullanımı
                      Text(
                        categoryData['icon']!,
                        style: TextStyle(
                          fontSize: 40,
                          // Icon color adapts to theme
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        categoryData['name']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          // Text color adapts to theme
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$wordCount kelime',
                        style: TextStyle(
                          fontSize: 12,
                          // Subtext color adapts to theme
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (userId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: StreamBuilder<double>(
                    stream: cps.watchProgressPercent(userId, categoryKey),
                    builder: (context, snapshot) {
                      final percent = snapshot.data ?? 0.0;
                      final ownerId = (userId ?? 'guest').trim();
                      final heroOwner = ownerId.isEmpty ? 'guest' : ownerId;
                      final normalizedCategory = categoryKey
                          .trim()
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), '_');
                      final heroCategory =
                          normalizedCategory.isEmpty
                              ? 'unknown'
                              : normalizedCategory;
                      final progressHeroTag =
                          'progress_${heroOwner}_$heroCategory';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Animated percentage label (overflow-safe)
                          AnimatedOpacity(
                            opacity: percent > 0 ? 1 : 0.7,
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              percent == 0
                                  ? 'Henüz öğrenilmedi'
                                  : '${percent.toStringAsFixed(1)}% öğrenildi',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                // Percentage label color adapts to theme and state
                                color:
                                    percent == 0
                                        ? (isDark
                                            ? Colors.grey.shade400
                                            : colorScheme.onSurface.withOpacity(
                                              0.6,
                                            ))
                                        : (isDark
                                            ? Colors.white70
                                            : colorScheme.onSurface.withOpacity(
                                              0.8,
                                            )),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Animated progress bar (Hero) with unique tag to avoid collisions
                          Hero(
                            tag: progressHeroTag,
                            flightShuttleBuilder: (
                              context,
                              animation,
                              direction,
                              fromContext,
                              toContext,
                            ) {
                              return FadeTransition(
                                opacity: animation.drive(
                                  Tween<double>(begin: 0.6, end: 1.0),
                                ),
                                child: toContext.widget,
                              );
                            },
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: percent / 100,
                              ),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 6,
                                    // Progress background adapts to theme
                                    backgroundColor:
                                        isDark
                                            ? Colors.grey.shade800
                                            : colorScheme
                                                .surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getCategoryColor(categoryKey),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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

// Kategori rengine göre premium görünüm sağlayan yardımcı fonksiyon
Color _getCategoryColor(String category) {
  switch (category) {
    case 'biology':
      return Colors.greenAccent;
    case 'technology':
      return Colors.blueAccent;
    case 'history':
      return Colors.brown;
    case 'geography':
      return Colors.lightBlueAccent;
    case 'psychology':
      return Colors.purpleAccent;
    case 'business':
      return Colors.orangeAccent;
    case 'communication':
      return Colors.tealAccent;
    case 'everyday_english':
      return Colors.amberAccent;
    default:
      return Colors.grey;
  }
}
