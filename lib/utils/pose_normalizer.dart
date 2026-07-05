import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/normalized_landmark.dart';

class PoseNormalizer {
  static List<NormalizedLandmark> normalize(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip]!;

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip]!;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]!;

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]!;

    final centerX = (leftHip.x + rightHip.x) / 2;

    final centerY = (leftHip.y + rightHip.y) / 2;

    final torsoLength = sqrt(
      pow(((leftShoulder.x + rightShoulder.x) / 2) - centerX, 2) +
          pow(((leftShoulder.y + rightShoulder.y) / 2) - centerY, 2),
    );

    final normalized = <NormalizedLandmark>[];

    for (final landmark in pose.landmarks.values) {
      normalized.add(
        NormalizedLandmark(
          x: (landmark.x - centerX) / torsoLength,

          y: (landmark.y - centerY) / torsoLength,
        ),
      );
    }

    return normalized;
  }
}
