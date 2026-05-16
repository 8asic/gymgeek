import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';
import '../models/workout.dart';
import '../utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<WorkoutSession> _recent = [];
  Map<String, int> _byEquipment = {};
  int _totalMinutes = 0;
  int _weekCount = 0;
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final recent = await db.getRecentWorkouts(limit: 20);
    final byEq = await db.getWorkoutCountByEquipment();
    final total = await db.getTotalWorkoutMinutes();
    final week = await db.getWorkoutsThisWeek();
    final streak = await db.getStreak();
    if (mounted) {
      setState(() {
        _recent = recent;
        _byEquipment = byEq;
        _totalMinutes = total;
        _weekCount = week;
        _streak = streak;
        _loading = false;
      });
    }
  }

  Future<void> _deleteWorkout(WorkoutSession s) async {
    await DatabaseHelper().deleteWorkout(s.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Progress Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _recent.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _statsRow(),
                        const SizedBox(height: 22),
                        if (_byEquipment.isNotEmpty) ...[
                          const Text('Workouts by Equipment',
                              style: TextStyle(color: AppColors.textPrimary,
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          _barChart(),
                          const SizedBox(height: 24),
                        ],
                        const Text('Recent Sessions',
                            style: TextStyle(color: AppColors.textPrimary,
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ..._recent.map((s) => _workoutTile(s)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fitness_center, color: AppColors.textSecondary, size: 64),
          const SizedBox(height: 16),
          const Text('No workouts yet',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Scan or search equipment, then save a session',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statCard('🔥', '$_streak', 'Day streak'),
        const SizedBox(width: 10),
        _statCard('📅', '$_weekCount', 'This week'),
        const SizedBox(width: 10),
        _statCard('⏱️', '${_totalMinutes}m', 'Total time'),
      ],
    );
  }

  Widget _statCard(String icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(color: AppColors.textPrimary,
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _barChart() {
    final entries = _byEquipment.entries.take(5).toList();
    final maxVal = entries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal + 1,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= entries.length) return const SizedBox();
                  final name = entries[i].key;
                  final short = name.length > 8 ? '${name.substring(0, 7)}…' : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(short,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.cardLight, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: AppColors.primary,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _workoutTile(WorkoutSession s) {
    return Dismissible(
      key: Key('w-${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => _deleteWorkout(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.fitness_center, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.equipmentName,
                      style: const TextStyle(color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  Text('${s.durationMinutes} min · ${s.dateLabel}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  if (s.notes.isNotEmpty)
                    Text(s.notes,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('${s.durationMinutes}m',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
