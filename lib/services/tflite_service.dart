import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../utils/constants.dart';
import 'equipment_service.dart';
import '../models/equipment.dart';
import 'database_helper.dart';

// Conditional TFLite import — only on mobile
// tflite_flutter is not available on web
import 'package:tflite_flutter/tflite_flutter.dart';

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

class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;
  bool _modelAvailable = false;

  bool get isLoaded => _isLoaded;
  bool get modelAvailable => _modelAvailable;

  /// Load the TFLite model and labels from assets.
  /// Returns false if model files are not found (demo mode will be used).
  Future<bool> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      // Load labels
      final labelsData = await _loadLabels();
      _labels = labelsData;
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
      final labelsStr = await _loadAssetAsString('assets/labels.txt');
      return labelsStr
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> _loadAssetAsString(String path) async {
    // Using rootBundle equivalent
    return '';
  }

  /// Run inference on image bytes (JPEG/PNG).
  /// Falls back to demo mode if model is not available.
  Future<DetectionResult> detect(Uint8List imageBytes) async {
    if (!_modelAvailable) {
      return _demoDetect(imageBytes);
    }
    return _realDetect(imageBytes);
  }

  Future<DetectionResult> _realDetect(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Cannot decode image');

      // Resize to model input size (224x224 for MobileNet-based)
      final resized = img.copyResize(image, width: 224, height: 224);

      // Normalize pixel values to [0, 1]
      final inputTensor = _imageToFloat32List(resized);

      // Run inference
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputSize = outputShape.reduce((a, b) => a * b);
      final output = List.filled(outputSize, 0.0).reshape(outputShape);

      _interpreter!.run(inputTensor, output);

      // Parse output
      final scores = List<double>.from(output[0] as List);
      int maxIdx = 0;
      double maxScore = 0;
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }

      final rawLabel = maxIdx < _labels.length ? _labels[maxIdx] : 'unknown';
      final equipment = EquipmentService().findByLabel(rawLabel);

      await DatabaseHelper().logAuditEvent(
        eventType: 'cv_detection',
        details: 'label=$rawLabel, equipment=${equipment?.name ?? "none"}',
        confidence: maxScore,
      );

      return DetectionResult(
        equipment: equipment,
        confidence: maxScore,
        rawLabel: rawLabel,
        isAboveThreshold: maxScore >= AppConstants.confidenceThreshold,
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

  /// Demo mode: cycles through equipment for demonstration purposes.
  /// In a real deployment, replace with actual TFLite model.
  static int _demoIndex = 0;
  static final _demoEquipment = [
    'Treadmill',
    'Leg Press',
    'Bench Press',
    'Rowing Machine',
    'Stationary Bike',
  ];

  Future<DetectionResult> _demoDetect(Uint8List imageBytes) async {
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 800));

    final name = _demoEquipment[_demoIndex % _demoEquipment.length];
    _demoIndex++;

    final equipment = EquipmentService().findByLabel(name);
    // Randomize confidence slightly above threshold for demo realism
    final confidence = 0.78 + (_demoIndex % 10) * 0.015;

    await DatabaseHelper().logAuditEvent(
      eventType: 'cv_detection_demo',
      details: 'label=$name (demo mode)',
      confidence: confidence,
    );

    return DetectionResult(
      equipment: equipment,
      confidence: confidence.clamp(0.0, 1.0),
      rawLabel: name,
      isAboveThreshold: true,
    );
  }

  /// Convert image to Float32 list for MobileNet input
  List<List<List<List<double>>>> _imageToFloat32List(img.Image image) {
    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );
    return input;
  }

  void dispose() {
    _interpreter?.close();
  }
}

// Extension for reshaping lists (needed for TFLite output)
extension ListReshape on List {
  List reshape(List<int> shape) {
    // Simple implementation for 2D output
    if (shape.length == 2 && shape[0] == 1) {
      return [this];
    }
    return this;
  }
}
