import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/equipment.dart';
import '../models/workout_session.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Equipment equipment;

  const VideoPlayerScreen({super.key, required this.equipment});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _workoutSaved = false;
  int _selectedDuration = 30;
  final _notesCtrl = TextEditingController();
  // UC-03: index of currently selected instructional video
  int _selectedVideoIndex = 0;

  Equipment get eq => widget.equipment;

  Future<void> _openVideo([int? index]) async {
    final idx = index ?? _selectedVideoIndex;
    final urlStr = eq.videos.isNotEmpty ? eq.videos[idx]['url']! : eq.videoUrl;
    final uri = Uri.parse(urlStr);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open video: $urlStr')),
      );
    }
  }

  /// UC-03 alternative: show bottom sheet when multiple videos available
  void _pickVideo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Choose Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...eq.videos.asMap().entries.map((entry) {
            final i = entry.key;
            final v = entry.value;
            final selected = i == _selectedVideoIndex;
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              title: Text(
                v['title'] ?? 'Video ${i + 1}',
                style: TextStyle(
                  color: selected ? AppColors.primary : Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedVideoIndex = i);
                _openVideo(i);
              },
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _saveWorkout() async {
    final session = WorkoutSession(
      equipmentId: eq.id,
      equipmentName: eq.name,
      durationMinutes: _selectedDuration,
      notes: _notesCtrl.text.trim(),
      timestamp: DateTime.now(),
    );
    await DatabaseService().insertWorkout(session);
    await DatabaseService().logAuditEvent(
      eventType: 'workout_logged',
      details: 'equipment=${eq.name} duration=${_selectedDuration}min',
    );
    if (mounted) {
      setState(() => _workoutSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('${eq.name} workout saved!'),
          ]),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(eq.name),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Equipment header
            Row(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(eq.muscleGroupIcon,
                        style: const TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eq.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(eq.difficultyLabel,
                          style: const TextStyle(color: AppColors.textSecondary)),
                      Text(eq.muscleGroup,
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(eq.description,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
            ),
            const SizedBox(height: 20),

            // Instructional video — UC-03 (multi-video alternative scenario)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  eq.videos.length > 1
                      ? 'Instructional Videos (${eq.videos.length})'
                      : 'Instructional Video',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                if (eq.videos.length > 1)
                  TextButton.icon(
                    onPressed: () => _pickVideo(context),
                    icon: const Icon(Icons.list, size: 14),
                    label: const Text('Choose'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
              ],
            ),
            if (eq.videos.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Playing: ${eq.videos[_selectedVideoIndex]['title']}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: eq.videos.length > 1
                  ? () => _pickVideo(context)
                  : _openVideo,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.card),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        color: AppColors.card,
                        child: Center(
                          child: Text(eq.muscleGroupIcon,
                              style: const TextStyle(fontSize: 60)),
                        ),
                      ),
                    ),
                    Container(
                      width: 64, height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        eq.videos.length > 1
                            ? Icons.video_library
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    Positioned(
                      bottom: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: eq.videos.length > 1
                              ? AppColors.primary
                              : Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              eq.videos.length > 1
                                  ? '${eq.videos.length} videos'
                                  : 'YouTube',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tips
            const Text('Tips',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...eq.tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tip,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 28),

            // Log workout — UC-05
            const Text('Log This Workout',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Duration (minutes)',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [15, 30, 45, 60, 90].map((d) {
                      final selected = _selectedDuration == d;
                      return ChoiceChip(
                        label: Text('$d min'),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.cardLight,
                        labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.textSecondary),
                        onSelected: (_) => setState(() => _selectedDuration = d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _workoutSaved ? null : _saveWorkout,
                      icon: Icon(_workoutSaved ? Icons.check : Icons.save_outlined, size: 18),
                      label: Text(_workoutSaved ? 'Saved!' : 'Save Workout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _workoutSaved ? AppColors.success : AppColors.primary,
                        minimumSize: const Size(double.infinity, 46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
