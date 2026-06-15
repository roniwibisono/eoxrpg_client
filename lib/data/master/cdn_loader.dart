import 'dart:convert';

import 'package:flutter/services.dart';

class MasterDataLoader {
  MasterDataLoader();

  static Future<String> loadJson(String fileName) async {
    return rootBundle.loadString('assets/data/$fileName');
  }

  Future<Map<String, dynamic>> loadFile(String fileName) async {
    final raw = await rootBundle.loadString('assets/data/$fileName');
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
