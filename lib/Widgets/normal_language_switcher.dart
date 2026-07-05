// normal_language_switcher.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/language_helper.dart';

class NormalLanguageSwitcher extends StatefulWidget {
  final Offset popupOffset;
  final VoidCallback? onLanguageChanged;

  const NormalLanguageSwitcher({
    super.key,
    this.popupOffset = const Offset(0, 45),
    this.onLanguageChanged,
  });

  @override
  State<NormalLanguageSwitcher> createState() => _NormalLanguageSwitcherState();
}

class _NormalLanguageSwitcherState extends State<NormalLanguageSwitcher> {
  final Color primaryPurple = const Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();

    LanguageHelper.loadLanguage().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _changeLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("language", lang);

    setState(() {
      LanguageHelper.currentLanguage = lang;
    });

    widget.onLanguageChanged?.call();
  }

  Widget _menuItem(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: primaryPurple.withOpacity(0.25)),
      ),

      child: Center(
        child: Text(
          text,

          style: GoogleFonts.poppins(
            color: primaryPurple,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: primaryPurple.withOpacity(0.35), width: 1.2),
      ),

      child: PopupMenuButton<String>(
        offset: widget.popupOffset,

        tooltip: "Select Language",

        color: Colors.transparent,

        elevation: 0,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

        onSelected: (value) {
          _changeLanguage(value);
        },

        itemBuilder: (context) => [
          PopupMenuItem(
            value: "English",

            padding: EdgeInsets.zero,

            height: 42,

            child: _menuItem("English"),
          ),

          PopupMenuItem(
            value: "मराठी",

            padding: EdgeInsets.zero,

            height: 42,

            child: _menuItem("मराठी"),
          ),

          PopupMenuItem(
            value: "हिंदी",

            padding: EdgeInsets.zero,

            height: 42,

            child: _menuItem("हिंदी"),
          ),
        ],

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(Icons.language_rounded, color: primaryPurple, size: 20),

            const SizedBox(width: 8),

            Text(
              LanguageHelper.currentLanguage,

              style: GoogleFonts.poppins(
                color: primaryPurple,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(width: 4),

            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: primaryPurple,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
