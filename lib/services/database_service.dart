import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workout_session.dart';
import '../models/workout_set.dart';
import '../models/goal.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gymgeek.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_id TEXT NOT NULL,
        equipment_name TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 0,
        notes TEXT DEFAULT "",
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        set_number INTEGER NOT NULL DEFAULT 1,
        weight_kg REAL NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        notes TEXT DEFAULT "",
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_type TEXT NOT NULL,
        target_value REAL,
        start_date DATETIME NOT NULL,
        end_date DATETIME
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        details TEXT,
        confidence REAL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.rawInsert(
        "INSERT INTO settings (key, value) VALUES ('gdpr_consent', 'true')");
    await db.rawInsert(
        "INSERT INTO settings (key, value) VALUES ('ai_recommendations', 'true')");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workout_sets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          exercise_id TEXT NOT NULL,
          exercise_name TEXT NOT NULL,
          set_number INTEGER NOT NULL DEFAULT 1,
          weight_kg REAL NOT NULL DEFAULT 0,
          reps INTEGER NOT NULL DEFAULT 0,
          notes TEXT DEFAULT "",
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }
  }

  // ─── Workout CRUD ─────────────────────────────────────────────────────────

  Future<int> insertWorkout(WorkoutSession session) async {
    final db = await database;
    return db.insert('workouts', session.toMap());
  }

  Future<List<WorkoutSession>> getAllWorkouts() async {
    final db = await database;
    final maps = await db.query('workouts', orderBy: 'timestamp DESC');
    return maps.map(WorkoutSession.fromMap).toList();
  }

  Future<List<WorkoutSession>> getRecentWorkouts({int limit = 10}) async {
    final db = await database;
    final maps = await db.query(
      'workouts',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(WorkoutSession.fromMap).toList();
  }

  Future<int> deleteWorkout(int id) async {
    final db = await database;
    return db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getWorkoutCountByEquipment() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT equipment_name, COUNT(*) as count FROM workouts GROUP BY equipment_name ORDER BY count DESC',
    );
    return {
      for (var row in result)
        row['equipment_name'] as String: row['count'] as int
    };
  }

  Future<int> getTotalWorkoutMinutes() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT SUM(duration_minutes) as total FROM workouts');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getWorkoutsThisWeek() async {
    final db = await database;
    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM workouts WHERE timestamp >= ?",
        [weekAgo]);
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getStreak() async {
    final db = await database;
    final maps = await db.query('workouts', orderBy: 'timestamp DESC');
    if (maps.isEmpty) return 0;
    int streak = 0;
    DateTime? lastDate;
    for (final map in maps) {
      final date = DateTime.parse(map['timestamp'] as String);
      final day = DateTime(date.year, date.month, date.day);
      if (lastDate == null) {
        lastDate = day;
        streak = 1;
      } else {
        final diff = lastDate.difference(day).inDays;
        if (diff == 1) {
          streak++;
          lastDate = day;
        } else if (diff == 0) {
          continue;
        } else {
          break;
        }
      }
    }
    return streak;
  }

  // ─── Goals CRUD ───────────────────────────────────────────────────────────

  Future<int> insertGoal(FitnessGoal goal) async {
    final db = await database;
    await db.delete('goals');
    return db.insert('goals', goal.toMap());
  }

  Future<FitnessGoal?> getCurrentGoal() async {
    final db = await database;
    final maps =
        await db.query('goals', orderBy: 'start_date DESC', limit: 1);
    if (maps.isEmpty) return null;
    return FitnessGoal.fromMap(maps.first);
  }

  Future<int> deleteAllGoals() async {
    final db = await database;
    return db.delete('goals');
  }

  // ─── Audit Log ────────────────────────────────────────────────────────────

  Future<void> logAuditEvent({
    required String eventType,
    String? details,
    double? confidence,
  }) async {
    final db = await database;
    await db.insert('audit_log', {
      'event_type': eventType,
      'details': details,
      'confidence': confidence,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ─── Settings ─────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps =
        await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── GDPR ─────────────────────────────────────────────────────────────────

  Future<void> deleteAllUserData() async {
    final db = await database;
    await db.delete('workouts');
    await db.delete('workout_sets');
    await db.delete('goals');
    await db.delete('audit_log');
    await db.update('settings', {'value': 'false'},
        where: 'key = ?', whereArgs: ['gdpr_consent']);
  }

  // ─── Workout Sets (sets/reps/weight) ──────────────────────────────────────

  Future<int> insertSet(WorkoutSet s) async {
    final db = await database;
    return db.insert('workout_sets', s.toMap());
  }

  Future<List<WorkoutSet>> getSetsForExercise(String exerciseId,
      {int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'workout_sets',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(WorkoutSet.fromMap).toList();
  }

  Future<List<WorkoutSet>> getRecentSets({int limit = 30}) async {
    final db = await database;
    final maps = await db.query('workout_sets',
        orderBy: 'timestamp DESC', limit: limit);
    return maps.map(WorkoutSet.fromMap).toList();
  }

  Future<int> deleteSet(int id) async {
    final db = await database;
    return db.delete('workout_sets', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Personal Records ─────────────────────────────────────────────────────

  Future<List<PersonalRecord>> getPersonalRecords() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT exercise_id, exercise_name, weight_kg, reps, timestamp,
             (weight_kg * (1.0 + reps / 30.0)) as e1rm
      FROM workout_sets
      GROUP BY exercise_id
      HAVING (weight_kg * (1.0 + reps / 30.0)) = MAX(weight_kg * (1.0 + reps / 30.0))
      ORDER BY e1rm DESC
    ''');
    return maps
        .map((m) => PersonalRecord(
              exerciseId: m['exercise_id'] as String,
              exerciseName: m['exercise_name'] as String,
              weightKg: (m['weight_kg'] as num).toDouble(),
              reps: m['reps'] as int,
              estimated1RM: (m['e1rm'] as num).toDouble(),
              date: DateTime.parse(m['timestamp'] as String),
            ))
        .toList();
  }

  Future<bool> isNewPR(WorkoutSet s) async {
    final db = await database;
    final new1rm = s.estimated1RM;
    final maps = await db.rawQuery('''
      SELECT MAX(weight_kg * (1.0 + reps / 30.0)) as best
      FROM workout_sets WHERE exercise_id = ?
    ''', [s.exerciseId]);
    if (maps.isEmpty || maps.first['best'] == null) return true;
    return new1rm > (maps.first['best'] as num).toDouble();
  }
}
