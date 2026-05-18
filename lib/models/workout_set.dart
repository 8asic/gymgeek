class WorkoutSet {
  final int? id;
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final double weightKg;
  final int reps;
  final String notes;
  final DateTime timestamp;

  WorkoutSet({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    this.notes = '',
    required this.timestamp,
  });

  // Epley formula for estimated 1-rep max
  double get estimated1RM {
    if (reps == 1) return weightKg;
    return weightKg * (1 + reps / 30.0);
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> m) => WorkoutSet(
        id: m['id'] as int?,
        exerciseId: m['exercise_id'] as String,
        exerciseName: m['exercise_name'] as String,
        setNumber: m['set_number'] as int,
        weightKg: (m['weight_kg'] as num).toDouble(),
        reps: m['reps'] as int,
        notes: m['notes'] as String? ?? '',
        timestamp: DateTime.parse(m['timestamp'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'set_number': setNumber,
        'weight_kg': weightKg,
        'reps': reps,
        'notes': notes,
        'timestamp': timestamp.toIso8601String(),
      };

  String get display => weightKg > 0
      ? '${weightKg.toStringAsFixed(1)}kg × $reps'
      : 'Bodyweight × $reps';
}

class PersonalRecord {
  final String exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final double estimated1RM;
  final DateTime date;

  PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.estimated1RM,
    required this.date,
  });
}
