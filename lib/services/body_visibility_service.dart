import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BodyVisibilityResult {
  final bool isVisible;
  final String message;

  BodyVisibilityResult({required this.isVisible, required this.message});
}

class BodyVisibilityService {
  static BodyVisibilityResult validate(
    Pose pose,
    double imageWidth,
    double imageHeight,
  ) {
    final landmarks = pose.landmarks;

    final requiredPoints = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ];

    for (final type in requiredPoints) {
      final point = landmarks[type];

      if (point == null) {
        return BodyVisibilityResult(
          isVisible: false,
          message: "Full body not visible",
        );
      }

      if (point.x < 0 ||
          point.y < 0 ||
          point.x > imageWidth ||
          point.y > imageHeight) {
        return BodyVisibilityResult(
          isVisible: false,
          message: "Move fully inside frame",
        );
      }
    }

    return BodyVisibilityResult(isVisible: true, message: "Full body detected");
  }
}
