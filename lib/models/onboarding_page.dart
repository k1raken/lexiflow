import 'package:flutter/material.dart';

class OnboardingPage {
  final String title;
  final String description;
  final String image;
  final Color backgroundColor;
  final Color textColor;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.image,
    required this.backgroundColor,
    required this.textColor,
  });
}

class OnboardingData {
  static List<OnboardingPage> pages = [
    const OnboardingPage(
      title: 'Hoş Geldin! 👋',
      description: 'LexiFlow ile İngilizce kelime öğrenme yolculuğuna başla. Her gün yeni kelimeler, eğlenceli quizler ve daha fazlası!',
      image: '🚀',
      backgroundColor: Color(0xFF6366F1),
      textColor: Colors.white,
    ),
    const OnboardingPage(
      title: 'Günlük Kelimeler 📚',
      description: 'Her gün sana özel seçilmiş 10 kelime. Öğrendikçe yeni kelimeler açılır, hiç sıkılmazsın!',
      image: '📖',
      backgroundColor: Color(0xFF8B5CF6),
      textColor: Colors.white,
    ),
    const OnboardingPage(
      title: 'Eğlenceli Quizler 🎯',
      description: 'Öğrendiğin kelimeleri quizlerle pekiştir. Her doğru cevap sana XP kazandırır!',
      image: '🎮',
      backgroundColor: Color(0xFFEC4899),
      textColor: Colors.white,
    ),
    const OnboardingPage(
      title: 'Streak Sistemi 🔥',
      description: 'Her gün giriş yap, streak\'ini koru! Kesintisiz öğrenme seni başarıya götürür.',
      image: '⚡',
      backgroundColor: Color(0xFFF59E0B),
      textColor: Colors.white,
    ),
    const OnboardingPage(
      title: 'Hazır mısın? 🎉',
      description: 'Hemen başlayalım! İlk 5 kelimeni öğrenmeye hazır ol.',
      image: '✨',
      backgroundColor: Color(0xFF10B981),
      textColor: Colors.white,
    ),
  ];
}
