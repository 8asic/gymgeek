import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/exercise.dart';

class ExerciseService {
  static final ExerciseService _instance = ExerciseService._internal();
  factory ExerciseService() => _instance;
  ExerciseService._internal();

  List<Exercise> _exercises = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString('assets/exercises.json');
    final List<dynamic> list = json.decode(jsonStr) as List;
    _exercises = list.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
    _loaded = true;
  }

  List<Exercise> get all => List.unmodifiable(_exercises);

  // All unique muscle groups
  List<String> get muscleGroups {
    final set = <String>{};
    for (final e in _exercises) {
      set.addAll(e.primaryMuscles);
    }
    return set.toList()..sort();
  }

  // All unique equipment types
  List<String> get equipmentTypes {
    final set = <String>{};
    for (final e in _exercises) {
      set.add(e.equipment);
    }
    return set.toList()..sort();
  }

  List<Exercise> search({
    String query = '',
    String? muscle,
    String? equipment,
    String? level,
    String? category,
  }) {
    return _exercises.where((e) {
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        final nameMatch = e.name.toLowerCase().contains(q);
        final muscleMatch = e.primaryMuscles.any((m) => m.toLowerCase().contains(q));
        final equipMatch = e.equipment.toLowerCase().contains(q);
        if (!nameMatch && !muscleMatch && !equipMatch) return false;
      }
      if (muscle != null && muscle.isNotEmpty) {
        if (!e.primaryMuscles.contains(muscle) && !e.secondaryMuscles.contains(muscle)) {
          return false;
        }
      }
      if (equipment != null && equipment.isNotEmpty) {
        if (e.equipment != equipment) return false;
      }
      if (level != null && level.isNotEmpty) {
        if (e.level != level) return false;
      }
      if (category != null && category.isNotEmpty) {
        if (e.category != category) return false;
      }
      return true;
    }).toList();
  }

  // Group exercises by primary muscle
  Map<String, List<Exercise>> get byMuscle {
    final map = <String, List<Exercise>>{};
    for (final e in _exercises) {
      for (final m in e.primaryMuscles) {
        map.putIfAbsent(m, () => []).add(e);
      }
    }
    return map;
  }

  // Exercises recommended for a given goal
  List<Exercise> forGoal(String goalType) {
    switch (goalType) {
      case 'strength':
        return search(level: null)
            .where((e) => e.mechanic == 'compound' && e.category == 'Strength')
            .toList();
      case 'endurance':
        return search(category: 'Cardio');
      case 'weightLoss':
        return _exercises
            .where((e) => e.category == 'Cardio' || e.mechanic == 'compound')
            .toList();
      case 'general':
      default:
        return all;
    }
  }

  // Beginner-friendly progression for a muscle group
  List<Exercise> progressionFor(String muscle) {
    final all = search(muscle: muscle);
    final beginner = all.where((e) => e.level == 'beginner').toList();
    final intermediate = all.where((e) => e.level == 'intermediate').toList();
    final advanced = all.where((e) => e.level == 'advanced').toList();
    return [...beginner, ...intermediate, ...advanced];
  }

  Exercise? findById(String id) {
    try {
      return _exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
