import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/workout_set.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});
  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  Exercise get ex => widget.exercise;
  List<WorkoutSet> _history = [];
  PersonalRecord? _pr;
  bool _loading = true;
  int _imageIndex = 0;
  ScaffoldFeatureController? _activeSnack;

  // Current set inputs
  double _weight = 0;
  int _reps = 10;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final sets = await DatabaseHelper().getSetsForExercise(ex.id, limit: 20);
    final prs = await DatabaseHelper().getPersonalRecords();
    PersonalRecord? myPr;
    try {
      myPr = prs.firstWhere((p) => p.exerciseId == ex.id);
    } catch (_) {}
    if (mounted) setState(() { _history = sets; _pr = myPr; _loading = false; });
  }

  Future<void> _logSet() async {
    final isPR = await DatabaseHelper().isNewPR(WorkoutSet(
      exerciseId: ex.id,
      exerciseName: ex.name,
      setNumber: _history.where((s) =>
          s.timestamp.day == DateTime.now().day).length + 1,
      weightKg: _weight,
      reps: _reps,
      timestamp: DateTime.now(),
    ));

    final set = WorkoutSet(
      exerciseId: ex.id,
      exerciseName: ex.name,
      setNumber: _history.where((s) =>
          s.timestamp.day == DateTime.now().day).length + 1,
      weightKg: _weight,
      reps: _reps,
      timestamp: DateTime.now(),
    );
    await DatabaseHelper().insertSet(set);
    await DatabaseHelper().logAuditEvent(
      eventType: 'set_logged',
      details: 'exercise=${ex.id} weight=$_weight reps=$_reps isPR=$isPR',
    );

    _loadHistory();

    if (isPR) {
      _showSnack('🏆 New Personal Record! ${set.display}', color: AppColors.primary);
    } else {
      _showSnack('Set logged: ${set.display}', color: AppColors.success);
    }
  }

  void _showSnack(String msg, {Color? color}) {
    if (!mounted) return;
    _activeSnack?.close();
    _activeSnack = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? AppColors.card,
      duration: const Duration(seconds: 3),
    ));
  }

  void _show1RMSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OneRMSheet(weight: _weight, reps: _reps),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar with animated image ─────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: ex.images.isNotEmpty
                  ? GestureDetector(
                      onTap: () => setState(() =>
                          _imageIndex = (_imageIndex + 1) % ex.images.length),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Image.network(
                          ex.images[_imageIndex],
                          key: ValueKey(_imageIndex),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.card,
                            child: Center(child: Text(ex.equipmentIcon,
                                style: const TextStyle(fontSize: 64))),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.card,
                      child: Center(child: Text(ex.equipmentIcon,
                          style: const TextStyle(fontSize: 64)))),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badges
                  Row(children: [
                    Expanded(child: Text(ex.name,
                        style: const TextStyle(color: AppColors.textPrimary,
                            fontSize: 22, fontWeight: FontWeight.bold))),
                    if (ex.images.length > 1)
                      Text('Tap image for animation',
                          style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.6),
                              fontSize: 10)),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _Badge(ex.level, ex.levelColor),
                    _Badge(ex.equipment, AppColors.textSecondary),
                    _Badge(ex.mechanic, AppColors.textSecondary),
                    if (_pr != null)
                      _Badge('PR: ${_pr!.weightKg}kg×${_pr!.reps}',
                          AppColors.primary),
                  ]),
                  const SizedBox(height: 20),

                  // Muscles
                  _sectionTitle('Muscles Targeted'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    ...ex.primaryMuscles.map((m) =>
                        _Badge(m, AppColors.primary, isPrimary: true)),
                    ...ex.secondaryMuscles.map((m) =>
                        _Badge(m, AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 24),

                  // Instructions
                  _sectionTitle('How To Do It'),
                  const SizedBox(height: 10),
                  ...ex.instructions.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(child: Text('${entry.key + 1}',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 12, fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.value,
                            style: const TextStyle(color: AppColors.textPrimary,
                                fontSize: 14, height: 1.5))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 24),

                  // Log a set
                  _sectionTitle('Log a Set'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(children: [
                      Row(children: [
                        // Weight
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Weight (kg)',
                                style: TextStyle(color: AppColors.textSecondary,
                                    fontSize: 12)),
                            const SizedBox(height: 6),
                            Row(children: [
                              _StepButton(
                                icon: Icons.remove,
                                onTap: () => setState(() =>
                                    _weight = (_weight - 2.5).clamp(0, 999)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                _weight == 0
                                    ? 'BW'
                                    : '${_weight.toStringAsFixed(1)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              )),
                              const SizedBox(width: 8),
                              _StepButton(
                                icon: Icons.add,
                                onTap: () => setState(() => _weight += 2.5),
                              ),
                            ]),
                          ],
                        )),
                        const SizedBox(width: 20),
                        // Reps
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Reps',
                                style: TextStyle(color: AppColors.textSecondary,
                                    fontSize: 12)),
                            const SizedBox(height: 6),
                            Row(children: [
                              _StepButton(
                                icon: Icons.remove,
                                onTap: () => setState(() =>
                                    _reps = (_reps - 1).clamp(1, 999)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('$_reps',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              )),
                              const SizedBox(width: 8),
                              _StepButton(
                                icon: Icons.add,
                                onTap: () => setState(() => _reps++),
                              ),
                            ]),
                          ],
                        )),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: ElevatedButton.icon(
                          onPressed: _logSet,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Log Set'),
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 46)),
                        )),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _show1RMSheet,
                          icon: const Icon(Icons.calculate_outlined,
                              size: 16, color: AppColors.textSecondary),
                          label: const Text('1RM',
                              style: TextStyle(color: AppColors.textSecondary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.cardLight),
                            minimumSize: const Size(0, 46),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // History
                  if (_history.isNotEmpty) ...[
                    _sectionTitle('Recent History'),
                    const SizedBox(height: 10),
                    ..._history.take(10).map((s) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Text('Set ${s.setNumber}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text(s.display,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('1RM ~${s.estimated1RM.toStringAsFixed(0)}kg',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(width: 8),
                        Text(s.dateLabel,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ]),
                    )),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(color: AppColors.textPrimary,
          fontSize: 16, fontWeight: FontWeight.bold));
}

