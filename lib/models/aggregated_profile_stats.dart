/// Unified profile stats combining canonical sources:
/// - XP & Quizzes from leaderboard_stats/{uid}
/// - Learned words from users/{uid}/stats/summary
import '../services/level_service.dart';

class AggregatedProfileStats {
  final int totalXp;
  final int totalQuizzesCompleted;
  final int learnedWordsCount;
  final int level; // standardized level field
  final int currentStreak;
  final int longestStreak;

  // Weekly stats (optional)
  final int? weeklyXp;
  final int? weeklyQuizzes;

  // Metadata
  final DateTime lastUpdated;
  final bool isLoading;

  const AggregatedProfileStats({
    required this.totalXp,
    required this.totalQuizzesCompleted,
    required this.learnedWordsCount,
    required this.level, // standardized level field
    required this.currentStreak,
    required this.longestStreak,
    this.weeklyXp,
    this.weeklyQuizzes,
    required this.lastUpdated,
    this.isLoading = false,
  });

  /// Loading state constructor
  AggregatedProfileStats.loading()
    : totalXp = 0,
      totalQuizzesCompleted = 0,
      learnedWordsCount = 0,
      level = 1, // standardized level field
      currentStreak = 0,
      longestStreak = 0,
      weeklyXp = null,
      weeklyQuizzes = null,
      lastUpdated = DateTime.fromMillisecondsSinceEpoch(0),
      isLoading = true;

  /// Create from leaderboard stats and user summary
  factory AggregatedProfileStats.fromSources({
    required Map<String, dynamic>? leaderboardData,
    required Map<String, dynamic>? summaryData,
    int? liveLearnedWordsCount, // Live count from subcollection (priority)
  }) {
    final now = DateTime.now();

    // Extract from summaryData (canonical) or leaderboard_stats (fallback)
    final totalXp = summaryData?['totalXp'] ?? leaderboardData?['totalXp'] ?? 0;
    // Prioritize summaryData for quizzesCompleted
    final totalQuizzesCompleted = summaryData?['quizzesCompleted'] ??
                                  leaderboardData?['quizzesCompleted'] ?? 
                                  leaderboardData?['totalQuizzesCompleted'] ?? 0;

    // Prioritize level from summaryData, otherwise calculate from XP
    final level = summaryData?['level'] ?? 
                  LevelService.computeLevelData(totalXp is int ? totalXp : 0).level;

    // CRITICAL FIX: Prioritize summaryData for streak (users/{uid}/stats/summary)
    // This is the canonical source for streak data
    final currentStreak = summaryData?['currentStreak'] ?? 
                          leaderboardData?['currentStreak'] ?? 0;
    final longestStreak = summaryData?['longestStreak'] ?? 
                          leaderboardData?['longestStreak'] ?? 0;
    
    final weeklyXp = leaderboardData?['weeklyXp'];
    final weeklyQuizzes = leaderboardData?['weeklyQuizzes'];

    // Prioritize live learned words count from subcollection
    int learnedWordsCount;
    if (liveLearnedWordsCount != null) {
      // Use live count from subcollection (canonical source)
      learnedWordsCount = liveLearnedWordsCount;
    } else {
      // Fallback to cached count from summary data if live stream unavailable
      learnedWordsCount = summaryData?['learnedWordsCount'] ?? 0;
    }

    return AggregatedProfileStats(
      totalXp: totalXp is int ? totalXp : 0,
      totalQuizzesCompleted:
          totalQuizzesCompleted is int ? totalQuizzesCompleted : 0,
      learnedWordsCount: learnedWordsCount,
      level: level, // using standardized level field
      currentStreak: currentStreak is int ? currentStreak : 0,
      longestStreak: longestStreak is int ? longestStreak : 0,
      weeklyXp: weeklyXp is int ? weeklyXp : null,
      weeklyQuizzes: weeklyQuizzes is int ? weeklyQuizzes : null,
      lastUpdated: now,
    );
  }

  /// Calculate XP needed for next level using LevelService
  int get xpToNextLevel {
    final levelData = LevelService.computeLevelData(totalXp);
    return levelData.xpNeeded - levelData.xpIntoLevel;
  }

  /// Calculate XP progress (0.0 to 1.0) using LevelService
  double get levelProgress {
    final levelData = LevelService.computeLevelData(totalXp);
    return levelData.progressPct;
  }

  /// XP remaining to next level using LevelService
  int get xpToNext {
    final levelData = LevelService.computeLevelData(totalXp);
    return levelData.xpNeeded - levelData.xpIntoLevel;
  }

  @override
  String toString() {
    return 'AggregatedProfileStats(totalXp: $totalXp, quizzes: $totalQuizzesCompleted, '
        'learned: $learnedWordsCount, level: $level, loading: $isLoading)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AggregatedProfileStats &&
        other.totalXp == totalXp &&
        other.totalQuizzesCompleted == totalQuizzesCompleted &&
        other.learnedWordsCount == learnedWordsCount &&
        other.level == level &&
        other.currentStreak == currentStreak &&
        other.longestStreak == longestStreak;
  }

  @override
  int get hashCode {
    return Object.hash(
      totalXp,
      totalQuizzesCompleted,
      learnedWordsCount,
      level,
      currentStreak,
      longestStreak,
    );
  }
}
