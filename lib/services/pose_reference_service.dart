import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/pose_reference.dart';

class PoseReferenceService {
  static Future<List<PoseReference>> loadReferences() async {
    try {
      print("LOADING JSON...");

      final jsonString = await rootBundle.loadString(
        'assets/data/pose_reference_data.json',
      );

      print("JSON LOADED");

      final List<dynamic> jsonData = jsonDecode(jsonString);

      print("TOTAL REFERENCES = ${jsonData.length}");

      return jsonData.map((e) => PoseReference.fromJson(e)).toList();
    } catch (e) {
      print("REFERENCE LOAD ERROR = $e");

      rethrow;
    }
  }
}
