import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/language_helper.dart';

class LanguageSwitcher extends StatefulWidget {
  final Offset popupOffset;
  final VoidCallback? onLanguageChanged;

  const LanguageSwitcher({
    super.key,
    this.popupOffset = const Offset(25, 20),
    this.onLanguageChanged,
  });

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
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

  Widget _glassMenuItem(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),

      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),

        child: SizedBox(
          width: 100,

          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),

            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),

              borderRadius: BorderRadius.circular(14),

              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),

            child: Center(
              child: Text(
                text,

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),

      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),

        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),

          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),

            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          ),

          child: PopupMenuButton<String>(
            offset: widget.popupOffset,

            tooltip: "Select Language",

            color: Colors.transparent,

            elevation: 0,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),

            onSelected: (value) {
              _changeLanguage(value);
            },

            itemBuilder: (context) => [
              PopupMenuItem(
                value: "English",

                padding: EdgeInsets.zero,

                height: 30,

                child: _glassMenuItem("English"),
              ),

              PopupMenuItem(
                value: "मराठी",

                padding: EdgeInsets.zero,

                height: 30,

                child: _glassMenuItem("मराठी"),
              ),

              PopupMenuItem(
                value: "हिंदी",

                padding: EdgeInsets.zero,

                height: 30,

                child: _glassMenuItem("हिंदी"),
              ),
            ],

            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Icon(
                  Icons.language_rounded,
                  color: Colors.white,
                  size: 20,
                ),

                const SizedBox(width: 8),

                Text(
                  LanguageHelper.currentLanguage,

                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(width: 4),

                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
