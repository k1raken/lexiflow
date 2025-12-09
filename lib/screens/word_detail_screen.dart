// lib/screens/word_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/session_service.dart';
import '../services/learned_words_service.dart';
import '../utils/design_system.dart';
import '../utils/animation_utils.dart';
import '../widgets/lexiflow_toast.dart';
import '../widgets/xp_popup.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen>
    with SafeAnimationMixin, TickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  final LearnedWordsService _learnedWordsService = LearnedWordsService();
  bool _isSpeaking = false;
  bool _isLearned = false;
  bool _isMarkingLearned = false;

  @override
  void initState() {
    super.initState();
    initSafeController(
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    safeForward();
    _initTts();
    _checkIfWordIsLearned();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
    }
  }

  /// Check if the current word is already learned
  Future<void> _checkIfWordIsLearned() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final userId = sessionService.currentUser?.uid;

    if (userId == null) return;

    try {
      final isLearned = await _learnedWordsService.isWordLearned(
        userId,
        widget.word.word,
        word: widget.word,
      );
      if (mounted) {
        setState(() {
          _isLearned = isLearned;
        });
      }
    } catch (e) {
      // Handle error silently, default to not learned
    }
  }

  /// Toggle the learned status of the current word
  Future<void> _toggleWordLearned() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final userId = sessionService.currentUser?.uid;

    if (userId == null || _isMarkingLearned) return;

    setState(() {
      _isMarkingLearned = true;
    });

    try {
      bool success = false;

      if (_isLearned) {
        // Unlearn the word
        success = await _learnedWordsService.unmarkWordAsLearned(
          userId,
          widget.word.word,
          word: widget.word,
        );

        if (mounted && success) {
          setState(() {
            _isLearned = false;
            _isMarkingLearned = false;
          });

          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kelime öğrenildi listesinden çıkarıldı'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Learn the word
        success = await _learnedWordsService.markWordAsLearned(
          userId,
          widget.word,
        );

        if (success && mounted) {
          showXPPopup(context, 20);
        }

        if (mounted && success) {
          // Trigger satisfying haptic feedback
          HapticFeedback.heavyImpact();
          
          setState(() {
            _isLearned = true;
            _isMarkingLearned = false;
          });

          // Show success feedback
          showLexiflowToast(
            context,
            ToastType.success,
            'Kelime öğrenildi olarak işaretlendi! 🎉',
          );
        }
      }

      if (mounted && !success) {
        setState(() {
          _isMarkingLearned = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMarkingLearned = false;
        });

        showLexiflowToast(
          context,
          ToastType.error,
          'Bir hata oluştu. Tekrar deneyin.',
        );
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    final wordService = Provider.of<WordService>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Clean light grey background for light mode
    final scaffoldBackground = isDark 
        ? AppColors.textPrimary 
        : const Color(0xFFF5F7FA);

    final detailSurface = isDark 
        ? AppDarkColors.surface 
        : scaffoldBackground;

    return Scaffold(
      backgroundColor: scaffoldBackground,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: isDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.textPrimary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null, // No gradient in light mode
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header
              _buildModernHeader(sessionService, wordService),

              // Content with Modern Design
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: detailSurface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    border: Border.all(
                      color: AppColors.surface.withOpacity(0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 30,
                        offset: const Offset(0, -12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      // Modern Word Card - Static at top
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                        ),
                        child: AnimationUtils.buildSafeScaleTransition(
                          animation: safeController,
                          child: _buildModernWordCard(isDark),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Tabbed Content - Fills remaining space
                      Expanded(child: _buildTabbedContent(isDark)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern Header
  Widget _buildModernHeader(
    SessionService sessionService,
    WordService wordService,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Theme-aware button styling
    final buttonBg = isDark 
        ? AppColors.surface.withOpacity(0.2) 
        : Colors.white;
    
    final iconColor = isDark 
        ? AppColors.surface 
        : Colors.black87;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          // Back Button with shadow in light mode
          Container(
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: AppBorderRadius.medium,
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: iconColor,
              ),
              iconSize: 20,
            ),
          ),
          const Spacer(),

          // Favorite Button
          if (!sessionService.isGuest && !sessionService.isAnonymous)
            StreamBuilder<Set<String>>(
              stream: wordService.favoritesKeysStream(
                sessionService.currentUser!.uid,
              ),
              builder: (context, snapshot) {
                final keys = snapshot.data ?? <String>{};
                final isFav = keys.contains(widget.word.word);
                return Container(
                  decoration: BoxDecoration(
                    color: buttonBg,
                    borderRadius: AppBorderRadius.medium,
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () async {
                      // Light haptic feedback for favorite toggle
                      HapticFeedback.lightImpact();
                      // Use optimistic UI for instant updates (no blocking)
                      await wordService.toggleFavoriteOptimistic(
                        widget.word,
                        sessionService.currentUser!.uid,
                      );
                    },
                    icon: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav ? AppColors.error : iconColor,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Modern Word Card
  Widget _buildModernWordCard(bool isDark) {
    // Pure white card in light mode
    final cardSurface = isDark 
        ? AppDarkColors.surface 
        : Colors.white;
    
    // Dark text in light mode, light text in dark mode
    final textColor = isDark 
        ? AppColors.surface 
        : Colors.black87;
    
    final borderColor = isDark 
        ? AppColors.surface.withOpacity(0.18) 
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: borderColor, width: 1.2) : null,
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.5) 
                : Colors.black.withOpacity(0.05), // Subtle shadow in light mode
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pronunciation Button with Animation
          AnimatedAudioButton(
            isSpeaking: _isSpeaking,
            onPressed: () => _speak(widget.word.word),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Word Text with Modern Typography
          Text(
            widget.word.word,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          // Word Type/Tags with Modern Design
          if (widget.word.tags.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children:
                  widget.word.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.surface.withOpacity(0.16),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Learned Button with Animation
          _buildLearnedButton(isDark),
        ],
      ),
    );
  }

  // Tabbed Content
  Widget _buildTabbedContent(bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Theme-aware tab bar background
    final tabBackground = isDark 
        ? AppColors.surface.withOpacity(0.05) 
        : Colors.white;
    
    // Readable unselected tab color in light mode
    final unselectedColor = isDark 
        ? AppColors.surface.withOpacity(0.7) 
        : Colors.grey[600];

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Modern Tab Bar - Theme Optimized
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            decoration: BoxDecoration(
              color: tabBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark 
                    ? AppColors.surface.withOpacity(0.1) 
                    : Colors.grey[300]!,
                width: 1,
              ),
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              indicatorColor: AppColors.primary,
              indicatorWeight: 3.2,
              labelColor: AppColors.primary,
              unselectedLabelColor: unselectedColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.pressed)
                        ? AppColors.primary.withOpacity(0.12)
                        : Colors.transparent,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(
                  text: 'Meaning',
                  icon: Icon(Icons.lightbulb_outline_rounded, size: 18),
                ),
                Tab(
                  text: 'Examples',
                  icon: Icon(Icons.format_quote_rounded, size: 18),
                ),
                Tab(
                  text: 'Details',
                  icon: Icon(Icons.info_outline_rounded, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Tab Content - Flexible layout
          Expanded(
            child: TabBarView(
              children: [
                _buildMeaningTab(isDark),
                _buildExamplesTab(isDark),
                _buildDetailsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Meaning Tab
  Widget _buildMeaningTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          _buildModernInfoCard(
            icon: Icons.lightbulb_outline_rounded,
            title: 'English Meaning',
            content: widget.word.meaning,
            color: AppColors.primaryLight,
            delay: 200,
            isDark: isDark,
          ),
          if (widget.word.tr.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildModernInfoCard(
              icon: Icons.translate_rounded,
              title: 'Türkçe Anlamı',
              content: widget.word.tr,
              color: AppColors.primary,
              delay: 400,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  // Examples Tab
  Widget _buildExamplesTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          if (widget.word.example.isNotEmpty)
            _buildModernInfoCard(
              icon: Icons.format_quote_rounded,
              title: 'Example Sentence',
              content: widget.word.example,
              color: AppColors.secondary,
              delay: 200,
              isDark: isDark,
            ),
          if (widget.word.exampleSentence.isNotEmpty &&
              widget.word.exampleSentence != widget.word.example) ...[
            const SizedBox(height: AppSpacing.md),
            _buildModernInfoCard(
              icon: Icons.auto_stories_rounded,
              title: 'Additional Example',
              content: widget.word.exampleSentence,
              color: AppColors.primaryLight,
              delay: 400,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  // Details Tab
  Widget _buildDetailsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          _buildModernInfoCard(
            icon: Icons.info_outline_rounded,
            title: 'Word Information',
            content:
                'Type: ${widget.word.tags.isNotEmpty ? widget.word.tags.join(', ') : 'General'}',
            color: AppColors.primary,
            delay: 200,
            isDark: isDark,
          ),
          if (widget.word.isCustom) ...[
            const SizedBox(height: AppSpacing.md),
            _buildModernInfoCard(
              icon: Icons.edit_rounded,
              title: 'Custom Word',
              content: 'This is a custom word added by you.',
              color: AppColors.primaryLight,
              delay: 400,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  // Modern Info Card
  Widget _buildModernInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    required int delay,
    required bool isDark,
  }) {
    // Pure white cards in light mode
    final backgroundColor = isDark 
        ? AppDarkColors.surfaceVariant.withOpacity(0.92) 
        : Colors.white;
    
    // Dark text in light mode for readability
    final textColor = isDark 
        ? AppColors.surface 
        : Colors.black87;
    
    final borderColor = isDark 
        ? AppColors.surface.withOpacity(0.1) 
        : Colors.transparent;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final safeValue = AnimationUtils.getSafeOpacity(value);
        return Transform.translate(
          offset: AnimationUtils.getSafeTranslation(safeValue, 20),
          child: Opacity(opacity: safeValue, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: borderColor, width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.4) 
                  : Colors.black.withOpacity(0.05), // Subtle shadow in light mode
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                color: textColor, // Dark text in light mode
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the learned button with animation
  Widget _buildLearnedButton(bool isDark) {
    final sessionService = Provider.of<SessionService>(context);

    // Don't show for guests or anonymous users
    if (sessionService.isGuest || sessionService.isAnonymous) {
      return const SizedBox.shrink();
    }

    return LearnedRippleButton(
      isLearned: _isLearned,
      isProcessing: _isMarkingLearned,
      onPressed: _toggleWordLearned,
    );
  }
}

class AnimatedAudioButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isSpeaking;

  const AnimatedAudioButton({
    required this.onPressed,
    required this.isSpeaking,
    super.key,
  });

  @override
  State<AnimatedAudioButton> createState() => _AnimatedAudioButtonState();
}

class _AnimatedAudioButtonState extends State<AnimatedAudioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _colorAnim = ColorTween(
      begin: AppColors.primary,
      end: AppColors.primaryLight,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (context, child) {
        final color = _colorAnim.value ?? AppColors.primary;
        return GestureDetector(
          onTap: _handleTap,
          child: Container(
            height: 95,
            width: 95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              widget.isSpeaking
                  ? Icons.volume_up_rounded
                  : Icons.volume_up_outlined,
              color: Colors.white,
              size: 42,
            ),
          ),
        );
      },
    );
  }
}

class LearnedRippleButton extends StatefulWidget {
  final bool isLearned;
  final bool isProcessing;
  final VoidCallback onPressed;

  const LearnedRippleButton({
    required this.isLearned,
    required this.isProcessing,
    required this.onPressed,
    super.key,
  });

  @override
  State<LearnedRippleButton> createState() => _LearnedRippleButtonState();
}

class _LearnedRippleButtonState extends State<LearnedRippleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerRipple() {
    if (widget.isProcessing) {
      return;
    }
    _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  void didUpdateWidget(covariant LearnedRippleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLearned && oldWidget.isLearned) {
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLearned) {
      return GestureDetector(
        onTap: widget.isProcessing ? null : widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isProcessing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.secondary,
                    ),
                  ),
                )
              else
                Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.isProcessing ? 'İşaretleniyor...' : 'Öğrenildi',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) {
            final value = _scaleAnim.value;
            if (value == 0) {
              return const SizedBox.shrink();
            }
            return Container(
              width: 150 + 110 * value,
              height: 50 + 110 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.18 * (1 - value)),
              ),
            );
          },
        ),
        IgnorePointer(
          ignoring: widget.isProcessing,
          child: OutlinedButton.icon(
            onPressed: _triggerRipple,
            icon:
                widget.isProcessing
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                    : const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primary,
                      size: 18,
                    ),
            label: Text(
              widget.isProcessing ? 'İşaretleniyor...' : 'Bu kelimeyi öğrendim',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              backgroundColor: Colors.white.withOpacity(0.02),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
