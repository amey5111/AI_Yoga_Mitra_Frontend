import 'dart:math';

class CosineSimilarity {
  static double calculate(List<double> a, List<double> b) {
    if (a.length != b.length) {
      return 0;
    }

    double dot = 0;

    double normA = 0;

    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];

      normA += a[i] * a[i];

      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) {
      return 0;
    }

    return dot / (sqrt(normA) * sqrt(normB));
  }
}
