// Basic smoke test — verifies the app's models behave sanely.
// (The full app depends on platform plugins and network, which are
// exercised on-device rather than in widget tests.)

import 'package:flutter_test/flutter_test.dart';

import 'package:yoga_mitra/models/goals.dart';
import 'package:yoga_mitra/models/health_info.dart';
import 'package:yoga_mitra/models/user_profile.dart';

void main() {
  test('UserProfile serializes to JSON', () {
    final profile = UserProfile(userId: '1', name: 'Test', email: 't@t.com');
    final json = profile.toJson();
    expect(json['userId'], '1');
    expect(json['name'], 'Test');
    expect(json['email'], 't@t.com');
  });

  test('HealthInfo serializes to JSON', () {
    final info = HealthInfo(
      height: 65,
      weight: 70,
      medicalConditions: ['Diabetes'],
    );
    final json = info.toJson();
    expect(json['height'], 65);
    expect(json['weight'], 70);
    expect(json['medical_conditions'], ['Diabetes']);
  });

  test('Goals serializes to JSON with defaults', () {
    final goals = Goals();
    final json = goals.toJson();
    expect(json['routine_duration'], 30);
    expect(json['focus_body_parts'], isEmpty);
    expect(json['tags'], isEmpty);
  });
}
