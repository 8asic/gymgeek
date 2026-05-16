import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/equipment.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';

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

  Equipment get eq => widget.equipment;

  Future<void> _openVideo() async {
    final uri = Uri.parse(eq.videoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video. Check internet connection.')),
        );
      }
    }
  }

  Future<void> _saveWorkout() async {
    final session = WorkoutSession(
      equipmentId: eq.id,
      equipmentName: eq.name,
      durationMinutes: _selectedDuration,
      notes: _notesCtrl.text.trim(),
      timestamp: DateTime.now(),
    );
    await DatabaseHelper().insertWorkout(session);
    await DatabaseHelper().logAuditEvent(
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

            // Instructional video button — UC-03
            const Text('Instructional Video',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _openVideo,
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
                    // Placeholder thumbnail
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
                    // Play button
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                    ),
                    // YouTube badge
                    Positioned(
                      bottom: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('YouTube', style: TextStyle(color: Colors.white, fontSize: 11)),
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
