import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectionService {
  late PoseDetector poseDetector;

  PoseDetectionService() {
    poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
  }

  Future<List<Pose>> processImage(InputImage image) async {
    return await poseDetector.processImage(image);
  }

  Future<void> dispose() async {
    await poseDetector.close();
  }
}
