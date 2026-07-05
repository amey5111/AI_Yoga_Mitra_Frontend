// lib/screens/routine_screen.dart  ← FULL UPDATED FILE

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/reminder_service.dart';
import '../services/reminder_storage.dart';
import '../utils/language_helper.dart';
import '../providers/user_provider.dart';
import 'pose_detail_screen.dart';
import 'breathing_detail_screen.dart';
import 'welcome_screen.dart';
import 'my_profile_screen.dart';
import 'edit_routine_screen.dart';
import '../Widgets/normal_language_switcher.dart';
import 'pose_detection_screen.dart';
import 'yoga_gpt_screen.dart';
import 'diet_screen.dart';
import '../theme/app_theme.dart';

class RoutineScreen extends StatefulWidget {
  final Map<String, dynamic>? routine;

  /// When hosted inside the bottom-nav shell, [embedded] is true (hides the
  /// FAB and lets the shell own navigation). [onSwitchTab] jumps to another
  /// tab (e.g. Recommendations) from the home screen.
  final bool embedded;
  final void Function(int tabIndex)? onSwitchTab;

  const RoutineScreen({
    super.key,
    this.routine,
    this.embedded = false,
    this.onSwitchTab,
  });

  @override
  State<RoutineScreen> createState() => RoutineScreenState();
}

class RoutineScreenState extends State<RoutineScreen> {
  bool loading = true;
  bool _forceRefresh = false;
  List<Map<String, dynamic>> routineSteps = [];

