import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'routine_screen.dart';
import 'recommendations_screen.dart';
import 'diet_screen.dart';
import 'settings_screen.dart';
import 'yoga_gpt_screen.dart';
import 'progress_dashboard_screen.dart';
import '../services/voice_service.dart';
import '../widgets/voice_button.dart';
import '../utils/language_helper.dart';

/// Root shell that hosts the four main tabs behind a bottom navigation bar,
/// with a prominent center YogaGPT button. Wrapped in PopScope so the Android
/// back gesture never pops the app out to the login screen (fixes the
/// "swipe = logout" bug) — the user only leaves via explicit Logout.
class MainShell extends StatefulWidget {
  final Map<String, dynamic>? initialRoutine;
  final int initialIndex;
  const MainShell({super.key, this.initialRoutine, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final GlobalKey<RoutineScreenState> _homeKey =
      GlobalKey<RoutineScreenState>();
  final GlobalKey<RecommendationsScreenState> _exploreKey =
      GlobalKey<RecommendationsScreenState>();
  final GlobalKey<DietScreenState> _dietKey = GlobalKey<DietScreenState>();

  late final List<Widget> _pages;

  final _voice = VoiceService.instance;

  static const _tabNames = [
    ["Home", "होम", "होम"],
    ["Explore", "एक्सप्लोर", "एक्सप्लोर"],
    ["Diet", "आहार", "डाइट"],
    ["Profile", "प्रोफाइल", "प्रोफ़ाइल"],
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;

    // Wire the voice assistant to this shell's navigation + actions
    _voice.tabSwitcher = _switchTo;
    _voice.setActions({
      'assistant': () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const YogaGptScreen()),
          ),
      'history': () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProgressDashboardScreen()),
          ),
      // Context-aware generate: on the Diet tab it makes a diet plan,
      // elsewhere it builds the yoga routine.
      'generate': () {
        if (_index == 2) {
          _dietKey.currentState?.triggerGenerate();
        } else {
          _goGenerate();
        }
      },
      // Navigate to Diet AND generate the plan (spoken by the diet screen)
      'dietGenerate': () {
        _switchTo(2);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _dietKey.currentState?.triggerGenerate();
        });
      },
    });
    _updateReader();

    // Welcome + command help — ONCE per app launch
    WidgetsBinding.instance.addPostFrameCallback((_) => _voice.welcomeOnLaunch());

    _pages = [
      RoutineScreen(
        key: _homeKey,
        routine: widget.initialRoutine,
        embedded: true,
        onSwitchTab: _switchTo,
        onGenerate: _goGenerate,
      ),
      RecommendationsScreen(
        key: _exploreKey,
        embedded: true,
        onSwitchTab: _switchTo,
      ),
      DietScreen(key: _dietKey, embedded: true),
      const SettingsScreen(),
    ];
  }

  /// Point the "read this screen" voice command at the active tab's content.
  void _updateReader() {
    switch (_index) {
      case 0:
        _voice.setReader(() => _homeKey.currentState?.spokenSummary() ?? '');
        break;
      case 1:
        _voice.setReader(
            () => _exploreKey.currentState?.spokenSummary() ?? '');
        break;
      case 2:
        _voice.setReader(() => _dietKey.currentState?.spokenSummary() ?? '');
        break;
      default:
        _voice.setReader(null);
    }
  }

  String _tab(int i) =>
      LanguageHelper.t(_tabNames[i][0], _tabNames[i][1], _tabNames[i][2]);

  @override
  void dispose() {
    if (identical(_voice.tabSwitcher, _switchTo)) _voice.tabSwitcher = null;
    super.dispose();
  }

  void _switchTo(int i) {
    setState(() => _index = i);
    // Reload home routine when returning to it (e.g. after generating one)
    if (i == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _homeKey.currentState?.reload();
      });
    }
    _updateReader();
  }

  /// From Home's "Generate" button: open the Explore tab and scroll straight
  /// down to the pinned "Generate Yoga Routine" button.
  void _goGenerate() {
    setState(() => _index = 1);
    _exploreKey.currentState?.scrollToBottom();
  }

  String t(String en, String mr, String hn) => LanguageHelper.t(en, mr, hn);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // back gesture never logs the user out
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on Home, back goes to Home instead of exiting
        if (_index != 0) _switchTo(0);
      },
      // Tap ANYWHERE while it's talking to silence it (accessibility: a blind
      // user can stop a long readout by tapping the screen, without a button).
      // Listener observes taps without consuming them, so normal use is intact.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (_voice.speaking) _voice.stopSpeaking();
        },
        child: Scaffold(
          backgroundColor: AppColors.bgLight,
          extendBody: false,
          body: Stack(
            children: [
              IndexedStack(index: _index, children: _pages),
              // Passive, non-interactive "listening/speaking" status.
              Positioned(
                top: MediaQuery.of(context).padding.top + 6,
                left: 0,
                right: 0,
                child: const Center(child: VoiceStatusIndicator()),
              ),
            ],
          ),
          floatingActionButton: _yogaGptButton(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _bottomBar(),
        ),
      ),
    );
  }

  Widget _yogaGptButton() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'yogagpt_shell',
        elevation: 0,
        backgroundColor: Colors.transparent,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const YogaGptScreen()),
        ),
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7B73E8), Color(0xFF5348C7)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smart_toy_rounded,
              color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return BottomAppBar(
      height: 66,
      color: AppColors.bgCard,
      elevation: 12,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home_rounded, Icons.home_outlined,
              t("Home", "होम", "होम")),
          _navItem(1, Icons.auto_awesome_rounded, Icons.auto_awesome_outlined,
              t("Explore", "शोधा", "एक्सप्लोर")),
          const SizedBox(width: 60), // gap for the FAB
          _navItem(2, Icons.restaurant_rounded, Icons.restaurant_outlined,
              t("Diet", "आहार", "डाइट")),
          _navItem(3, Icons.person_rounded, Icons.person_outline_rounded,
              t("Profile", "प्रोफाइल", "प्रोफ़ाइल")),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData active, IconData inactive, String label) {
    final selected = _index == index;
    return Expanded(
      child: InkWell(
        onTap: () => _switchTo(index),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? active : inactive,
              color: selected ? AppColors.accent : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
