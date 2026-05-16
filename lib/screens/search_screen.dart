import 'package:flutter/material.dart';
import '../services/equipment_service.dart';
import '../models/equipment.dart';
import '../utils/constants.dart';
import '../widgets/equipment_card.dart';
import 'video_player_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool standalone; // true when pushed as a route rather than tab

  const SearchScreen({super.key, this.standalone = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Equipment> _results = [];
  bool _loaded = false;

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
              children: ['All', 'Cardio', 'Legs', 'Chest', 'Back', 'Full Body']
                  .map((g) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(g),
                          selected: false,
                          backgroundColor: AppColors.card,
                          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          onSelected: (_) {
                            _ctrl.text = g == 'All' ? '' : g;
                            _onSearch(g == 'All' ? '' : g);
                          },
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
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, color: AppColors.textSecondary, size: 48),
                            SizedBox(height: 12),
                            Text('No equipment found',
                                style: TextStyle(color: AppColors.textSecondary)),
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
