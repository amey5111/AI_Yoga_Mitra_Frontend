import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:typed_data';
import '../models/normalized_landmark.dart';
import '../utils/pose_normalizer.dart';
import '../models/pose_reference.dart';
import '../services/pose_reference_service.dart';
import '../utils/cosine_similarity.dart';

import '../services/pose_detection_service.dart';
import '../widgets/pose_painter.dart';

import '../services/pose_match_service.dart';
import 'package:flutter/services.dart';
import '../services/body_visibility_service.dart';
import '../services/pose_hold_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'pose_result_screen.dart';

class PoseDetectionScreen extends StatefulWidget {
  final int poseId;
  final String poseName;

  const PoseDetectionScreen({
    super.key,
    required this.poseId,
    required this.poseName,
  });

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen> {
  CameraController? _cameraController;

  late PoseDetectionService _poseService;

  Pose? detectedPose;

  bool isBusy = false;

  bool isInitialized = false;

  int landmarkCount = 0;

  List<double> currentVector = [];

  List<NormalizedLandmark> normalizedLandmarks = [];

  List<PoseReference> references = [];

  double similarity = 0;

  String matchedPose = "";

  bool referencesLoaded = false;

  String bestMatchPose = "";

  double bestMatchScore = 0;

  bool isBodyVisible = false;

  String bodyStatus = "Searching...";

  final List<double> scoreHistory = [];

  double smoothedSimilarity = 0;

  DateTime? lastProcessedTime;

  final PoseHoldService holdService = PoseHoldService();

  int currentHoldTime = 0;

  bool poseCompleted = false;

  Timer? holdTimer;

  // ── Session metrics for AI post-session feedback ─────────────────────────
  double _sessionSumSim = 0;
  int _sessionCountSim = 0;
  double _sessionBestSim = 0;
  int _sessionFrames = 0;
  int _sessionVisFails = 0;
  int _maxHoldReached = 0;
  bool _finishing = false;

  double get holdProgress {
    return currentHoldTime / 15;
  }

  void startHoldTimer() {
    if (holdTimer != null) return;

    holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        currentHoldTime++;

        if (currentHoldTime > _maxHoldReached) _maxHoldReached = currentHoldTime;

        if (currentHoldTime >= 15) {
          poseCompleted = true;

          timer.cancel();
        }
      });
    });
  }

  void stopHoldTimer() {
    holdTimer?.cancel();

    holdTimer = null;

    currentHoldTime = 0;
  }

  void updateSimilarity(double newScore) {
    scoreHistory.add(newScore);

    if (scoreHistory.length > 10) {
      scoreHistory.removeAt(0);
    }

    smoothedSimilarity =
        scoreHistory.reduce((a, b) => a + b) / scoreHistory.length;

    if (smoothedSimilarity >= 80) {
      startHoldTimer();
    } else {
      poseCompleted = false;

      stopHoldTimer();
    }
  }

  Future<void> _loadReferences() async {
    try {
      debugPrint("LOADING REFERENCES...");

      references = await PoseReferenceService.loadReferences();

      debugPrint("REFERENCES LOADED = ${references.length}");

      if (references.isNotEmpty) {
        debugPrint("FIRST POSE = ${references.first.poseName}");
      }

      referencesLoaded = true;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("REFERENCE LOAD ERROR = $e");
    }
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final int ySize = width * height;
    final int uvSize = width * height ~/ 4;

    final Uint8List nv21 = Uint8List(ySize + uvSize * 2);

    // Copy Y plane
    nv21.setRange(0, ySize, image.planes[0].bytes);

    int index = ySize;

    final Uint8List uBytes = image.planes[1].bytes;

    final Uint8List vBytes = image.planes[2].bytes;

    for (int i = 0; i < uvSize; i++) {
      nv21[index++] = vBytes[i];
      nv21[index++] = uBytes[i];
    }

    return nv21;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _debugManifest();
    _loadReferences();
    _initialize();
  }

  Future<void> _debugManifest() async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    debugPrint(manifest);
  }

  Future<void> _initialize() async {
    try {
      _poseService = PoseDetectionService();

      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      debugPrint("SENSOR ORIENTATION = ${frontCamera.sensorOrientation}");

      await _cameraController!.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (isBusy) return;
    final now = DateTime.now();

    if (lastProcessedTime != null &&
        now.difference(lastProcessedTime!).inMilliseconds < 300) {
      return;
    }

    lastProcessedTime = now;

    isBusy = true;

    try {
      final nv21Bytes = _convertYUV420ToNV21(image);

      final inputImage = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      final poses = await _poseService.processImage(inputImage);

      debugPrint("POSE COUNT = ${poses.length}");

      if (poses.isNotEmpty) {
        detectedPose = poses.first;

        final visibilityResult = BodyVisibilityService.validate(
          detectedPose!,
          image.width.toDouble(),
          image.height.toDouble(),
        );

        isBodyVisible = visibilityResult.isVisible;

        bodyStatus = visibilityResult.message;

        _sessionFrames++;
        if (!isBodyVisible) _sessionVisFails++;

        landmarkCount = detectedPose!.landmarks.length;

        normalizedLandmarks = PoseNormalizer.normalize(detectedPose!);

        currentVector = normalizedLandmarks
            .map((e) => [e.x, e.y])
            .expand((e) => e)
            .toList();

        final result = PoseMatchService.findBestMatch(
          currentVector,
          references,
        );

        bestMatchPose = result.poseName;

        bestMatchScore = result.similarity;

        if (isBodyVisible && referencesLoaded && currentVector.length == 66) {
          if (!isBodyVisible) {
            similarity = 0;
            matchedPose = "";
            bestMatchPose = "";
            bestMatchScore = 0;

            if (mounted) {
              setState(() {});
            }

            isBusy = false;
            return;
          }
          try {
            debugPrint("SCREEN POSE = ${widget.poseName}");
            final selectedPose = references.firstWhere(
              (pose) =>
                  pose.poseName.toLowerCase() == widget.poseName.toLowerCase(),
            );

            if (selectedPose.referenceVector.length == currentVector.length) {
              similarity =
                  CosineSimilarity.calculate(
                    currentVector,
                    selectedPose.referenceVector,
                  ) *
                  100;

              updateSimilarity(similarity);

              _sessionSumSim += similarity;
              _sessionCountSim++;
              if (similarity > _sessionBestSim) _sessionBestSim = similarity;

              matchedPose = selectedPose.poseName;
            }
          } catch (_) {
            // Pose reference not found yet
          }
        }

        debugPrint(
          "LANDMARKS = "
          "$landmarkCount",
        );

        debugPrint(
          "VECTOR SIZE = "
          "${currentVector.length}",
        );

        debugPrint("BODY DETECTED ✅");
      } else {
        debugPrint("NO BODY DETECTED ❌");
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e, stack) {
      debugPrint("POSE DETECTION ERROR = $e");

      debugPrint(stack.toString());
    }

    isBusy = false;
  }

  @override
  void dispose() {
    holdTimer?.cancel();

    // Return the app to portrait after leaving the (landscape) detector
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _cameraController?.dispose();

    _poseService.dispose();

    super.dispose();
  }

  // ── Finish the session and open AI post-session feedback ─────────────────
  Future<void> _finishSession() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    holdTimer?.cancel();
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}

    final avg = _sessionCountSim > 0 ? _sessionSumSim / _sessionCountSim : 0.0;
    final best = _sessionBestSim;
    final held = poseCompleted ? 15 : _maxHoldReached;
    final visRatio = _sessionFrames > 0 ? _sessionVisFails / _sessionFrames : 0.0;

    final mistakes = <String>[];
    if (!poseCompleted) {
      mistakes.add("Did not hold the pose for the full 15 seconds");
    }
    if (avg < 60 && _sessionCountSim > 0) {
      mistakes.add("Overall alignment stayed below target accuracy");
    }
    if (visRatio > 0.3) {
      mistakes.add("Full body was often not visible in the camera frame");
    }
    if (best >= 80 && avg < 60) {
      mistakes.add("Found the correct pose but struggled to hold it steadily");
    }

    final result = <String, dynamic>{
      'poseId': widget.poseId,
      'poseName': widget.poseName,
      'avgSimilarity': avg,
      'bestSimilarity': best,
      'durationAchieved': held,
      'targetDuration': 15,
      'completed': poseCompleted,
      'mistakes': mistakes,
      'level': 'beginner',
    };

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PoseResultScreen(results: [result]),
      ),
    );
  }

  String getPoseStatus(double score) {
    if (score >= 90) {
      return "Excellent";
    }

    if (score >= 80) {
      return "Good";
    }

    if (score >= 60) {
      return "Close";
    }

    return "Not Matching";
  }

  Color getPoseStatusColor(double score) {
    if (score >= 90) {
      return Colors.green;
    }

    if (score >= 80) {
      return Colors.lightGreen;
    }

    if (score >= 60) {
      return Colors.orange;
    }

    return Colors.red;
  }

  Widget _buildLandscapeInfoPanel() {
    return Positioned(
      top: 16,
      right: 16,
      bottom: 16,
      width: 300,
      child: Card(
        color: Colors.black87,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.poseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                bodyStatus,
                style: TextStyle(
                  color: isBodyVisible ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text("Similarity", style: TextStyle(color: Colors.white70)),

              Text(
                "${smoothedSimilarity.toStringAsFixed(1)}%",
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                getPoseStatus(smoothedSimilarity),
                style: TextStyle(
                  color: getPoseStatusColor(smoothedSimilarity),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 16),

              Text("Hold Time", style: TextStyle(color: Colors.white70)),

              Text(
                "$currentHoldTime / 15 sec",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              LinearProgressIndicator(value: holdProgress.clamp(0, 1)),

              const SizedBox(height: 16),

              if (poseCompleted)
                const Center(
                  child: Text(
                    "POSE COMPLETED ✅",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              const Divider(),

              Text(
                "Debug Information",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Landmarks: $landmarkCount",
                style: TextStyle(color: Colors.white70),
              ),

              Text(
                "Vector: ${currentVector.length}",
                style: TextStyle(color: Colors.white70),
              ),

              Text(
                "Matched: $matchedPose",
                style: TextStyle(color: Colors.white70),
              ),

              Text("Best Match:", style: TextStyle(color: Colors.orange)),

              Text(
                bestMatchPose,
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                "${bestMatchScore.toStringAsFixed(1)}%",
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionOverlay() {
    if (!poseCompleted) {
      return const SizedBox();
    }

    return Container(
      color: Colors.black54,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "POSE COMPLETED ✅",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildPoseInfoCard() {
  //   return Positioned(
  //     top: 16,
  //     left: 16,
  //     right: 16,
  //     child: Card(
  //       color: Colors.black87,
  //       child: Padding(
  //         padding: const EdgeInsets.all(12),
  //         child: Column(
  //           children: [
  //             Text(
  //               widget.poseName,
  //               style: const TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),

  //             const SizedBox(height: 6),

  //             Text(
  //               detectedPose == null
  //                   ? "Searching for body..."
  //                   : "Pose detected",
  //               style: const TextStyle(color: Colors.white70),
  //             ),

  //             const SizedBox(height: 8),

  //             Text(
  //               bodyStatus,
  //               style: TextStyle(
  //                 color: isBodyVisible ? Colors.green : Colors.red,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             Text(
  //               "Hold Time: "
  //               "$currentHoldTime / 15 sec",
  //               style: const TextStyle(
  //                 color: Colors.white,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             const SizedBox(height: 8),

  //             LinearProgressIndicator(value: holdProgress.clamp(0, 1)),
  //             const SizedBox(height: 8),
  //             if (poseCompleted)
  //               const Text(
  //                 "POSE COMPLETED ✅",
  //                 style: TextStyle(
  //                   color: Colors.green,
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),

  //             const SizedBox(height: 4),

  //             Text(
  //               "Landmarks: $landmarkCount",
  //               style: const TextStyle(color: Colors.white70),
  //             ),

  //             Text(
  //               "Vector: ${currentVector.length}",
  //               style: const TextStyle(color: Colors.white70),
  //             ),

  //             const SizedBox(height: 4),

  //             Text(
  //               "Similarity: "
  //               "${smoothedSimilarity.toStringAsFixed(1)}%",
  //               style: const TextStyle(
  //                 color: Colors.green,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),

  //             Text(
  //               matchedPose.isEmpty
  //                   ? "Reference Not Loaded"
  //                   : "Matched: $matchedPose",
  //               style: const TextStyle(color: Colors.white70),
  //             ),

  //             const SizedBox(height: 8),

  //             Text(
  //               "Best Match: $bestMatchPose",
  //               style: const TextStyle(
  //                 color: Colors.orange,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),

  //             Text(
  //               "Best Match Score: "
  //               "${bestMatchScore.toStringAsFixed(1)}%",
  //               style: const TextStyle(color: Colors.orange),
  //             ),

  //             Text(
  //               getPoseStatus(similarity),
  //               style: TextStyle(
  //                 color: getPoseStatusColor(smoothedSimilarity),
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildBottomHint() {
  //   return Positioned(
  //     bottom: 20,
  //     left: 20,
  //     right: 20,
  //     child: Card(
  //       color: Colors.black87,
  //       child: Padding(
  //         padding: const EdgeInsets.all(12),
  //         child: Text(
  //           bodyStatus,
  //           textAlign: TextAlign.center,
  //           style: const TextStyle(color: Colors.white),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      // appBar: AppBar(title: Text(widget.poseName)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          if (detectedPose != null)
            CustomPaint(
              size: Size.infinite,
              painter: PosePainter(detectedPose!),
            ),

          _buildLandscapeInfoPanel(),

          _buildCompletionOverlay(),

          // ── Finish & Get Feedback button (bottom-left) ──────────────────
          Positioned(
            left: 16,
            bottom: 16,
            child: ElevatedButton.icon(
              onPressed: _finishing ? null : _finishSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: poseCompleted
                    ? const Color(0xFF34C759)
                    : const Color(0xFF5348C7),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
              ),
              icon: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.assessment_rounded),
              label: Text(
                _finishing
                    ? "Analyzing…"
                    : "Finish & Get Feedback",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          // Small close (X) top-left to exit without feedback
          Positioned(
            left: 12,
            top: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
