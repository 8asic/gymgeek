import 'package:flutter/material.dart';

class Exercise {
  final String id;
  final String name;
  final String category;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String equipment;
  final String level;
  final String mechanic;
  final List<String> instructions;
  final List<String> images;

  double? prWeight;
  int? prReps;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    required this.level,
    required this.mechanic,
    required this.instructions,
    required this.images,
    this.prWeight,
    this.prReps,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String? ?? 'Strength',
        primaryMuscles: List<String>.from(j['primaryMuscles'] as List? ?? []),
        secondaryMuscles: List<String>.from(j['secondaryMuscles'] as List? ?? []),
        equipment: j['equipment'] as String? ?? 'body only',
        level: j['level'] as String? ?? 'beginner',
        mechanic: j['mechanic'] as String? ?? 'compound',
        instructions: List<String>.from(j['instructions'] as List? ?? []),
        images: List<String>.from(j['images'] as List? ?? []),
      );

  String get thumbnailUrl => images.isNotEmpty ? images[0] : '';
  String get secondImageUrl => images.length > 1 ? images[1] : thumbnailUrl;

  String get levelEmoji {
    switch (level) {
      case 'beginner':    return '🟢';
      case 'intermediate':return '🟡';
      case 'advanced':    return '🔴';
      default:            return '⚪';
    }
  }

  String get equipmentIcon {
    switch (equipment) {
      case 'barbell':   return '🏋️';
      case 'dumbbell':  return '💪';
      case 'cable':     return '🔗';
      case 'machine':   return '⚙️';
      case 'body only': return '🤸';
      case 'kettlebell':return '🫙';
      default:          return '🏃';
    }
  }

  Color get levelColor {
    switch (level) {
      case 'beginner':    return const Color(0xFF4CAF50);
      case 'intermediate':return const Color(0xFFFF9800);
      case 'advanced':    return const Color(0xFFE53935);
      default:            return const Color(0xFFAAAAAA);
    }
  }
}