  /// Public reload used by the shell after a routine is generated elsewhere.
  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      routineSteps = [];
      _forceRefresh = true;
    });
    await _loadRoutine();
  }

  Future<void> _openEditRoutine() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditRoutineScreen(routineSteps: routineSteps),
      ),
    );
    if (mounted) {
      setState(() {
        loading = true;
        routineSteps = [];
        _forceRefresh = true;
      });
      _loadRoutine();
    }
  }

  Color get purple => const Color(0xFF7C4DFF);
  Color get purpleDark => const Color(0xFF5E35B1);

  String get langCode {
    switch (LanguageHelper.currentLanguage) {
      case 'मराठी':
        return 'mr';
      case 'हिंदी':
        return 'hn';
      default:
        return 'en';
    }
  }

  String t(String en, String mr, String hn) => LanguageHelper.t(en, mr, hn);

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return t('Good Morning 🌅', 'शुभ प्रभात 🌅', 'सुप्रभात 🌅');
    if (hour < 17)
      return t('Good Afternoon 🌄', 'शुभ दुपार 🌄', 'शुभ दोपहर 🌄');
    return t('Good Evening 🌃', 'शुभ संध्याकाळ 🌃', 'शुभ संध्या 🌃');
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? -1;
  }

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    try {
      Map<String, dynamic>? routineObject;
      final provider = Provider.of<UserProvider>(context, listen: false);

      if (_forceRefresh || widget.routine == null || widget.routine!.isEmpty) {
        debugPrint('=== _loadRoutine: fetching fresh from DB');
        _forceRefresh = false;
        final fullData = await ApiService.fetchUserRoutine(
          provider.profile.userId,
        );
        if (fullData != null) {
          if (provider.poseDetails.isEmpty) {
            final savedPoses =
                (fullData['savedPoseRecommendations'] as List? ?? [])
                    .cast<Map<String, dynamic>>();
            final savedBreathing =
                (fullData['savedBreathingRecommendations'] as List? ?? [])
                    .cast<Map<String, dynamic>>();
            provider.setRecommendations(
              poses: savedPoses,
              breathing: savedBreathing,
            );
          }
          // Hydrate persisted health profile + medical report
          provider.hydrateFromHealthProfile(
            (fullData['healthProfile'] as Map?)?.cast<String, dynamic>(),
          );
          provider.setMedicalReport(
            (fullData['medicalReport'] as Map?)?.cast<String, dynamic>(),
          );
          routineObject = fullData['routine'] as Map<String, dynamic>?;
        }
      } else {
        final raw = widget.routine!;
        if (raw.containsKey('savedPoseRecommendations')) {
          if (provider.poseDetails.isEmpty) {
            final savedPoses = (raw['savedPoseRecommendations'] as List? ?? [])
                .cast<Map<String, dynamic>>();
            final savedBreathing =
                (raw['savedBreathingRecommendations'] as List? ?? [])
                    .cast<Map<String, dynamic>>();
            provider.setRecommendations(
              poses: savedPoses,
              breathing: savedBreathing,
            );
          }
          routineObject = raw['routine'] as Map<String, dynamic>?;
        } else if (raw.containsKey('total_duration')) {
          routineObject = raw;
        } else {
          routineObject = raw;
        }
      }

      final rawSteps = routineObject?['routine'];
      final steps = (rawSteps is List) ? rawSteps : [];

      final List<Map<String, dynamic>> loadedSteps = [];
      for (final step in steps) {
        try {
          final stepMap = Map<String, dynamic>.from(step as Map);
          final id = _toInt(stepMap['id']);
          final duration = stepMap['duration'];
          final type = stepMap['type'] as String?;

          if (id == -1) continue;

          if (type == 'breathing') {
            final breathing = await ApiService.fetchBreathingById(id);
            if (breathing != null) {
              breathing['duration'] = duration;
              breathing['type'] = 'breathing';
              loadedSteps.add(breathing);
            }
          } else {
            final pose = await ApiService.fetchPoseById(id);
            pose['duration'] = duration;
            pose['type'] = 'pose';
            loadedSteps.add(pose);
          }
        } catch (stepErr) {
          debugPrint('=== Error loading step: $stepErr');
        }
      }

      if (mounted) {
        setState(() {
          routineSteps = loadedSteps;
          loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('=== _loadRoutine ERROR: $e');
      debugPrint('=== STACK: $stack');
      if (mounted) {
        setState(() {
          routineSteps = [];
          loading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SET REMINDER BUTTON handler — checks permissions first, then opens popup
  // ─────────────────────────────────────────────────────────────────────────

  // ✅ FIX: Do NOT instantiate FlutterLocalNotificationsPlugin here.
  //         All permission logic lives in ReminderService — call it from there.
  Future<void> _handleSetReminderTap() async {
    // Step 1: Request notification permission (Android 13+)
    await ReminderService.checkAndRequestPermissions();

    // Step 2: Check if exact alarm permission is granted
    final exactGranted = await ReminderService.isExactAlarmPermissionGranted();

    if (!exactGranted) {
      if (!mounted) return;
      // Show a dialog guiding user to grant the permission manually
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('⚠️ Permission Required'),
          content: const Text(
            'To ring alarms on time, please enable "Alarms & Reminders" '
            'permission for this app.\n\n'
            'Tap "Open Settings" → find Yoga Mitra → enable it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Opens the system exact alarm settings page
                await ReminderService.openExactAlarmSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return; // Do not open popup until permission is granted
    }

    // Permission granted — open the reminder popup
    _openReminderPopup();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REMINDER POPUP — per-user, pre-fills existing reminder, shows confirmation
  // ─────────────────────────────────────────────────────────────────────────
  void _openReminderPopup() async {
    final provider = Provider.of<UserProvider>(context, listen: false);
    final String userId = provider.profile.userId;

    List<int> selectedDays = [];
    TimeOfDay selectedTime = TimeOfDay.now();

    // Load this user's previously saved reminder
    final existing = await ReminderStorage.loadReminder(userId);
    if (existing != null) {
      selectedDays = List<int>.from(existing['days'] as List);
      selectedTime = TimeOfDay(
        hour: existing['hour'] as int,
        minute: existing['minute'] as int,
      );
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    existing != null
                        ? t('Edit Reminder', 'रिमाइंडर बदला', 'रिमाइंडर बदलें')
                        : t(
                            'Set Reminder',
                            'रिमाइंडर सेट करा',
                            'रिमाइंडर सेट करें',
                          ),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── DAY CHIPS ───────────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    children: List.generate(7, (index) {
                      final day = index + 1; // 1=Mon … 7=Sun
                      final labels = [
                        t('Mon', 'सोम', 'सोम'),
                        t('Tue', 'मंगळ', 'मंगल'),
                        t('Wed', 'बुध', 'बुध'),
                        t('Thu', 'गुरु', 'गुरु'),
                        t('Fri', 'शुक्र', 'शुक्र'),
                        t('Sat', 'शनि', 'शनि'),
                        t('Sun', 'रवि', 'रवि'),
                      ];
                      final isSelected = selectedDays.contains(day);
                      return ChoiceChip(
                        label: Text(labels[index]),
                        selected: isSelected,
                        selectedColor: purple.withOpacity(0.8),
                        onSelected: (_) {
                          setModalState(() {
                            if (isSelected) {
                              selectedDays.remove(day);
                            } else {
                              selectedDays.add(day);
                            }
                          });
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 20),

                  // ── TIME PICKER ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('Select Time', 'वेळ निवडा', 'समय चुनें'),
                        style: GoogleFonts.inter(fontSize: 16),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: sheetContext,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setModalState(() => selectedTime = picked);
                          }
                        },
                        child: Text(
                          selectedTime.format(sheetContext),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: purple,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── SET ALARM BUTTON ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (selectedDays.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                t(
                                  'Please select at least one day',
                                  'किमान एक दिवस निवडा',
                                  'कम से कम एक दिन चुनें',
                                ),
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          // 1. Cancel this user's old alarms
                          final old = await ReminderStorage.loadReminder(
                            userId,
                          );
                          if (old != null) {
                            final oldDays = List<int>.from(old['days'] as List);
                            final idOffset = userId.hashCode.abs() % 1000;
                            final oldIds = List.generate(
                              oldDays.length,
                              (i) => idOffset + i,
                            );
                            await ReminderService.cancelForIds(oldIds);
                          }

                          // 2. Schedule new alarms (per-user ID offset)
                          final idOffset = userId.hashCode.abs() % 1000;
                          for (int i = 0; i < selectedDays.length; i++) {
                            await ReminderService.scheduleReminder(
                              id: idOffset + i,
                              weekday: selectedDays[i],
                              hour: selectedTime.hour,
                              minute: selectedTime.minute,
                            );
                          }

                          // 3. Save per-user
                          await ReminderStorage.saveReminder(
                            userId: userId,
                            days: selectedDays,
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                          );

                          // 4. Close bottom sheet first
                          Navigator.of(sheetContext).pop();

                          // 5. Show success dialog using parent context
                          //    Delay 300ms so sheet is fully dismissed first
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (!mounted) return;
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(
                                  t('✅ Success', '✅ यशस्वी', '✅ सफल'),
                                ),
                                content: Text(
                                  t(
                                    'Reminder set successfully!\nAlarm will ring at the selected days and time.',
                                    'रिमाइंडर यशस्वीरित्या सेट झाला!\nनिवडलेल्या दिवस व वेळी अलार्म वाजेल.',
                                    'रिमाइंडर सफलतापूर्वक सेट हुआ!\nचुने हुए दिन और समय पर अलार्म बजेगा।',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(t('OK', 'ठीक आहे', 'ठीक है')),
                                  ),
                                ],
                              ),
                            );
                          });
                        } catch (e) {
                          Navigator.of(sheetContext).pop();
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error setting reminder: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          });
                        }
                      },
                      child: Text(
                        t('Set Alarm', 'अलार्म सेट करा', 'अलार्म सेट करें'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  String formatDuration(int seconds) {
    final mins = (seconds / 60).round();
    return '$mins ${t("mins", "मिनिटे", "मिनट")}';
  }

  void openVideo(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget routineCard(Map<String, dynamic> item, int index) {
    final name = item['name']?[langCode] ?? '';
    final duration = _toInt(item['duration'] ?? 60);
    final video = item['video']?[langCode]?['youtube_url'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [purple.withOpacity(.7), purpleDark.withOpacity(.9)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}) $name',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.play_arrow, color: purpleDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${t("Duration", "कालावधी", "समय")} : ${formatDuration(duration)}',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: () {
                  if (item['type'] == 'breathing') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BreathingDetailScreen(id: item['id']),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PoseDetailScreen(poseId: item['id']),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      t('Info', 'माहिती', 'जानकारी'),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              InkWell(
                onTap: () => openVideo(video),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle, color: Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      t('Video', 'व्हिडिओ', 'वीडियो'),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  // Only yoga poses can be detected
                  if (item['type'] == 'pose') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PoseDetectionScreen(
                          poseId: item['id'],
                          poseName: name,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Pose detection is available only for yoga poses.',
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t(
                          'Start Practice',
                          'सराव सुरू करा',
                          'अभ्यास शुरू करें',
                        ),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget profileMenu() {
    return PopupMenuButton<String>(
      icon: const CircleAvatar(backgroundImage: AssetImage('assets/user.png')),
      onSelected: (value) async {
        if (value == 'profile') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyProfileScreen()),
          );
        }

        if (value == 'editRoutine') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditRoutineScreen(routineSteps: routineSteps),
            ),
          );
          if (mounted) {
            setState(() {
              loading = true;
              routineSteps = [];
              _forceRefresh = true;
            });
            _loadRoutine();
          }
        }

        if (value == 'dietPlan') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DietScreen()),
          );
        }

        if (value == 'logout') {
          // Cancel this user's notifications on logout
          // but keep their saved reminder data for when they log back in
          final provider = Provider.of<UserProvider>(context, listen: false);
          final userId = provider.profile.userId;
          final existing = await ReminderStorage.loadReminder(userId);
          if (existing != null) {
            final days = List<int>.from(existing['days'] as List);
            final idOffset = userId.hashCode.abs() % 1000;
            final ids = List.generate(days.length, (i) => idOffset + i);
            await ReminderService.cancelForIds(ids);
          }

          await ApiService.clearSession();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => WelcomeScreen()),
            (route) => false,
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Text(t('My Profile', 'माझे प्रोफाइल', 'मेरा प्रोफाइल')),
        ),
        PopupMenuItem(
          value: 'editRoutine',
          child: Text(
            t(
              'Edit Routine',
              'दिनचर्या सुधारित करा',
              'दिनचर्या में बदलाव करें',
            ),
          ),
        ),
        PopupMenuItem(
          value: 'dietPlan',
          child: Text(t('Diet Plan 🥗', 'आहार योजना 🥗', 'डाइट प्लान 🥗')),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Text(t('Logout', 'लॉगआउट', 'लॉगआउट')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProvider>(context, listen: false);
    final totalSeconds = routineSteps.fold<int>(
      0,
      (sum, e) => sum + _toInt(e['duration'] ?? 0),
    );
    final totalMinutes = (totalSeconds / 60).round();

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton.extended(
              heroTag: 'yogagpt_fab',
              backgroundColor: purpleDark,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.smart_toy_rounded),
              label: Text(
                'YogaGPT',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const YogaGptScreen()),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── GRADIENT HEADER CARD ────────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppGradients.welcomeBg,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x338B84F8),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 12, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      getGreeting(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.profile.name.isNotEmpty
                                          ? provider.profile.name
                                          : t(
                                              'Welcome !',
                                              'आपले स्वागत आहे!',
                                              'आपका स्वागत है!',
                                            ),
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              NormalLanguageSwitcher(
                                onLanguageChanged: () => setState(() {}),
                              ),
                              const SizedBox(width: 8),
                              _homeAvatar(provider.profile.name),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Today summary chips
                          Row(
                            children: [
                              _summaryChip(
                                Icons.self_improvement_rounded,
                                '${routineSteps.length}',
                                t('Steps', 'पायऱ्या', 'चरण'),
                              ),
                              const SizedBox(width: 10),
                              _summaryChip(
                                Icons.timer_outlined,
                                '$totalMinutes',
                                t('Minutes', 'मिनिटे', 'मिनट'),
                              ),
                              const SizedBox(width: 10),
                              _summaryChip(
                                Icons.local_fire_department_rounded,
                                routineSteps.isEmpty ? '—' : '${(totalMinutes * 4)}',
                                t('Kcal', 'कॅलरी', 'कैलोरी'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── QUICK ACCESS ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Row(
                    children: [
                      _quickCard(
                        Icons.auto_awesome_rounded,
                        t('Recommend', 'शिफारसी', 'सिफारिश'),
                        const Color(0xFF6C63FF),
                        () => widget.onSwitchTab?.call(1),
                      ),
                      const SizedBox(width: 10),
                      _quickCard(
                        Icons.restaurant_rounded,
                        t('Diet', 'आहार', 'डाइट'),
                        const Color(0xFF34C759),
                        () => widget.embedded
                            ? widget.onSwitchTab?.call(2)
                            : Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DietScreen(),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      _quickCard(
                        Icons.smart_toy_rounded,
                        'YogaGPT',
                        const Color(0xFFFF9500),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const YogaGptScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── ROUTINE TITLE ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Row(
                    children: [
                      Text(
                        t(
                          'Your Yoga Routine',
                          'तुमची योगा दिनचर्या',
                          'आपकी योगा दिनचर्या',
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (routineSteps.isNotEmpty) ...[
                        GestureDetector(
                          onTap: _openEditRoutine,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.chipBg,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_rounded,
                                    size: 14, color: AppColors.accent),
                                const SizedBox(width: 5),
                                Text(
                                  t('Edit', 'संपादन', 'संपादित'),
                                  style: GoogleFonts.poppins(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── ROUTINE LIST ────────────────────────────────────────
                Expanded(
                  child: routineSteps.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: routineSteps.length,
                          itemBuilder: (context, index) =>
                              routineCard(routineSteps[index], index),
                        ),
                ),

                // ── BOTTOM BUTTONS ──────────────────────────────────────
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                color: AppColors.accent,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.alarm_rounded),
                            label: Text(
                              t(
                                'Set Reminder',
                                'रिमाइंडर सेट करा',
                                'रिमाइंडर सेट करें',
                              ),
                            ),
                            onPressed: _handleSetReminderTap,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: Icon(
                              routineSteps.isEmpty
                                  ? Icons.auto_awesome_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(
                              routineSteps.isEmpty
                                  ? t('Generate', 'तयार करा', 'बनाएं')
                                  : t('Start', 'सुरू करा', 'शुरू करें'),
                            ),
                            // When there's no routine yet, this takes the user
                            // to the Explore (Recommendations) tab to build one;
                            // otherwise it starts live pose practice.
                            onPressed: routineSteps.isEmpty
                                ? () => widget.onSwitchTab?.call(1)
                                : () {
                                    // Launch pose detection for the first yoga pose
                                    final firstPose = routineSteps.firstWhere(
                                      (s) => s['type'] != 'breathing',
                                      orElse: () => {},
                                    );
                                    if (firstPose.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PoseDetectionScreen(
                                            poseId: _toInt(firstPose['id']),
                                            poseName:
                                                firstPose['name']?['en'] ?? '',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Home helper widgets ────────────────────────────────────────────────
  Widget _homeAvatar(String name) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join()
        : '?';
    return GestureDetector(
      onTap: () => widget.onSwitchTab?.call(3),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.22),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        ),
        child: Center(
          child: Text(
            initials,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.self_improvement_rounded,
                size: 52,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t(
                'No routine yet',
                'अद्याप दिनचर्या नाही',
                'अभी तक कोई दिनचर्या नहीं',
              ),
              style: AppTextStyles.heading3(),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'Get AI recommendations and build your\npersonalized yoga routine.',
                'AI शिफारसी घ्या आणि तुमची योगा दिनचर्या तयार करा.',
                'AI सिफारिशें लेकर अपनी योगा दिनचर्या बनाएं.',
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: t(
                'Get Recommendations',
                'शिफारसी मिळवा',
                'सिफारिशें पाएं',
              ),
              icon: Icons.auto_awesome_rounded,
              width: 240,
              onPressed: () => widget.onSwitchTab?.call(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
