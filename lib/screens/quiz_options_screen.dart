import 'package:flutter/material.dart';
import 'package:lexiflow/models/category_theme.dart';
import 'package:lexiflow/utils/logger.dart';
import 'package:lexiflow/utils/transitions.dart';
import 'package:lexiflow/utils/feature_flags.dart';
import 'package:animations/animations.dart';
import 'package:lexiflow/services/ad_service.dart';
import 'package:lexiflow/di/locator.dart';
import 'package:lexiflow/screens/quiz_type_select_screen.dart';
import 'package:lexiflow/utils/feature_flags.dart';

class QuizOptionsScreen extends StatefulWidget {
  final String category;

  const QuizOptionsScreen({super.key, required this.category});

  @override
  State<QuizOptionsScreen> createState() => _QuizOptionsScreenState();
}

class _QuizOptionsScreenState extends State<QuizOptionsScreen> {
  static const String _tag = 'QuizOptionsScreen';

  @override
  Widget build(BuildContext context) {
    // dinamik tema uygulama
    final theme =
        categoryThemes[widget.category] ??
        const CategoryTheme(
          emoji: '🎯',
          color: Colors.blueAccent,
          title: 'Quiz',
          description: 'Hazırsan başlayalım!',
        );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          theme.title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // kategori başlığı ve emoji
                _buildCategoryHeader(theme),
                const SizedBox(height: 32),

                // quiz türleri
                _buildQuizTypesList(theme),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(CategoryTheme theme) {
    return Column(
      children: [
        // büyük emoji container
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.color.withOpacity(0.3),
                theme.color.withOpacity(0.1),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: theme.color.withOpacity(0.5), width: 2),
          ),
          child: Text(theme.emoji, style: const TextStyle(fontSize: 80)),
        ),
        const SizedBox(height: 24),

        // kategori başlığı
        Text(
          theme.title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // kategori açıklaması
        Text(
          theme.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuizTypesList(CategoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quiz Hazır!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Text(
          'Farklı quiz türleri arasından seçim yapabilirsiniz',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // quiz başlat butonu
        ElevatedButton(
          onPressed: _startQuizSelection,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow, size: 28),
              const SizedBox(width: 12),
              Text(
                'Quiz Başlat',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _startQuizSelection() async {
    Logger.i(
      '[QUIZ] Opening quiz type selection for category: ${widget.category}',
      _tag,
    );
    final adService = locator<AdService>();
    final proceed =
        FeatureFlags.adsEnabled
            ? await adService.enforceRewardedGateIfNeeded(
              context: context,
              grantXpOnReward: true,
            )
            : true;
    if (!proceed) return;
    if (!mounted) return;
    Navigator.push(
      context,
      FeatureFlags.useSharedAxisForDrillIn
          ? sharedAxisRoute(
              builder:
                  (context) => QuizTypeSelectScreen(category: widget.category),
              type: SharedAxisTransitionType.horizontal,
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
            )
          : fadeThroughRoute(
              builder:
                  (context) => QuizTypeSelectScreen(category: widget.category),
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
            ),
    );
  }
}
