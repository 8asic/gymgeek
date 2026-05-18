import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/constants.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'services/equipment_service.dart';
import 'services/exercise_service.dart';
import 'services/tflite_service.dart';
import 'services/llm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load all services in parallel
  await Future.wait([
    EquipmentService().load(),
    ExerciseService().load(),
    TFLiteService().loadModel(),
    LLMService().loadResearchBase(),
  ]);

  runApp(const GymGeekApp());
}

class GymGeekApp extends StatelessWidget {
  const GymGeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymGeek',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GymGeek',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  CircularProgressIndicator(color: AppColors.primary),
                ],
              ),
            ),
          );
        }
        if (snap.data == true) return const HomeShell();
        return const LoginScreen();
      },
    );
  }

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }
}
