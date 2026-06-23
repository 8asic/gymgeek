import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';

class EquipmentCard extends StatelessWidget {
  final Equipment equipment;
  final VoidCallback? onTap;
  final bool showBadge;
  final double? confidence;

  const EquipmentCard({
    super.key,
    required this.equipment,
    this.onTap,
    this.showBadge = false,
    this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: showBadge
              ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.cardLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    equipment.muscleGroupIcon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          equipment.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (showBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      equipment.muscleGroup,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (confidence != null) ...[
                      const SizedBox(height: 6),
                      _ConfidenceBar(confidence: confidence!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Difficulty + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    equipment.difficultyLabel,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  const _ConfidenceBar({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toStringAsFixed(0);
    final color = confidence >= 0.85
        ? AppColors.success
        : confidence >= AppConstants.confidenceThreshold
            ? AppColors.warning
            : Colors.red;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0),
              backgroundColor: AppColors.cardLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$pct%',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
