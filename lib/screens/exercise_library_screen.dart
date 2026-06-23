import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../utils/app_theme.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final String? initialMuscle;    // Pre-filter from profile/goal
  final bool standalone;

  const ExerciseLibraryScreen({
    super.key,
    this.initialMuscle,
    this.standalone = false,
  });

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();

  String _query = '';
  String? _selectedMuscle;
  String? _selectedEquipment;
  String? _selectedLevel;

  List<Exercise> _results = [];
  Map<String, List<Exercise>> _byMuscle = {};
  bool _loaded = false;
  // UC-07 exception: fuzzy suggestion when query returns no results
  String? _suggestion;

  static const _muscleOrder = [
    'chest', 'lats', 'middle back', 'lower back',
    'shoulders', 'biceps', 'triceps', 'forearms',
    'quadriceps', 'hamstrings', 'glutes', 'calves',
    'abdominals', 'hip flexors',
  ];

  static const _muscleIcons = {
    'chest': '🫁', 'lats': '🔙', 'middle back': '🔙',
    'lower back': '🔙', 'shoulders': '💪', 'biceps': '💪',
    'triceps': '💪', 'forearms': '🤛', 'quadriceps': '🦵',
    'hamstrings': '🦵', 'glutes': '🍑', 'calves': '🦵',
    'abdominals': '🫁', 'hip flexors': '🦵',
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _selectedMuscle = widget.initialMuscle;
    _init();
  }

  Future<void> _init() async {
    await ExerciseService().load();
    _refresh();
    setState(() {
      _byMuscle = ExerciseService().byMuscle;
      _loaded = true;
    });
  }

  void _refresh() {
    final results = ExerciseService().search(
      query: _query,
      muscle: _selectedMuscle,
      equipment: _selectedEquipment,
      level: _selectedLevel,
    );
    setState(() {
      _results = results;
      _suggestion = (results.isEmpty && _query.isNotEmpty)
          ? _findSuggestion(_query)
          : null;
    });
  }

  /// UC-07 exception scenario: "Did you mean [X]?" when search returns nothing.
  String? _findSuggestion(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;
    String? best;
    int bestDist = 999;
    for (final e in ExerciseService().all) {
      final name = e.name.toLowerCase();
      // Check full name distance and each individual word distance
      for (final token in [name, ...name.split(' ')]) {
        final d = _editDistance(q, token);
        // Threshold: allow up to 40% of query length in edits
        if (d < bestDist && d <= (q.length * 0.5).ceil()) {
          bestDist = d;
          best = e.name;
        }
      }
    }
    return best;
  }

  int _editDistance(String s, String t) {
    final m = s.length, n = t.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) { d[i][0] = i; }
    for (var j = 0; j <= n; j++) { d[0][j] = j; }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        d[i][j] = s[i - 1] == t[j - 1]
            ? d[i - 1][j - 1]
            : 1 + [d[i - 1][j], d[i][j - 1], d[i - 1][j - 1]]
                .reduce((a, b) => a < b ? a : b);
      }
    }
    return d[m][n];
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _selectedMuscle = null;
      _selectedEquipment = null;
      _selectedLevel = null;
    });
    _refresh();
  }

  bool get _hasFilters =>
      _query.isNotEmpty ||
      _selectedMuscle != null ||
      _selectedEquipment != null ||
      _selectedLevel != null;

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Exercise Library'),
        automaticallyImplyLeading: widget.standalone,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'Search (${_results.length})'),
            const Tab(text: 'By Muscle'),
          ],
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabs,
              children: [_searchTab(), _byMuscleTab()],
            ),
    );
  }

  // ── Search Tab ────────────────────────────────────────────────────────────

  Widget _searchTab() {
    return Column(
      children: [
        _searchBar(),
        _filterChips(),
        if (_hasFilters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_results.length} exercises',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Clear filters'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fitness_center,
                          color: AppColors.textSecondary, size: 48),
                      const SizedBox(height: 12),
                      const Text('No exercises found',
                          style: TextStyle(color: AppColors.textSecondary)),
                      if (_suggestion != null) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.text = _suggestion!;
                            _query = _suggestion!;
                            _refresh();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search,
                                    color: AppColors.primary, size: 16),
                                const SizedBox(width: 8),
                                Text.rich(TextSpan(
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14),
                                  children: [
                                    const TextSpan(text: 'Did you mean: '),
                                    TextSpan(
                                      text: _suggestion,
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: '?'),
                                  ],
                                )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (_, i) => _ExerciseCard(
                    exercise: _results[i],
                    onTap: () => _openDetail(_results[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: AppColors.textPrimary),
        onChanged: (v) {
          _query = v;
          _refresh();
        },
        decoration: InputDecoration(
          hintText: 'Search exercises, muscles, equipment...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchCtrl.clear();
                    _query = '';
                    _refresh();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Muscle filter
          _FilterDropdown(
            label: _selectedMuscle ?? 'Muscle',
            icon: Icons.accessibility_new,
            active: _selectedMuscle != null,
            options: _muscleOrder
                .where((m) => ExerciseService().muscleGroups.contains(m))
                .toList(),
            onSelected: (v) {
              setState(() => _selectedMuscle = v == _selectedMuscle ? null : v);
              _refresh();
            },
          ),
          const SizedBox(width: 8),
          // Equipment filter
          _FilterDropdown(
            label: _selectedEquipment ?? 'Equipment',
            icon: Icons.fitness_center,
            active: _selectedEquipment != null,
            options: ExerciseService().equipmentTypes,
            onSelected: (v) {
              setState(() =>
                  _selectedEquipment = v == _selectedEquipment ? null : v);
              _refresh();
            },
          ),
          const SizedBox(width: 8),
          // Level filter
          _FilterDropdown(
            label: _selectedLevel ?? 'Level',
            icon: Icons.bar_chart,
            active: _selectedLevel != null,
            options: const ['beginner', 'intermediate', 'advanced'],
            onSelected: (v) {
              setState(
                  () => _selectedLevel = v == _selectedLevel ? null : v);
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  // ── By Muscle Tab ─────────────────────────────────────────────────────────

  Widget _byMuscleTab() {
    final orderedMuscles = _muscleOrder
        .where((m) => _byMuscle.containsKey(m))
        .toList();
    // Add any not in the order list
    for (final m in _byMuscle.keys) {
      if (!orderedMuscles.contains(m)) orderedMuscles.add(m);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orderedMuscles.length,
      itemBuilder: (_, i) {
        final muscle = orderedMuscles[i];
        final exercises = _byMuscle[muscle] ?? [];
        return _MuscleGroupSection(
          muscle: muscle,
          icon: _muscleIcons[muscle] ?? '💪',
          exercises: exercises,
          onExerciseTap: _openDetail,
        );
      },
    );
  }

  void _openDetail(Exercise e) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: e)),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;
  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 90,
                height: 80,
                child: e.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        e.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _FallbackThumb(e),
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : _FallbackThumb(e),
                      )
                    : _FallbackThumb(e),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(e.primaryMuscles.join(', '),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: e.levelColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(e.level,
                            style: TextStyle(
                                color: e.levelColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      Text('${e.equipmentIcon} ${e.equipment}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  final Exercise e;
  const _FallbackThumb(this.e);
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.cardLight,
        child: Center(
          child: Text(e.equipmentIcon,
              style: const TextStyle(fontSize: 28)),
        ),
      );
}

// ── Muscle group section ──────────────────────────────────────────────────

class _MuscleGroupSection extends StatefulWidget {
  final String muscle;
  final String icon;
  final List<Exercise> exercises;
  final void Function(Exercise) onExerciseTap;
  const _MuscleGroupSection({
    required this.muscle,
    required this.icon,
    required this.exercises,
    required this.onExerciseTap,
  });
  @override
  State<_MuscleGroupSection> createState() => _MuscleGroupSectionState();
}

class _MuscleGroupSectionState extends State<_MuscleGroupSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Text(widget.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.muscle[0].toUpperCase() +
                            widget.muscle.substring(1),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      Text('${widget.exercises.length} exercises',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
              ]),
            ),
          ),
          // Exercises
          if (_expanded)
            ...widget.exercises.map((e) => InkWell(
                  onTap: () => widget.onExerciseTap(e),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.cardLight, width: 1)),
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 54,
                        height: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: e.thumbnailUrl.isNotEmpty
                              ? Image.network(e.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _FallbackThumb(e))
                              : _FallbackThumb(e),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            Row(children: [
                              Text('${e.levelEmoji} ${e.level}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                              const Text(' · ',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                              Text(e.equipment,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                            ]),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary, size: 18),
                    ]),
                  ),
                )),
        ],
      ),
    );
  }
}

// ── Filter dropdown chip ──────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final List<String> options;
  final void Function(String) onSelected;

  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.active,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.cardLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.primary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 16,
                color: active ? AppColors.primary : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text('Select $label',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          ...options.map((o) => ListTile(
                title: Text(o[0].toUpperCase() + o.substring(1),
                    style: const TextStyle(color: AppColors.textPrimary)),
                trailing: o == label
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(o);
                },
              )),
        ],
      ),
    );
  }
}
