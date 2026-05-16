enum GoalType { strength, endurance, weightLoss, general }

extension GoalTypeExtension on GoalType {
  String get label {
    switch (this) {
      case GoalType.strength:
        return 'Strength';
      case GoalType.endurance:
        return 'Endurance';
      case GoalType.weightLoss:
        return 'Weight Loss';
      case GoalType.general:
        return 'General Fitness';
    }
  }

  String get icon {
    switch (this) {
      case GoalType.strength:
        return '💪';
      case GoalType.endurance:
        return '🏃';
      case GoalType.weightLoss:
        return '🔥';
      case GoalType.general:
        return '⭐';
    }
  }

  String get description {
    switch (this) {
      case GoalType.strength:
        return 'Build muscle and increase max lifts';
      case GoalType.endurance:
        return 'Improve stamina and cardiovascular health';
      case GoalType.weightLoss:
        return 'Burn fat and reduce body weight';
      case GoalType.general:
        return 'Stay active and maintain overall fitness';
    }
  }

  /// Recommended equipment muscle groups for this goal
  List<String> get recommendedMuscleGroups {
    switch (this) {
      case GoalType.strength:
        return ['Chest', 'Back', 'Legs', 'Full Body'];
      case GoalType.endurance:
        return ['Cardio', 'Full Body'];
      case GoalType.weightLoss:
        return ['Cardio', 'Full Body'];
      case GoalType.general:
        return ['Cardio', 'Chest', 'Back', 'Legs', 'Full Body'];
    }
  }
}

class FitnessGoal {
  final int? id;
  final GoalType goalType;
  final double? targetValue;
  final DateTime startDate;
  final DateTime? endDate;

  FitnessGoal({
    this.id,
    required this.goalType,
    this.targetValue,
    required this.startDate,
    this.endDate,
  });

  factory FitnessGoal.fromMap(Map<String, dynamic> map) {
    return FitnessGoal(
      id: map['id'] as int?,
      goalType: GoalType.values.firstWhere(
        (e) => e.name == map['goal_type'],
        orElse: () => GoalType.general,
      ),
      targetValue: map['target_value'] as double?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'goal_type': goalType.name,
        'target_value': targetValue,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      };
}
