import 'package:flutter/material.dart';
import '../services/equipment_service.dart';
import '../models/equipment.dart';
import '../utils/app_theme.dart';
import '../widgets/equipment_card.dart';
import 'video_player_screen.dart';

class EquipmentSearchScreen extends StatefulWidget {
  final bool standalone; // true when pushed as a route rather than tab

  const EquipmentSearchScreen({super.key, this.standalone = false});

  @override
  State<EquipmentSearchScreen> createState() => _EquipmentSearchScreenState();
}

class _EquipmentSearchScreenState extends State<EquipmentSearchScreen> {
  final _ctrl = TextEditingController();
  List<Equipment> _results = [];
  bool _loaded = false;
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await EquipmentService().load();
    setState(() {
      _results = EquipmentService().all;
      _loaded = true;
    });
  }

  void _onSearch(String query) {
    setState(() => _results = EquipmentService().search(query));
  }

  void _applyFilter(String group) {
    setState(() => _activeFilter = group);
    _ctrl.text = group == 'All' ? '' : group;
    _onSearch(group == 'All' ? '' : group);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search Equipment'),
        automaticallyImplyLeading: widget.standalone,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _ctrl,
              onChanged: _onSearch,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search by name, muscle group...',
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              ),
            ),
          ),

          // Filter chips by muscle group
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: ['All', 'Cardio', 'Legs', 'Chest', 'Back', 'Full Body', 'Shoulders', 'Arms', 'Core']
                  .map((g) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(g),
                          selected: _activeFilter == g,
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primary,
                          backgroundColor: AppColors.card,
                          labelStyle: TextStyle(
                            color: _activeFilter == g ? AppColors.primary : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          onSelected: (_) => _applyFilter(g),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  _loaded ? '${_results.length} equipment found' : 'Loading...',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),

          // Results list
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, color: AppColors.textSecondary, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No equipment found.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Try different keywords or use camera',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Use Camera'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) {
                          final eq = _results[i];
                          return EquipmentCard(
                            equipment: eq,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => VideoPlayerScreen(equipment: eq)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
