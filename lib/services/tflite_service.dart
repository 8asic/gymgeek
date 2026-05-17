import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'equipment_service.dart';
import '../models/equipment.dart';
import 'database_helper.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// ── Data classes ────────────────────────────────────────────────────────────

class LabelScore {
  final String label;
  final double score;
  LabelScore(this.label, this.score);
}

class DetectionResult {
  final Equipment? equipment;
  final double confidence;
  final String rawLabel;
  final bool isAboveThreshold;

  DetectionResult({
    this.equipment,
    required this.confidence,
    required this.rawLabel,
    required this.isAboveThreshold,
  });

  bool get detected => equipment != null && isAboveThreshold;
}

// ── Service ─────────────────────────────────────────────────────────────────

class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;
  bool _modelAvailable = false;

  // Last top-N results for the confidence breakdown sheet
  List<LabelScore> _lastTopResults = [];
  List<LabelScore> get lastTopResults => List.unmodifiable(_lastTopResults);

  // Feedback weights: label -> adjustment (-N..+N)
  // Stored in SharedPreferences so they persist across sessions
  Map<String, int> _feedbackWeights = {};

  bool get isLoaded => _isLoaded;
  bool get modelAvailable => _modelAvailable;

  // ── Load model ─────────────────────────────────────────────────────────

  Future<bool> loadModel() async {
    // Load persisted feedback weights
    await _loadFeedbackWeights();

    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      _labels = await _loadLabels();
      _isLoaded = true;
      _modelAvailable = true;
      debugPrint('✅ TFLite model loaded. Labels: ${_labels.length}');
      return true;
    } catch (e) {
      debugPrint('⚠️ TFLite model not found — running in demo mode. Error: $e');
      _isLoaded = true;
      _modelAvailable = false;
      return false;
    }
  }

  Future<List<String>> _loadLabels() async {
    try {
      final str = await rootBundle.loadString('assets/labels.txt');
      return str.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Feedback / reinforcement ────────────────────────────────────────────

  Future<void> _loadFeedbackWeights() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('fw_'));
    _feedbackWeights = {
      for (final k in keys) k.substring(3): prefs.getInt(k) ?? 0,
    };
  }

  /// Called when user confirms or denies a detection.
  /// Adjusts an in-memory (and persisted) weight for that label,
  /// which shifts confidence scores in future demo detections.
  Future<void> recordFeedback({required String label, required bool correct}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'fw_$label';
    final current = _feedbackWeights[label] ?? 0;
    final updated = correct ? (current + 1).clamp(-10, 10) : (current - 1).clamp(-10, 10);
    _feedbackWeights[label] = updated;
    await prefs.setInt(key, updated);
    debugPrint('📊 Feedback recorded: $label → weight $updated');
  }

  double _applyFeedbackWeight(String label, double rawScore) {
    final weight = _feedbackWeights[label] ?? 0;
    // Each feedback point shifts confidence by 1.5%, capped at ±15%
    final adjustment = weight * 0.015;
    return (rawScore + adjustment).clamp(0.0, 1.0);
  }

  // ── Main detect ────────────────────────────────────────────────────────

  Future<DetectionResult> detect(Uint8List imageBytes) async {
    if (!_modelAvailable) return _demoDetect(imageBytes);
    return _realDetect(imageBytes);
  }

  // ── Real TFLite inference ───────────────────────────────────────────────

  Future<DetectionResult> _realDetect(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Cannot decode image');

      final resized = img.copyResize(image, width: 224, height: 224);
      final inputTensor = _imageToFloat32List(resized);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape.last;
      final output = List.generate(1, (_) => List<double>.filled(numClasses, 0.0));

      _interpreter!.run(inputTensor, output);

      final scores = output[0];

      // Build sorted top-5 results
      final indexed = scores.asMap().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5 = indexed.take(5).toList();

      _lastTopResults = top5.map((e) {
        final lbl = e.key < _labels.length ? _labels[e.key] : 'class_${e.key}';
        return LabelScore(lbl, _applyFeedbackWeight(lbl, e.value));
      }).toList();

      final best = _lastTopResults.first;
      final equipment = EquipmentService().findByLabel(best.label);

      await DatabaseHelper().logAuditEvent(
        eventType: 'cv_detection',
        details: 'label=${best.label}, equipment=${equipment?.name ?? "none"}',
        confidence: best.score,
      );

      return DetectionResult(
        equipment: equipment,
        confidence: best.score,
        rawLabel: best.label,
        isAboveThreshold: best.score >= AppConstants.confidenceThreshold,
      );
    } catch (e) {
      debugPrint('Detection error: $e');
      return DetectionResult(
        equipment: null,
        confidence: 0,
        rawLabel: 'error',
        isAboveThreshold: false,
      );
    }
  }

  // ── Demo mode ───────────────────────────────────────────────────────────

  static int _demoIndex = 0;

  // All demo equipment with realistic "runner-up" alternatives
  static final _demoScenarios = [
    _DemoScenario('Treadmill',        [('Elliptical Trainer', 0.11), ('Stationary Bike', 0.06)]),
    _DemoScenario('Leg Press',        [('Barbell Squat Rack', 0.09), ('Smith Machine', 0.05)]),
    _DemoScenario('Bench Press',      [('Smith Machine', 0.10),      ('Dumbbell Rack', 0.07)]),
    _DemoScenario('Rowing Machine',   [('Cable Machine', 0.08),      ('Lat Pulldown', 0.05)]),
    _DemoScenario('Stationary Bike',  [('Treadmill', 0.09),          ('Elliptical Trainer', 0.06)]),
    _DemoScenario('Pull-up Bar',      [('Lat Pulldown', 0.12),       ('Cable Machine', 0.05)]),
    _DemoScenario('Lat Pulldown',     [('Cable Machine', 0.10),      ('Pull-up Bar', 0.07)]),
    _DemoScenario('Elliptical Trainer',[('Treadmill', 0.10),         ('Stationary Bike', 0.07)]),
  ];

  Future<DetectionResult> _demoDetect(Uint8List imageBytes) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final scenario = _demoScenarios[_demoIndex % _demoScenarios.length];
    _demoIndex++;

    // Base confidence with small variation
    final baseConf = 0.78 + (_demoIndex % 8) * 0.018;
    final topLabel = scenario.topLabel;
    final adjustedConf = _applyFeedbackWeight(topLabel, baseConf).clamp(0.0, 1.0);

    // Build top results list: winner + runner-ups
    _lastTopResults = [
      LabelScore(topLabel, adjustedConf),
      ...scenario.alternatives.map((a) =>
        LabelScore(a.$1, _applyFeedbackWeight(a.$1, a.$2))),
    ];

    final equipment = EquipmentService().findByLabel(topLabel);

    await DatabaseHelper().logAuditEvent(
      eventType: 'cv_detection_demo',
      details: 'label=$topLabel (demo)',
      confidence: adjustedConf,
    );

    return DetectionResult(
      equipment: equipment,
      confidence: adjustedConf,
      rawLabel: topLabel,
      isAboveThreshold: adjustedConf >= AppConstants.confidenceThreshold,
    );
  }

  // ── Image preprocessing ─────────────────────────────────────────────────

  List<List<List<List<double>>>> _imageToFloat32List(img.Image image) {
    return List.generate(1, (_) =>
      List.generate(224, (y) =>
        List.generate(224, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );
  }

  void dispose() {
    _interpreter?.close();
  }
}

class _DemoScenario {
  final String topLabel;
  final List<(String, double)> alternatives;
  const _DemoScenario(this.topLabel, this.alternatives);
}
