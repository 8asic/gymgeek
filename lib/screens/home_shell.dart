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
  final _camKey  = GlobalKey<CameraScreenState>();
  final _dashKey = GlobalKey<DashboardScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      CameraScreen(key: _camKey),
      const ExerciseLibraryScreen(),
      DashboardScreen(key: _dashKey),
      const ResearchScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTap(int i) {
    if (_index == 0 && i != 0) _camKey.currentState?.pause();
    if (_index != 0 && i == 0) _camKey.currentState?.resume();
    if (i == 2) _dashKey.currentState?.reload();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: GymGeekBottomNav(
        currentIndex: _index,
        onTap: _onTap,
      ),
    );
  }
}
