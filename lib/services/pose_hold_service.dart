class PoseHoldService {
  int holdSeconds = 0;

  bool isCompleted = false;

  void reset() {
    holdSeconds = 0;
    isCompleted = false;
  }
}
