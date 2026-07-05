import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'routine_screen.dart';
import 'recommendations_screen.dart';
import 'diet_screen.dart';
import 'settings_screen.dart';
import 'yoga_gpt_screen.dart';

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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = [
      RoutineScreen(
        key: _homeKey,
        routine: widget.initialRoutine,
        embedded: true,
        onSwitchTab: _switchTo,
      ),
      RecommendationsScreen(embedded: true, onSwitchTab: _switchTo),
      const DietScreen(embedded: true),
      const SettingsScreen(),
    ];
  }

  void _switchTo(int i) {
    setState(() => _index = i);
    // Reload home routine when returning to it (e.g. after generating one)
    if (i == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _homeKey.currentState?.reload();
      });
    }
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
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        extendBody: false,
        body: IndexedStack(index: _index, children: _pages),
        floatingActionButton: _yogaGptButton(),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _bottomBar(),
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
