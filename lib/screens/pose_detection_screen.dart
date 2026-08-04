
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/normalized_landmark.dart';
import '../utils/pose_normalizer.dart';
import '../models/pose_reference.dart';
import '../services/pose_reference_service.dart';
import '../utils/cosine_similarity.dart';
import '../utils/angle_scorer.dart';

import '../services/pose_detection_service.dart';
import '../Widgets/pose_painter.dart';

import '../services/pose_match_service.dart';
import 'package:flutter/services.dart';
import '../services/body_visibility_service.dart';
import 'dart:async';
import 'pose_result_screen.dart';
import '../services/voice_service.dart';

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

class _PoseDetectionScreenState extends State<PoseDetectionScreen>
    with TickerProviderStateMixin {
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

  String matchedPose = '';

  bool referencesLoaded = false;

  String bestMatchPose = '';

  double bestMatchScore = 0;

  bool isBodyVisible = false;

  String bodyStatus = 'Searching...';

  /// EMA-smoothed similarity score — replaces the old SMA approach.
  double smoothedSimilarity = 0;

  /// Per-joint angle scores forwarded to the painter for segment colouring.
  List<double?> _perJointScores = List.filled(8, null);

  /// The actual pixel size of the camera image (not the preview widget).
  /// Populated once the camera is ready and updated per frame.
  Size _imageSize = Size.zero;

  int currentHoldTime = 0;

  bool poseCompleted = false;

  Timer? holdTimer;

  // ── Session metrics ──────────────────────────────────────────────────────
  double _sessionSumSim = 0;
  int _sessionCountSim = 0;
  double _sessionBestSim = 0;
  int _sessionFrames = 0;
  int _sessionVisFails = 0;
  int _maxHoldReached = 0;
  bool _finishing = false;

  // ── Completion animation ─────────────────────────────────────────────────
  late AnimationController _completionPulse;
  late Animation<double> _pulseAnim;

  // ── Voice cues ───────────────────────────────────────────────────────────
  final _voice = VoiceService.instance;
  String _lastCue = '';
  DateTime? _lastCueAt;
  bool _completeAnnounced = false;

  // ─────────────────────────────────────────────────────────────────────────
  //  EMA constants
  // ─────────────────────────────────────────────────────────────────────────
  static const double _scoreAlpha = 0.30;   // score EMA — reacts in ~3 frames

  // ─────────────────────────────────────────────────────────────────────────
  //  Hybrid score weights
  // ─────────────────────────────────────────────────────────────────────────
  static const double _cosineWeight = 0.60;
  static const double _angleWeight  = 0.40;

  // ─────────────────────────────────────────────────────────────────────────

  void _maybeSpeakCue() {
    if (!_voice.accessibilityMode) return;

    String cue;
    if (poseCompleted) {
      if (_completeAnnounced) return;
      _completeAnnounced = true;
      cue = _voice.t(
        'Excellent! Pose complete. Say finish to see your feedback.',
        'उत्तम! आसन पूर्ण. फीडबॅकसाठी फिनिश म्हणा.',
        'बहुत बढ़िया! आसन पूर्ण. फीडबैक के लिए फिनिश कहें.',
      );
    } else if (!isBodyVisible) {
      cue = _voice.t(
        bodyStatus,
        bodyStatus,
        bodyStatus,
      );
    } else if (smoothedSimilarity >= 80) {
      cue = _voice.t('Great, hold it steady.', 'छान, स्थिर धरा.',
          'बढ़िया, स्थिर रखें.');
    } else if (smoothedSimilarity >= 60) {
      cue = _voice.t('Almost there, adjust slightly.',
          'जवळजवळ झाले, थोडे समायोजित करा.',
          'लगभग हो गया, थोड़ा समायोजित करें.');
    } else if (smoothedSimilarity >= 30) {
      cue = _voice.t('Getting closer, keep adjusting.',
          'जवळ येत आहात, समायोजित करत राहा.',
          'करीब आ रहे हैं, समायोजित करते रहें.');
    } else {
      cue = _voice.t('Adjust your posture to match the pose.',
          'आसनाशी जुळण्यासाठी स्थिती बदला.',
          'आसन से मिलान हेतु मुद्रा बदलें.');
    }

    final now = DateTime.now();
    final changed = cue != _lastCue;
    final elapsed = _lastCueAt == null
        ? const Duration(seconds: 99)
        : now.difference(_lastCueAt!);
    if ((changed && elapsed.inSeconds >= 3) || elapsed.inSeconds >= 6) {
      _lastCue = cue;
      _lastCueAt = now;
      _voice.speak(cue, resumeListening: false);
    }
  }

  double get holdProgress => currentHoldTime / 15;

  void startHoldTimer() {
    if (holdTimer != null) return;
    holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        currentHoldTime++;
        if (currentHoldTime > _maxHoldReached) {
          _maxHoldReached = currentHoldTime;
        }
        if (currentHoldTime >= 15) {
          poseCompleted = true;
          timer.cancel();
          _completionPulse.repeat(reverse: true);
        }
      });
    });
  }

  void stopHoldTimer() {
    holdTimer?.cancel();
    holdTimer = null;
    currentHoldTime = 0;
    _completionPulse.stop();
    _completionPulse.reset();
  }

  /// Update [smoothedSimilarity] with an EMA step and manage the hold timer.
  void updateSimilarity(double newScore) {
    smoothedSimilarity =
        _scoreAlpha * newScore + (1 - _scoreAlpha) * smoothedSimilarity;

    if (smoothedSimilarity >= 80) {
      startHoldTimer();
    } else {
      poseCompleted = false;
      stopHoldTimer();
    }
  }



  Future<void> _loadReferences() async {
    try {
      references = await PoseReferenceService.loadReferences();
      referencesLoaded = true;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('REFERENCE LOAD ERROR = $e');
    }
  }

  InputImageRotation _cameraRotation = InputImageRotation.rotation270deg;

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    if (image.format.group == ImageFormatGroup.nv21) {
      return image.planes[0].bytes;
    }

    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = width * height;
    final nv21 = Uint8List(numPixels + (numPixels ~/ 2));

    int idY = 0;
    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      final yOffset = y * yRowStride;
      for (int x = 0; x < width; x++) {
        nv21[idY++] = yBuffer[yOffset + x * yPixelStride];
      }
    }

    int idUV = numPixels;
    final vRowStride = vPlane.bytesPerRow;
    final vPixelStride = vPlane.bytesPerPixel ?? 2;
    final uRowStride = uPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 2;
    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;

    for (int y = 0; y < uvHeight; y++) {
      final vRowOffset = y * vRowStride;
      final uRowOffset = y * uRowStride;
      for (int x = 0; x < uvWidth; x++) {
        final vIndex = vRowOffset + x * vPixelStride;
        final uIndex = uRowOffset + x * uPixelStride;

        nv21[idUV++] = vIndex < vBuffer.length ? vBuffer[vIndex] : 0;
        nv21[idUV++] = uIndex < uBuffer.length ? uBuffer[uIndex] : 0;
      }
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

    // Pulse animation for pose-complete state
    _completionPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _completionPulse, curve: Curves.easeInOut),
    );

    _loadReferences();
    _initialize();

    _voice.addAction('finish', () {
      if (mounted) _finishSession();
    });
    if (_voice.accessibilityMode) {
      _voice.speak(
        _voice.t(
          'Starting ${widget.poseName} guidance. Face the camera and match the pose. I will guide you. Say finish when you are done.',
          '${widget.poseName} मार्गदर्शन सुरू. कॅमेऱ्यासमोर आसन जुळवा. मी मार्गदर्शन करेन. पूर्ण झाल्यावर फिनिश म्हणा.',
          '${widget.poseName} मार्गदर्शन शुरू. कैमरे के सामने आसन मिलाएं. मैं मार्गदर्शन करूँगा. पूरा होने पर फिनिश कहें.',
        ),
        resumeListening: false,
      );
    }
  }

  Future<void> _initialize() async {
    try {
      _poseService = PoseDetectionService();

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );

      // medium = 480p — best accuracy/latency trade-off for ML Kit
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _cameraRotation = _rotationFromSensor(frontCamera.sensorOrientation);

      await _cameraController!.initialize();

      // Capture the raw camera frame dimensions once so the painter can scale.
      final ps = _cameraController!.value.previewSize!;
      _imageSize = Size(ps.height, ps.width);

      await _cameraController!.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (isBusy) return;
    isBusy = true;

    try {
      if (image.width > 0 && image.height > 0) {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      }

      final nv21Bytes = _convertYUV420ToNV21(image);
      final inputImage = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _cameraRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      final poses = await _poseService.processImage(inputImage);

      if (poses.isNotEmpty) {
        detectedPose = poses.first;

        // ── Visibility check (confidence-gated) ──────────────────────────
        final visResult = BodyVisibilityService.validate(detectedPose!);
        isBodyVisible = visResult.isVisible;
        bodyStatus = visResult.message;

        _sessionFrames++;
        if (!isBodyVisible) _sessionVisFails++;

        landmarkCount = detectedPose!.landmarks.length;

        // ── Normalization ────────────────────────────────────────────────
        normalizedLandmarks = PoseNormalizer.normalize(detectedPose!);
        currentVector = normalizedLandmarks
            .map((e) => [e.x, e.y])
            .expand((e) => e)
            .toList();

        // ── Best-match (for the debug panel) ────────────────────────────
        final matchResult = PoseMatchService.findBestMatch(
          currentVector,
          references,
        );
        bestMatchPose  = matchResult.poseName;
        bestMatchScore = matchResult.similarity;

        // ── Hybrid scoring ───────────────────────────────────────────────
        if (isBodyVisible && referencesLoaded && currentVector.length == 66) {
          try {
            final selectedPose = references.firstWhere(
              (p) => p.poseName.toLowerCase() == widget.poseName.toLowerCase(),
            );

            if (selectedPose.referenceVector.length == currentVector.length) {
              // 1) Cosine score
              final cosineScore = CosineSimilarity.calculate(
                    currentVector,
                    selectedPose.referenceVector,
                  ) *
                  100;

              // 2) Angle score
              final liveAngles = AngleScorer.extractAngles(detectedPose!);
              // Use pre-computed reference angles from the JSON
              final List<double?> refAngles = selectedPose.referenceAngles;
              final angleScore = AngleScorer.score(liveAngles, refAngles);

              // 3) Per-joint scores for painter
              _perJointScores =
                  AngleScorer.perJointScores(liveAngles, refAngles);

              // 4) Hybrid: 60% cosine (shape) + 40% angle (joint accuracy)
              final hasAngles = refAngles.any((v) => v != null);
              similarity = hasAngles
                  ? (cosineScore * _cosineWeight + angleScore * _angleWeight)
                  : cosineScore;

              updateSimilarity(similarity);

              _sessionSumSim += similarity;
              _sessionCountSim++;
              if (similarity > _sessionBestSim) _sessionBestSim = similarity;

              matchedPose = selectedPose.poseName;
            }
          } catch (_) {
            // Pose reference not yet found — keep previous score
          }
        }
      } else {
        detectedPose = null;
        isBodyVisible = false;
        bodyStatus = 'Searching for body...';
      }

      if (mounted) setState(() {});
      _maybeSpeakCue();
    } catch (e, stack) {
      debugPrint('POSE DETECTION ERROR = $e\n$stack');
    }

    isBusy = false;
  }

  @override
  void dispose() {
    holdTimer?.cancel();
    _completionPulse.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _cameraController?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  Future<void> _finishSession() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    holdTimer?.cancel();
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}

    final avg  = _sessionCountSim > 0 ? _sessionSumSim / _sessionCountSim : 0.0;
    final best = _sessionBestSim;
    final held = poseCompleted ? 15 : _maxHoldReached;
    final visRatio =
        _sessionFrames > 0 ? _sessionVisFails / _sessionFrames : 0.0;

    final mistakes = <String>[];
    if (!poseCompleted) {
      mistakes.add('Did not hold the pose for the full 15 seconds');
    }
    if (avg < 60 && _sessionCountSim > 0) {
      mistakes.add('Overall alignment stayed below target accuracy');
    }
    if (visRatio > 0.3) {
      mistakes.add('Full body was often not visible in the camera frame');
    }
    if (best >= 80 && avg < 60) {
      mistakes.add('Found the correct pose but struggled to hold it steadily');
    }

    final result = <String, dynamic>{
      'poseId':           widget.poseId,
      'poseName':         widget.poseName,
      'avgSimilarity':    avg,
      'bestSimilarity':   best,
      'durationAchieved': held,
      'targetDuration':   15,
      'completed':        poseCompleted,
      'mistakes':         mistakes,
      'level':            'beginner',
    };

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PoseResultScreen(results: [result])),
    );
  }

  // ── Score → status helpers ──────────────────────────────────────────────

  String getPoseStatus(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Good';
    if (score >= 60) return 'Close';
    return 'Not Matching';
  }

  Color getPoseStatusColor(double score) {
    if (score >= 90) return const Color(0xFF00FF88);
    if (score >= 80) return const Color(0xFF7FFF00);
    if (score >= 60) return const Color(0xFFFFAA00);
    return const Color(0xFFFF3B30);
  }

  // ── Info panel ──────────────────────────────────────────────────────────

  Widget _buildLandscapeInfoPanel() {
    final scoreColor = getPoseStatusColor(smoothedSimilarity);
    return Positioned(
      top: 16,
      right: 16,
      bottom: 16,
      width: 260,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scoreColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pose name
              Text(
                widget.poseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              // Body status
              Row(
                children: [
                  Icon(
                    isBodyVisible
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: isBodyVisible ? Colors.greenAccent : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bodyStatus,
                      style: TextStyle(
                        color: isBodyVisible ? Colors.greenAccent : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Accuracy score with animated number
              Text(
                'Accuracy',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(end: smoothedSimilarity),
                duration: const Duration(milliseconds: 300),
                builder: (context, val, child) => Text(
                  '${val.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: scoreColor.withValues(alpha: 0.6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                getPoseStatus(smoothedSimilarity),
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              // Accuracy bar
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (smoothedSimilarity / 100).clamp(0, 1),
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 20),

              // Hold timer
              Text('Hold Time', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                '$currentHoldTime / 15 sec',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: holdProgress.clamp(0, 1),
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF00C7FF)),
                  minHeight: 8,
                ),
              ),

              // Debug section (debug builds only)
              if (kDebugMode) ...[
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                Text('Debug', style: TextStyle(color: Colors.orange.shade300, fontSize: 11)),
                const SizedBox(height: 4),
                Text('Landmarks: $landmarkCount', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text('Vector: ${currentVector.length}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text('Best: $bestMatchPose', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text('${bestMatchScore.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionOverlay() {
    if (!poseCompleted) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: _pulseAnim.value,
        child: child,
      ),
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C787), Color(0xFF00A060)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 48),
                SizedBox(height: 10),
                Text(
                  'POSE COMPLETED!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ─────────────────────────────────────────────
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:  _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // ── Skeleton overlay ───────────────────────────────────────────
          if (detectedPose != null)
            LayoutBuilder(
              builder: (context, constraints) {
                // Pass the actual rendered canvas size to the painter so it
                // can compute the correct ML Kit → canvas transform.
                final canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return CustomPaint(
                  size: canvasSize,
                  painter: PosePainter(
                    pose:            detectedPose!,
                    similarityScore: smoothedSimilarity,
                    perJointScores:  _perJointScores,
                    imageSize:       _imageSize,
                  ),
                );
              },
            ),

          // ── Info panel ─────────────────────────────────────────────────
          _buildLandscapeInfoPanel(),

          // ── Completion overlay ─────────────────────────────────────────
          _buildCompletionOverlay(),

          // ── Finish button ──────────────────────────────────────────────
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assessment_rounded),
              label: Text(
                _finishing ? 'Analyzing…' : 'Finish & Get Feedback',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          // ── Close button ───────────────────────────────────────────────
          Positioned(
            left: 12,
            top: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
