import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/equipment.dart';

class EquipmentService {
  static final EquipmentService _instance = EquipmentService._internal();
  factory EquipmentService() => _instance;
  EquipmentService._internal();

  List<Equipment> _equipment = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString('assets/equipment.json');
    final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
    _equipment = jsonList
        .map((e) => Equipment.fromJson(e as Map<String, dynamic>))
        .toList();
    _loaded = true;
  }

  List<Equipment> get all => List.unmodifiable(_equipment);

  /// Text search by name, description, muscle group
  List<Equipment> search(String query) {
    if (query.trim().isEmpty) return all;
    final q = query.toLowerCase();
    return _equipment.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q) ||
          e.muscleGroup.toLowerCase().contains(q) ||
          e.labels.any((l) => l.toLowerCase().contains(q));
    }).toList();
  }

  /// Find equipment by CV label (from TFLite model output)
  Equipment? findByLabel(String label) {
    final l = label.toLowerCase();
    for (final e in _equipment) {
      if (e.name.toLowerCase() == l) return e;
      if (e.labels.any((lbl) => lbl.toLowerCase() == l)) return e;
      if (e.labels.any((lbl) => lbl.toLowerCase().contains(l) || l.contains(lbl.toLowerCase()))) {
        return e;
      }
    }
    return null;
  }

  Equipment? findById(String id) {
    try {
      return _equipment.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Filter by muscle group
  List<Equipment> filterByMuscleGroups(List<String> groups) {
    if (groups.isEmpty) return all;
    return _equipment.where((e) => groups.contains(e.muscleGroup)).toList();
  }
}
