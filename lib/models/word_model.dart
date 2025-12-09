import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
part 'word_model.g.dart';

@HiveType(typeId: 0)
class Word extends HiveObject {
  @HiveField(14)
  final String id;
  @HiveField(0)
  final String word;
  @HiveField(1)
  final String meaning;
  @HiveField(2)
  final String example;
  @HiveField(3)
  final String tr; // Turkish translation
  @HiveField(4)
  final String exampleSentence;
  @HiveField(5)
  bool isFavorite;
  @HiveField(6)
  DateTime? nextReviewDate;
  @HiveField(7)
  int interval;
  @HiveField(8)
  int correctStreak;
  @HiveField(9)
  List<String> tags;
  @HiveField(10)
  int srsLevel; // 0 = not learned, 1-5 = learning stages
  @HiveField(11)
  bool isCustom; // true if added by user, false if from default word list
  @HiveField(12)
  final String? category; // Category for quiz filtering
  @HiveField(13)
  final DateTime? createdAt; // When the word was created/added

  Word({
    this.id = '',
    required this.word,
    required this.meaning,
    required this.example,
    this.tr = '',
    this.exampleSentence = '',
    this.isFavorite = false,
    this.nextReviewDate,
    this.interval = 1,
    this.correctStreak = 0,
    this.tags = const [],
    this.srsLevel = 0,
    this.isCustom = false,
    this.category,
    this.createdAt,
  });

  factory Word.fromJson(Map<String, dynamic> json, [String docId = '']) {
    final resolvedWord = (json['word'] ??
            json['text'] ??
            json['value'] ??
            json['name'] ??
            '')
        .toString();
    if (resolvedWord.isEmpty) {

    }
    final resolvedId = docId.isNotEmpty
        ? docId
        : (json['id'] ?? json['wordId'] ?? resolvedWord).toString();
    
    // Helper function to parse DateTime from various formats
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      // Handle Firestore Timestamp
      if (value is Timestamp) {
        return value.toDate();
      }
      return null;
    }
    
    return Word(
      id: resolvedId,
      word: resolvedWord,
      meaning: json['meaning']?.toString() ?? '',
      example: (json['example'] ?? json['exampleSentence'] ?? '').toString(),
      tr: json['tr']?.toString() ?? '',
      exampleSentence:
          (json['exampleSentence'] ?? json['example'] ?? '').toString(),
      isFavorite: json['isFavorite'] ?? false,
      nextReviewDate: parseDateTime(json['nextReviewDate']),
      interval: json['interval'] ?? 1,
      correctStreak: json['correctStreak'] ?? 0,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      srsLevel: json['srsLevel'] ?? 0,
      isCustom: json['isCustom'] ?? false,
      category: json['category'],
      createdAt: parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'example': example,
      'tr': tr,
      'exampleSentence': exampleSentence,
      'isFavorite': isFavorite,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'interval': interval,
      'correctStreak': correctStreak,
      'tags': tags,
      'srsLevel': srsLevel,
      'isCustom': isCustom,
      'category': category,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
