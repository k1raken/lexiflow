import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/learned_words_service.dart';
import '../services/session_service.dart';
import '../di/locator.dart';
import 'package:confetti/confetti.dart';

class FirstWordsTutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const FirstWordsTutorialScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<FirstWordsTutorialScreen> createState() => _FirstWordsTutorialScreenState();
}

class _FirstWordsTutorialScreenState extends State<FirstWordsTutorialScreen> {
  final PageController _pageController = PageController();
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(milliseconds: 1500),
  );
  
  int _currentIndex = 0;
  List<Word> _words = [];
  bool _isLoading = true;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _loadFirstWords();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstWords() async {
    try {
      final wordService = locator<WordService>();
      final allWords = await wordService.getRandomWords(5);
      
      if (mounted) {
        setState(() {
          _words = allWords;
          _isLoading = false;
        });
      }
    } catch (e) {

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _nextWord() {
    HapticFeedback.lightImpact();
    if (_currentIndex < _words.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentIndex++;
      });
    } else {
      _completeLesson();
    }
  }

  Future<void> _completeLesson() async {
    if (_isCompleting) return;
    
    setState(() {
      _isCompleting = true;
    });

    HapticFeedback.mediumImpact();
    _confettiController.play();

    // Fire-and-forget: Start background operations but don't wait
    _saveProgressInBackground();

    // Navigate immediately without waiting
    if (mounted) {
      widget.onComplete();
    }
  }

  Future<void> _saveProgressInBackground() async {
    try {
      final sessionService = locator<SessionService>();
      final learnedWordsService = locator<LearnedWordsService>();
      final userId = sessionService.currentUser?.uid;

      if (userId != null) {
        // API çağrılarını paralel yap
        final futures = <Future>[];
        
        // Mark all words as learned
        for (final word in _words) {
          futures.add(learnedWordsService.markWordAsLearned(userId, word));
        }

        // Award XP
        futures.add(sessionService.addXp(50)); // Bonus XP for completing tutorial
        
        // Hepsini bekle ama hata olsa bile devam et
        await Future.wait(futures).catchError((e) {

          return <dynamic>[];
        });

      }
    } catch (e) {

    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF6366F1),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text(
                'İlk kelimeler hazırlanıyor...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF6366F1),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '😔',
                style: TextStyle(fontSize: 80),
              ),
              const SizedBox(height: 24),
              const Text(
                'Kelimeler yüklenemedi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: widget.onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Devam Et'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF6366F1),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'İlk 5 Kelimen',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_currentIndex + 1}/${_words.length}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / _words.length,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Word cards
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      return _buildWordCard(_words[index]);
                    },
                  ),
                ),

                // Next button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isCompleting ? null : _nextWord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isCompleting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _currentIndex == _words.length - 1
                                  ? 'Tamamla! 🎉'
                                  : 'Sonraki Kelime',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(Word word) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Word content (left side)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Word
                      Text(
                        word.word,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Meaning
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          word.meaning,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Turkish translation
                      if (word.tr.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text('🇹🇷', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                word.tr,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Example
                      if (word.exampleSentence.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.format_quote,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  word.exampleSentence,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                    fontStyle: FontStyle.italic,
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
                
                // Checkmark icon (right side) - directly in Row like favorites
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
