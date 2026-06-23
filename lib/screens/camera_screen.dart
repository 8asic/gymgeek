import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/detection_service.dart';
import '../services/equipment_service.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import 'video_player_screen.dart';
import 'equipment_search_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  bool _processing = false;
  DetectionResult? _result;
  String _statusMsg = 'Point camera at gym equipment';
  Timer? _detectionTimer;
  Timer? _noDetectTimer;
  int _secondsWithoutDetect = 0;

  FlashMode _flashMode = FlashMode.off;

  double _scanBoxSize = 240;
  static const double _minBox = 100;
  static const double _maxBox = 360;
  double _scaleStart = 240;

  ScaffoldFeatureController? _activeSnack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    await EquipmentService().load();
    await DetectionService().loadModel();
    final cams = await availableCameras();
    if (cams.isEmpty) {
      if (mounted) setState(() => _statusMsg = 'No camera found on device');
      return;
    }
    _cameras = cams;
    await _startCamera(_cameras.first);

    _startTimers();
  }

  void _startTimers() {
    _detectionTimer?.cancel();
    _noDetectTimer?.cancel();
    _detectionTimer = Timer.periodic(
        const Duration(milliseconds: 2500), (_) => _runDetection());
    _noDetectTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_result == null || !_result!.detected) {
        _secondsWithoutDetect++;
        if (_secondsWithoutDetect >= AppConstants.noDetectionTimeoutSeconds) {
          if (mounted) {
            setState(() => _statusMsg =
                'No equipment detected — adjust camera or use Search ↓');
          }
        }
      } else {
        _secondsWithoutDetect = 0;
      }
    });
  }

  void _stopTimers() {
    _detectionTimer?.cancel();
    _noDetectTimer?.cancel();
    _detectionTimer = null;
    _noDetectTimer = null;
  }

  void pause() {
    _stopTimers();
    _camCtrl?.dispose();
    _camCtrl = null;
    if (mounted) setState(() => _initialized = false);
  }

  void resume() {
    if (_cameras.isNotEmpty && mounted) {
      _startCamera(_cameras.first).then((_) => _startTimers());
    }
  }

  Future<void> _startCamera(CameraDescription cam) async {
    await _camCtrl?.dispose();
    _camCtrl = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _camCtrl!.initialize();
      await _camCtrl!.setFlashMode(_flashMode);
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Camera error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flashMode) {
      FlashMode.off   => FlashMode.auto,
      FlashMode.auto  => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _               => FlashMode.off,
    };
    await _camCtrl?.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.off    => Icons.flash_off,
    FlashMode.auto   => Icons.flash_auto,
    FlashMode.always => Icons.flash_on,
    _                => Icons.flash_off,
  };

  Future<void> _runDetection() async {
    if (_processing || !(_camCtrl?.value.isInitialized ?? false)) return;
    _processing = true;
    try {
      final xfile = await _camCtrl!.takePicture();
      final bytes = await xfile.readAsBytes();
      final result = await DetectionService().detect(Uint8List.fromList(bytes));
      if (!mounted) return;
      setState(() {
        _result = result;
        if (result.detected) {
          _statusMsg = 'Detected: ${result.equipment!.name}';
          _secondsWithoutDetect = 0;
        } else if (result.confidence > 0 &&
            result.confidence < AppConstants.confidenceThreshold) {
          _statusMsg =
              'Low confidence (${(result.confidence * 100).toStringAsFixed(0)}%) — adjust camera';
        } else {
          _statusMsg = 'Scanning...';
        }
      });
    } finally {
      _processing = false;
    }
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

  void _showConfidenceSheet() {
    if (_result == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ConfidenceSheet(
        result: _result!,
        topResults: DetectionService().lastTopResults,
        onConfirm: () async {
          Navigator.pop(context);
          await DetectionService()
              .recordFeedback(label: _result!.rawLabel, correct: true);
          await DatabaseService().logAuditEvent(
            eventType: 'feedback_confirmed',
            details:
                'label=${_result!.rawLabel} equipment=${_result!.equipment?.name}',
            confidence: _result!.confidence,
          );
          _showSnack('✅ Confirmed — thanks for the feedback!',
              color: AppColors.success);
        },
        onDeny: () async {
          Navigator.pop(context);
          await DetectionService()
              .recordFeedback(label: _result!.rawLabel, correct: false);
          await DatabaseService().logAuditEvent(
            eventType: 'feedback_denied',
            details:
                'label=${_result!.rawLabel} equipment=${_result!.equipment?.name}',
            confidence: _result!.confidence,
          );
          _showSnack('❌ Noted — helps improve detection.',
              color: Colors.orange);
        },
      ),
    );
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    final current = _camCtrl?.description;
    final next =
        _cameras.firstWhere((c) => c != current, orElse: () => _cameras.first);
    setState(() => _initialized = false);
    await _startCamera(next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _camCtrl?.dispose();
      if (mounted) setState(() => _initialized = false);
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      _startCamera(_cameras.first);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectionTimer?.cancel();
    _noDetectTimer?.cancel();
    _camCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview — correct aspect ratio
          if (_initialized && _camCtrl != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _camCtrl!.value.previewSize!.height,
                  height: _camCtrl!.value.previewSize!.width,
                  child: CameraPreview(_camCtrl!),
                ),
              ),
            )
          else
            const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary)),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GymGeek',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Row(children: [
                      if (!DetectionService().modelAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('DEMO MODE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(_flashIcon, color: Colors.white),
                        tooltip: 'Flash: ${_flashMode.name}',
                        onPressed: _initialized ? _toggleFlash : null,
                      ),
                      // UC-07: manual equipment search
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        tooltip: 'Search equipment by name',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EquipmentSearchScreen(standalone: true),
                          ),
                        ),
                      ),
                      if (_cameras.length > 1) ...[
                        IconButton(
                          icon: const Icon(Icons.flip_camera_ios,
                              color: Colors.white),
                          onPressed: _switchCamera,
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // Pinch-to-resize scan box
          Center(
            child: GestureDetector(
              onScaleStart: (_) => _scaleStart = _scanBoxSize,
              onScaleUpdate: (d) => setState(() {
                _scanBoxSize =
                    (_scaleStart * d.scale).clamp(_minBox, _maxBox);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: _scanBoxSize,
                height: _scanBoxSize,
                decoration: BoxDecoration(
                  border:
                      Border.all(color: AppColors.primary, width: 2.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _processing
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2))
                    : null,
              ),
            ),
          ),

          // Hint below box
          Positioned(
            top: MediaQuery.of(context).size.height / 2 +
                _scanBoxSize / 2 +
                10,
            left: 0, right: 0,
            child: Center(
              child: Text('Pinch to resize frame',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11)),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.transparent
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_statusMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  if (_result != null && _result!.detected)
                    _DetectionCard(
                      result: _result!,
                      onViewInstructions: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                              equipment: _result!.equipment!),
                        ),
                      ),
                      onConfidenceTap: _showConfidenceSheet,
                    )
                  else ...[
                    ElevatedButton.icon(
                      onPressed: _runDetection,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Scan Now'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48)),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const EquipmentSearchScreen(standalone: true)),
                      ),
                      icon: const Icon(Icons.search,
                          color: Colors.white60, size: 18),
                      label: const Text('Search manually instead',
                          style: TextStyle(color: Colors.white60)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detection card ────────────────────────────────────────────────────────

class _DetectionCard extends StatelessWidget {
  final DetectionResult result;
  final VoidCallback onViewInstructions;
  final VoidCallback onConfidenceTap;
  const _DetectionCard({
    required this.result,
    required this.onViewInstructions,
    required this.onConfidenceTap,
  });

  @override
  Widget build(BuildContext context) {
    final eq = result.equipment!;
    final pct = (result.confidence * 100).toStringAsFixed(0);
    final confColor =
        result.confidence >= 0.85 ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(eq.muscleGroupIcon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(eq.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(5)),
                  child: const Text('AI',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
              Text(eq.muscleGroup,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
          GestureDetector(
            onTap: onConfidenceTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: confColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: confColor.withValues(alpha: 0.5)),
              ),
              child: Column(children: [
                Text('$pct%',
                    style: TextStyle(
                        color: confColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text('details',
                    style: TextStyle(
                        color: confColor.withValues(alpha: 0.7), fontSize: 9)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(eq.description,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: onViewInstructions,
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: const Text('View Instructions'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44)),
        ),
      ]),
    );
  }
}

// ── Confidence sheet ──────────────────────────────────────────────────────

class _ConfidenceSheet extends StatelessWidget {
  final DetectionResult result;
  final List<LabelScore> topResults;
  final VoidCallback onConfirm;
  final VoidCallback onDeny;
  const _ConfidenceSheet({
    required this.result,
    required this.topResults,
    required this.onConfirm,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final rows = topResults.isNotEmpty
        ? topResults
        : [LabelScore(result.rawLabel, result.confidence)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(2)),
        )),
        const Text('Detection Confidence',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Top predictions from CV model',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        ...rows.map((ls) => _ScoreRow(
              label: ls.label,
              score: ls.score,
              isTop: ls.label == result.rawLabel,
            )),
        const SizedBox(height: 16),
        const Divider(color: AppColors.cardLight),
        const SizedBox(height: 12),
        const Text('Was this identification correct?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        const SizedBox(height: 6),
        const Text(
            'Your feedback adjusts confidence scores for future detections.',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.thumb_up, size: 16),
              label: const Text('Yes, correct'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(0, 46)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onDeny,
              icon: const Icon(Icons.thumb_down, size: 16),
              label: const Text('No, wrong'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  minimumSize: const Size(0, 46)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final bool isTop;
  const _ScoreRow(
      {required this.label, required this.score, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final color =
        isTop ? AppColors.primary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight:
                      isTop ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              backgroundColor: AppColors.cardLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text('${(score * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
