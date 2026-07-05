// lib/main.dart  ← FULL UPDATED FILE
//
// Change from original:
//   1. Added `import 'services/reminder_service.dart';`
//   2. Made main() async and added `await ReminderService.init();`
//   Everything else is identical to your original.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_service.dart';
import 'services/reminder_service.dart'; // ✅ ADD THIS IMPORT
import 'models/user_profile.dart';
import 'theme/app_theme.dart';

void main() async {
  // ✅ REQUIRED: must call before any async work in main()
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize the notification system once at startup
  await ReminderService.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: const YogaMitraApp(),
    ),
  );
}

class YogaMitraApp extends StatefulWidget {
  const YogaMitraApp({super.key});

  @override
  State<YogaMitraApp> createState() => _YogaMitraAppState();
}

class _YogaMitraAppState extends State<YogaMitraApp> {
  // Blank while session check runs — avoids flash of WelcomeScreen
  Widget startScreen = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    try {
      final session = await ApiService.loadSession();
      debugPrint('=== SESSION: $session');

      if (session == null) {
        if (mounted) setState(() => startScreen = WelcomeScreen());
        return;
      }

      final provider = Provider.of<UserProvider>(context, listen: false);
      provider.setProfile(
        UserProfile(
          userId: session['userId']!,
          name: session['name']!,
          email: session['email']!,
        ),
      );
      provider.setAgeGender(session['ageGroup'] ?? '', session['gender'] ?? '');

      debugPrint('=== FETCHING ROUTINE FOR: ${session["userId"]}');

      final data = await ApiService.fetchUserRoutine(session['userId']!);
      debugPrint('=== DATA KEYS: ${data?.keys}');

      if (data != null) {
        final savedPoses = (data['savedPoseRecommendations'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        final savedBreathing =
            (data['savedBreathingRecommendations'] as List? ?? [])
                .cast<Map<String, dynamic>>();

        provider.setRecommendations(
          poses: savedPoses,
          breathing: savedBreathing,
        );

        // Hydrate persisted health profile + medical report
        provider.hydrateFromHealthProfile(
          (data['healthProfile'] as Map?)?.cast<String, dynamic>(),
        );
        provider.setMedicalReport(
          (data['medicalReport'] as Map?)?.cast<String, dynamic>(),
        );

        final routinePayload = data['routine'] as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            startScreen = MainShell(
              initialRoutine: routinePayload ?? {'routine': []},
            );
          });
        }
      } else {
        if (mounted) {
          setState(() {
            startScreen = const MainShell(initialRoutine: {'routine': []});
          });
        }
      }
    } catch (e, stack) {
      debugPrint('=== _checkLogin ERROR: $e');
      debugPrint('=== STACK: $stack');
      if (mounted) setState(() => startScreen = WelcomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: startScreen,
    );
  }
}