// ── 1RM Sheet ─────────────────────────────────────────────────────────────

class _OneRMSheet extends StatelessWidget {
  final double weight;
  final int reps;
  const _OneRMSheet({required this.weight, required this.reps});

  @override
  Widget build(BuildContext context) {
    final e1rm = weight > 0 ? weight * (1 + reps / 30.0) : 0.0;
    final pcts = [100, 95, 90, 85, 80, 75, 70, 65, 60];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.cardLight,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('1-Rep Max Calculator',
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Based on ${weight.toStringAsFixed(1)}kg × $reps reps (Epley formula)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text('Estimated 1RM: ${e1rm.toStringAsFixed(1)} kg',
              style: const TextStyle(color: AppColors.primary,
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Divider(color: AppColors.cardLight),
          const SizedBox(height: 12),
          ...pcts.map((p) {
            final load = (e1rm * p / 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 50,
                    child: Text('$p%', style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13))),
                Expanded(child: LinearProgressIndicator(
                  value: p / 100,
                  backgroundColor: AppColors.cardLight,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                )),
                const SizedBox(width: 12),
                SizedBox(width: 60,
                    child: Text('${load.toStringAsFixed(1)}kg',
                        style: const TextStyle(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600, fontSize: 13))),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isPrimary;
  const _Badge(this.label, this.color, {this.isPrimary = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(isPrimary ? 0.15 : 0.08),
      borderRadius: BorderRadius.circular(8),
      border: isPrimary ? Border.all(color: color.withOpacity(0.3)) : null,
    ),
    child: Text(label[0].toUpperCase() + label.substring(1),
        style: TextStyle(color: color, fontSize: 12,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal)),
  );
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.textPrimary, size: 18),
    ),
  );
}

// Reuse dateLabel from WorkoutSession-like
extension _SetDate on WorkoutSet {
  String get dateLabel {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
