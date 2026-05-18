import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'camera_screen.dart';
import 'exercise_library_screen.dart';
import 'dashboard_screen.dart';
import 'research_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // IndexedStack keeps all screens alive — state preserved when switching tabs
  final _screens = const [
    CameraScreen(),
    ExerciseLibraryScreen(),   // replaces old flat SearchScreen
    DashboardScreen(),
    ResearchScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: GymGeekBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
