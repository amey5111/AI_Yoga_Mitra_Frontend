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

class RoutineScreen extends StatefulWidget {
  final Map<String, dynamic>? routine;
  const RoutineScreen({super.key, this.routine});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  bool loading = true;
  bool _forceRefresh = false;
  List<Map<String, dynamic>> routineSteps = [];

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
              Text(
                t('Start Practice', 'सराव सुरू करा', 'अभ्यास शुरू करें'),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
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
          value: 'logout',
          child: Text(t('Logout', 'लॉगआउट', 'लॉगआउट')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = routineSteps.fold<int>(
      0,
      (sum, e) => sum + _toInt(e['duration'] ?? 0),
    );
    final totalMinutes = (totalSeconds / 60).round();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ── HEADER ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                getGreeting(),
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                t(
                                  'Welcome !',
                                  'आपले स्वागत आहे!',
                                  'आपका स्वागत है!',
                                ),
                                style: GoogleFonts.inter(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NormalLanguageSwitcher(
                              onLanguageChanged: () {
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 10),
                            profileMenu(),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      t(
                        'Start Your todays day with Yoga, to get energetic life ahead.',
                        'पुढील आयुष्य उत्साहाने भरण्यासाठी आजच्या दिवसाची सुरुवात योगाभ्यासाने करा.',
                        'आपकी जिंदगी उत्साह से भरने हेतु अपने दिन की शुरुआत योगाभ्यास से करें।',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── ROUTINE TITLE ───────────────────────────────────────
                  Text(
                    t(
                      'Your Yoga Routine',
                      'तुमची योगा दिनचर्या',
                      'आपकी योगा दिनचर्या',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '(${t("Total time", "एकूण वेळ", "कुल समय")} : $totalMinutes ${t("Min", "मिनिटे", "मिनट")})',
                    style: GoogleFonts.poppins(
                      color: purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── ROUTINE LIST ────────────────────────────────────────
                  Expanded(
                    child: routineSteps.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                t(
                                  'No routine yet.\nGo to Recommendations to generate one.',
                                  'अद्याप दिनचर्या नाही.\nशिफारसींमध्ये जाऊन तयार करा.',
                                  'अभी तक कोई दिनचर्या नहीं।\nसिफारिशें देखकर बनाएं।',
                                ),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: routineSteps.length,
                            itemBuilder: (context, index) =>
                                routineCard(routineSteps[index], index),
                          ),
                  ),

                  // ── BOTTOM BUTTONS ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.alarm),
                            label: Text(
                              t(
                                'Set Reminder',
                                'रिमाइंडर सेट करा',
                                'रिमाइंडर सेट करें',
                              ),
                            ),
                            // ✅ FIXED: calls _handleSetReminderTap which
                            //    checks permissions via ReminderService only —
                            //    no FlutterLocalNotificationsPlugin instantiated here
                            onPressed: _handleSetReminderTap,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t('Start', 'सुरू करा', 'शुरू करें')),
                            onPressed: () {
                              // your existing start logic here
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
