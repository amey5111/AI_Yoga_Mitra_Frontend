import '../models/normalized_landmark.dart';

class PoseSimilarity {
  static List<double> landmarksToVector(List<NormalizedLandmark> landmarks) {
    final vector = <double>[];

    for (final landmark in landmarks) {
      vector.add(landmark.x);

      vector.add(landmark.y);
    }

    return vector;
  }
}
