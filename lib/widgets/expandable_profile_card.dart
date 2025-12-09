import 'package:flutter/material.dart';
import '../models/achievement.dart';

class ExpandableProfileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int currentValue;
  final int maxValue;
  final Color color;
  final List<Achievement> achievements;

  const ExpandableProfileCard({
    super.key,
    required this.title,
    required this.icon,
    required this.currentValue,
    required this.maxValue,
    required this.color,
    required this.achievements,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate milestone counts based on title
    List<int> milestones = [];
    if (title.contains('Kelime')) {
      milestones = [50, 100, 250, 500, 1000];
    } else if (title.contains('Seri')) {
      milestones = [25, 50, 75, 100, 150];
    } else if (title.contains('Quiz')) {
      milestones = [25, 50, 75, 100, 150];
    }
    
    // Count how many milestones are completed
    final unlockedCount = milestones.where((m) => currentValue >= m).length;
    final totalCount = milestones.length;
    
    // Calculate progress for the card itself (e.g., 5/25 quizzes)
    // If maxValue is 0, avoid division by zero
    final progress = maxValue > 0 ? (currentValue / maxValue).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: () => _showAchievementDialog(context, isDark),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
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
          child: Row(
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unlockedCount/$totalCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Progress Text
                    Text(
                      '$currentValue / $maxValue',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementDialog(BuildContext context, bool isDark) {
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
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Achievements List - Show Milestones
              Flexible(
                child: Builder(
                  builder: (context) {
                    // Create milestone list based on title
                    List<Map<String, dynamic>> milestones = [];
                    
                    if (title.contains('Kelime')) {
                      milestones = [
                        {'target': 50, 'description': '50 kelime öğren'},
                        {'target': 100, 'description': '100 kelime öğren'},
                        {'target': 250, 'description': '250 kelime öğren'},
                        {'target': 500, 'description': '500 kelime öğren'},
                        {'target': 1000, 'description': '1000 kelime öğren'},
                      ];
                    } else if (title.contains('Seri')) {
                      milestones = [
                        {'target': 25, 'description': '25 günlük seri'},
                        {'target': 50, 'description': '50 günlük seri'},
                        {'target': 75, 'description': '75 günlük seri'},
                        {'target': 100, 'description': '100 günlük seri'},
                        {'target': 150, 'description': '150 günlük seri'},
                      ];
                    } else if (title.contains('Quiz')) {
                      milestones = [
                        {'target': 25, 'description': '25 quiz tamamla'},
                        {'target': 50, 'description': '50 quiz tamamla'},
                        {'target': 75, 'description': '75 quiz tamamla'},
                        {'target': 100, 'description': '100 quiz tamamla'},
                        {'target': 150, 'description': '150 quiz tamamla'},
                      ];
                    }
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: milestones.length,
                      itemBuilder: (context, index) {
                        final milestone = milestones[index];
                        final target = milestone['target'] as int;
                        final description = milestone['description'] as String;
                        final unlocked = currentValue >= target;
                        final progress = currentValue;

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
                                  icon,
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
                                      description,
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
                                      unlocked ? 'Tamamlandı! 🎉' : 'Devam et...',
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
