import '../models/pose_reference.dart';
import '../utils/cosine_similarity.dart';
import 'package:flutter/material.dart';

class PoseMatchResult {
  final String poseName;
  final double similarity;

  PoseMatchResult({required this.poseName, required this.similarity});
}

class PoseMatchService {
  static PoseMatchResult findBestMatch(
    List<double> currentVector,
    List<PoseReference> references,
  ) {
    double highestScore = 0;

    String bestPose = "";

    for (final pose in references) {
      if (pose.referenceVector.length != currentVector.length) {
        continue;
      }
      debugPrint("REFERENCE = ${pose.poseName}");
      final score =
          CosineSimilarity.calculate(currentVector, pose.referenceVector) * 100;

      if (score > highestScore) {
        highestScore = score;
        bestPose = pose.poseName;
      }
    }

    return PoseMatchResult(poseName: bestPose, similarity: highestScore);
  }
}
