import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/goal.dart';
import '../services/database_helper.dart';
import '../services/equipment_service.dart';
import '../models/equipment.dart';
import '../utils/constants.dart';
import '../widgets/equipment_card.dart';
import 'video_player_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  FitnessGoal? _currentGoal;
  String _userEmail = '';
  bool _aiRecommendations = true;
  bool _gdprConsent = true;
  List<Equipment> _recommended = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final db = DatabaseHelper();
    final goal = await db.getCurrentGoal();
    final aiRec = await db.getSetting('ai_recommendations') ?? 'true';
    final gdpr = await db.getSetting('gdpr_consent') ?? 'true';

    List<Equipment> recs = [];
    if (goal != null) {
      await EquipmentService().load();
      recs = EquipmentService().filterByMuscleGroups(goal.goalType.recommendedMuscleGroups);
    }

    if (mounted) {
      setState(() {
        _currentGoal = goal;
        _userEmail = prefs.getString('user_email') ?? 'demo@gymgeek.app';
        _aiRecommendations = aiRec == 'true';
        _gdprConsent = gdpr == 'true';
        _recommended = recs;
        _loading = false;
      });
    }
  }

  Future<void> _saveGoal(GoalType type) async {
    final goal = FitnessGoal(
      goalType: type,
      startDate: DateTime.now(),
    );
    await DatabaseHelper().insertGoal(goal);
    await DatabaseHelper().logAuditEvent(
      eventType: 'goal_set',
      details: 'type=${type.name}',
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Goal set: ${type.label} ${type.icon}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _setAiRecommendations(bool val) async {
    await DatabaseHelper().setSetting('ai_recommendations', val.toString());
    setState(() => _aiRecommendations = val);
  }

  Future<void> _setGdprConsent(bool val) async {
    await DatabaseHelper().setSetting('gdpr_consent', val.toString());
    setState(() => _gdprConsent = val);
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete All Data', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will permanently delete all your workout history, goals, and audit logs. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper().deleteAllUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted (GDPR compliant)')),
        );
        _load();
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _userHeader(),
                  const SizedBox(height: 24),
                  _section('Fitness Goal', _goalSection()),
                  const SizedBox(height: 20),
                  if (_currentGoal != null && _recommended.isNotEmpty) ...[
                    _section('Recommended Equipment', _recommendedSection()),
                    const SizedBox(height: 20),
                  ],
                  _section('Privacy & AI Settings', _privacySection()),
                  const SizedBox(height: 28),
                  _logoutButton(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _userHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.primary,
          child: Text(
            _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : 'G',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_userEmail,
                  style: const TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis),
              if (_currentGoal != null)
                Text('Goal: ${_currentGoal!.goalType.icon} ${_currentGoal!.goalType.label}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  Widget _goalSection() {
    return Column(
      children: GoalType.values.map((type) {
        final selected = _currentGoal?.goalType == type;
        return GestureDetector(
          onTap: () => _saveGoal(type),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label,
                          style: const TextStyle(color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      Text(type.description,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _recommendedSection() {
    return Column(
      children: _recommended.take(3).map((eq) => EquipmentCard(
        equipment: eq,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VideoPlayerScreen(equipment: eq)),
        ),
      )).toList(),
    );
  }

  Widget _privacySection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _aiRecommendations,
            onChanged: _setAiRecommendations,
            activeColor: AppColors.primary,
            title: const Text('AI Recommendations',
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Personalised equipment suggestions based on your goal',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          const Divider(color: AppColors.cardLight, height: 1),
          SwitchListTile(
            value: _gdprConsent,
            onChanged: _setGdprConsent,
            activeColor: AppColors.primary,
            title: const Text('Data Storage Consent (GDPR)',
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Store workout history and goals locally on your device',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          const Divider(color: AppColors.cardLight, height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete All My Data',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('GDPR right to erasure — removes all local data',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            onTap: _deleteAllData,
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: AppColors.textSecondary, size: 18),
        label: const Text('Sign Out', style: TextStyle(color: AppColors.textSecondary)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.card),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}
