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
  ScaffoldFeatureController? _activeSnack;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();
    final results = await Future.wait([
      db.getRecentWorkouts(limit: 50),
      db.getWorkoutCountByEquipment(),
      db.getTotalWorkoutMinutes(),
      db.getWorkoutsThisWeek(),
      db.getStreak(),
    ]);
    if (!mounted) return;
    setState(() {
      _recent = results[0] as List<WorkoutSession>;
      _byEquipment = results[1] as Map<String, int>;
      _totalMinutes = results[2] as int;
      _weekCount = results[3] as int;
      _streak = results[4] as int;
      _loading = false;
    });
  }

  void _showSnack(String msg, {Color? color}) {
    if (!mounted) return;
    _activeSnack?.close();
    _activeSnack = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? AppColors.card,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _deleteWorkout(WorkoutSession s) async {
    await DatabaseHelper().deleteWorkout(s.id!);
    _showSnack('Workout deleted', color: Colors.red.shade700);
    _load();
  }

  void _showEditSheet(WorkoutSession s) {
    final notesCtrl = TextEditingController(text: s.notes);
    int duration = s.durationMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              Text('Edit: ${s.equipmentName}',
                  style: const TextStyle(color: AppColors.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Duration',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60, 90].map((d) {
                  final sel = duration == d;
                  return ChoiceChip(
                    label: Text('$d min'),
                    selected: sel,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.card,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : AppColors.textSecondary),
                    onSelected: (_) => setModal(() => duration = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Notes'),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteWorkout(s);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(0, 46)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Update by delete + re-insert with same timestamp
                      await DatabaseHelper().deleteWorkout(s.id!);
                      await DatabaseHelper().insertWorkout(WorkoutSession(
                        equipmentId: s.equipmentId,
                        equipmentName: s.equipmentName,
                        durationMinutes: duration,
                        notes: notesCtrl.text.trim(),
                        timestamp: s.timestamp,
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _showSnack('Workout updated', color: AppColors.success);
                      _load();
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                    child: const Text('Save'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Progress Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recent Sessions',
                                style: TextStyle(color: AppColors.textPrimary,
                                    fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('Hold to edit • Swipe to delete',
                                style: TextStyle(
                                    color: AppColors.textSecondary.withOpacity(0.6),
                                    fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._recent.map((s) => _workoutTile(s)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.fitness_center, color: AppColors.textSecondary, size: 64),
      const SizedBox(height: 16),
      const Text('No workouts yet',
          style: TextStyle(color: AppColors.textPrimary,
              fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Scan or search equipment, then save a session',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _statsRow() => Row(children: [
    _statCard('🔥', '$_streak', 'Day streak'),
    const SizedBox(width: 10),
    _statCard('📅', '$_weekCount', 'This week'),
    const SizedBox(width: 10),
    _statCard('⏱️', '${_totalMinutes}m', 'Total time'),
  ]);

  Widget _statCard(String icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.card,
          borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: AppColors.textPrimary,
            fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _barChart() {
    final entries = _byEquipment.entries.take(5).toList();
    final maxVal = entries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b).toDouble();
    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal + 1,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 28,
            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 36,
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
          )),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.cardLight, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((entry) => BarChartGroupData(
          x: entry.key,
          barRods: [BarChartRodData(
            toY: entry.value.value.toDouble(),
            color: AppColors.primary,
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          )],
        )).toList(),
      )),
    );
  }

  Widget _workoutTile(WorkoutSession s) {
    return Dismissible(
      key: Key('w-${s.id}-${s.timestamp}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        bool confirmed = false;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Delete workout?',
                style: TextStyle(color: AppColors.textPrimary)),
            content: Text('Remove ${s.equipmentName} (${s.durationMinutes} min)?',
                style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () { confirmed = true; Navigator.pop(context); },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed;
      },
      onDismissed: (_) => _deleteWorkout(s),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: GestureDetector(
        onLongPress: () => _showEditSheet(s),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.fitness_center, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.equipmentName,
                    style: const TextStyle(color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text('${s.durationMinutes} min · ${s.dateLabel}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                if (s.notes.isNotEmpty)
                  Text(s.notes,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
            const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 18),
          ]),
        ),
      ),
    );
  }
}
