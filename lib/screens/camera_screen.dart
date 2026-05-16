import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/tflite_service.dart';
import '../services/equipment_service.dart';
import '../utils/constants.dart';
import '../models/equipment.dart';
import 'video_player_screen.dart';
import 'search_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  bool _processing = false;
  DetectionResult? _result;
  String _statusMsg = 'Point camera at gym equipment';
  Timer? _detectionTimer;
  Timer? _noDetectTimer;
  int _secondsWithoutDetect = 0;
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    await EquipmentService().load();
    final loaded = await TFLiteService().loadModel();
    setState(() => _modelLoaded = true);

    final cams = await availableCameras();
    if (cams.isEmpty) {
      setState(() => _statusMsg = 'No camera found on device');
      return;
    }
    _cameras = cams;
    await _startCamera(_cameras.first);

    // Start periodic detection every 2 seconds
    _detectionTimer = Timer.periodic(const Duration(seconds: 2), (_) => _runDetection());

    // No-detection timeout
    _noDetectTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_result == null || !_result!.detected) {
        _secondsWithoutDetect++;
        if (_secondsWithoutDetect >= AppConstants.noDetectionTimeoutSeconds) {
          setState(() => _statusMsg = 'No equipment detected — try adjusting camera or use Search');
        }
      } else {
        _secondsWithoutDetect = 0;
      }
    });
  }

  Future<void> _startCamera(CameraDescription cam) async {
    _camCtrl = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _camCtrl!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      setState(() => _statusMsg = 'Camera error: $e');
    }
  }

  Future<void> _runDetection() async {
    if (_processing || _camCtrl == null || !_camCtrl!.value.isInitialized) return;
    _processing = true;
    try {
      final xfile = await _camCtrl!.takePicture();
      final bytes = await xfile.readAsBytes();
      final result = await TFLiteService().detect(Uint8List.fromList(bytes));
      if (mounted) {
        setState(() {
          _result = result;
          if (result.detected) {
            _statusMsg = 'Detected: ${result.equipment!.name}';
          } else if (result.confidence > 0 && result.confidence < AppConstants.confidenceThreshold) {
            _statusMsg = 'Low confidence (${(result.confidence * 100).toStringAsFixed(0)}%) — adjust camera';
          }
        });
      }
    } finally {
      _processing = false;
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    final current = _camCtrl?.description;
    final next = _cameras.firstWhere((c) => c != current, orElse: () => _cameras.first);
    await _camCtrl?.dispose();
    await _startCamera(next);
  }

  void _goToSearch() {
    // Navigate sibling tab — handled by HomeShell via callback
    // For simplicity we push a new search screen
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen(standalone: true)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _camCtrl?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameras.isNotEmpty) _startCamera(_cameras.first);
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
          // Camera preview
          if (_initialized && _camCtrl != null)
            Positioned.fill(
              child: CameraPreview(_camCtrl!),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GymGeek',
                        style: TextStyle(color: Colors.white, fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    if (!TFLiteService().modelAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('DEMO MODE',
                            style: TextStyle(color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    if (_cameras.length > 1)
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                        onPressed: _switchCamera,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Scanning frame overlay
          Center(
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _processing
                  ? const Center(child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
                  : null,
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
                  colors: [Colors.black.withOpacity(0.95), Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status message
                  Text(_statusMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),

                  // Detection result card
                  if (_result != null && _result!.detected)
                    _DetectionCard(
                      result: _result!,
                      onViewInstructions: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VideoPlayerScreen(equipment: _result!.equipment!),
                        ),
                      ),
                    )
                  else ...[
                    ElevatedButton.icon(
                      onPressed: _runDetection,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Scan Now'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _goToSearch,
                      icon: const Icon(Icons.search, color: Colors.white60, size: 18),
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

class _DetectionCard extends StatelessWidget {
  final DetectionResult result;
  final VoidCallback onViewInstructions;

  const _DetectionCard({required this.result, required this.onViewInstructions});

  @override
  Widget build(BuildContext context) {
    final eq = result.equipment!;
    final pct = (result.confidence * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(eq.muscleGroupIcon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(eq.name,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('AI',
                              style: TextStyle(color: Colors.white, fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text(eq.muscleGroup,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Text('$pct%',
                  style: TextStyle(
                    color: result.confidence >= 0.85 ? AppColors.success : AppColors.warning,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Text(eq.description,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onViewInstructions,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('View Instructions'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44)),
          ),
        ],
      ),
    );
  }
}
