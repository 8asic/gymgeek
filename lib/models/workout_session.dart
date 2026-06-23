class WorkoutSession {
  final int? id;
  final String equipmentId;
  final String equipmentName;
  final int durationMinutes;
  final String notes;
  final DateTime timestamp;

  WorkoutSession({
    this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.durationMinutes,
    this.notes = '',
    required this.timestamp,
  });

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as int?,
      equipmentId: map['equipment_id'] as String,
      equipmentName: map['equipment_name'] as String,
      durationMinutes: map['duration_minutes'] as int,
      notes: map['notes'] as String? ?? '',
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'equipment_id': equipmentId,
        'equipment_name': equipmentName,
        'duration_minutes': durationMinutes,
        'notes': notes,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Friendly date string
  String get dateLabel {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
