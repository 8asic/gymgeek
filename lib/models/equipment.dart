class Equipment {
  final String id;
  final String name;
  final String description;
  final String muscleGroup;
  final String difficultyLevel;
  final String videoUrl;
  final List<String> tips;
  final List<String> labels;

  Equipment({
    required this.id,
    required this.name,
    required this.description,
    required this.muscleGroup,
    required this.difficultyLevel,
    required this.videoUrl,
    required this.tips,
    required this.labels,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      muscleGroup: json['muscleGroup'] as String,
      difficultyLevel: json['difficultyLevel'] as String,
      videoUrl: json['videoUrl'] as String,
      tips: List<String>.from(json['tips'] as List),
      labels: List<String>.from(json['labels'] as List),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'muscleGroup': muscleGroup,
        'difficultyLevel': difficultyLevel,
        'videoUrl': videoUrl,
        'tips': tips,
        'labels': labels,
      };

  /// Muscle group icon
  String get muscleGroupIcon {
    switch (muscleGroup.toLowerCase()) {
      case 'cardio':
        return '🏃';
      case 'legs':
        return '🦵';
      case 'chest':
        return '💪';
      case 'back':
        return '🔙';
      case 'full body':
        return '⚡';
      default:
        return '🏋️';
    }
  }

  /// Difficulty color hint
  String get difficultyLabel {
    switch (difficultyLevel.toLowerCase()) {
      case 'beginner':
        return '🟢 Beginner';
      case 'intermediate':
        return '🟡 Intermediate';
      case 'advanced':
        return '🔴 Advanced';
      default:
        return difficultyLevel;
    }
  }
}
