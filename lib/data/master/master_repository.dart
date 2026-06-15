import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/error/failures.dart';

class MasterRepository {
  MasterRepository();

  final Map<String, dynamic> _cache = {};

  Future<Map<String, dynamic>> loadFile(String fileName) async {
    if (_cache.containsKey(fileName)) return _cache[fileName] as Map<String, dynamic>;
    final raw = await rootBundle.loadString('assets/data/$fileName');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _cache[fileName] = data;
    return data;
  }

  Future<Map<String, dynamic>> getConfig() => loadFile('config_baseline.json');
  Future<Map<String, dynamic>> getSkills() => loadFile('skills.json');
  Future<Map<String, dynamic>> getStatusEffects() => loadFile('status_effects.json');
  Future<Map<String, dynamic>> getClassTree() => loadFile('class_tree.json');
  Future<Map<String, dynamic>> getElementTable() => loadFile('element_table.json');
  Future<Map<String, dynamic>> getFactions() => loadFile('factions.json');
  Future<Map<String, dynamic>> getWorldMap() => loadFile('world_map.json');
  Future<Map<String, dynamic>> getNexusCity() => loadFile('nexus_city.json');
  Future<Map<String, dynamic>> getMonsterMaster() => loadFile('monster_master.json');
  Future<Map<String, dynamic>> getItems() => loadFile('items.json');
  Future<Map<String, dynamic>> getAllyMaster() => loadFile('ally_master.json');

  List<dynamic> getList(Map<String, dynamic> data, String key) {
    return (data[key] as List<dynamic>?) ?? [];
  }

  void clearCache() => _cache.clear();

  Future<int> getBaselineNumber(String key) async {
    final config = await getConfig();
    final value = _navigateJson(config, key);
    if (value is num) return value.toInt();
    throw CacheFailure('Config key $key not found or not a number');
  }

  Future<double> getBaselineDouble(String key) async {
    final config = await getConfig();
    final value = _navigateJson(config, key);
    if (value is num) return value.toDouble();
    throw CacheFailure('Config key $key not found or not a number');
  }

  dynamic _navigateJson(Map<String, dynamic> root, String dottedKey) {
    final parts = dottedKey.split('.');
    dynamic current = root;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }
}
