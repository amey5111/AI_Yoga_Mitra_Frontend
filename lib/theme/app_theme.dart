import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP COLORS
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const Color lavender      = Color(0xFFB8B2FF);
  static const Color lilac         = Color(0xFFD9CCFF);
  static const Color indigoDark    = Color(0xFF2E2A5E);
  static const Color softWhite     = Color(0xFFFCFBFF);
  static const Color accent        = Color(0xFF6C63FF);
  static const Color accentDark    = Color(0xFF4B44CC);
  static const Color mistCard      = Color(0x2EFFFFFF);
  static const Color borderTint    = Color(0x38FFFFFF);
  static const Color bgLight       = Color(0xFFF5F3FF);
  static const Color bgCard        = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1E1B4B);
  static const Color textSecondary = Color(0xFF6B6B8A);
  static const Color textLight     = Color(0xFFFFFFFF);
  static const Color chipSelected  = Color(0xFF6C63FF);
  static const Color chipBg        = Color(0xFFEDE9FF);
  static const Color success       = Color(0xFF4CAF50);
  static const Color warning       = Color(0xFFFF9800);
  static const Color error         = Color(0xFFE53935);
  static const Color divider       = Color(0xFFE8E4FF);
  static const Color shadowColor   = Color(0x1A6C63FF);
}

// ─────────────────────────────────────────────────────────────────────────────
// APP GRADIENTS
// ─────────────────────────────────────────────────────────────────────────────
class AppGradients {
  static const LinearGradient heroBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA89EFF), Color(0xFF7B73E8), Color(0xFF5E57D1)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB8B2FF), Color(0xFF8B84F8)],
  );

  static const LinearGradient routineCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B73E8), Color(0xFF5348C7)],
  );

  static const LinearGradient softBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FF)],
  );

  static const LinearGradient welcomeBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B95F5), Color(0xFF7B73E8), Color(0xFF5E57D1), Color(0xFF4B44CC)],
    stops: [0.0, 0.35, 0.7, 1.0],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// APP SHADOWS
// ─────────────────────────────────────────────────────────────────────────────
class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 20,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: const Color(0x0D000000),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get button => [
    BoxShadow(
      color: AppColors.accent.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// APP TEXT STYLES
// ─────────────────────────────────────────────────────────────────────────────
class AppTextStyles {
  static TextStyle heroTitle({Color color = AppColors.softWhite}) =>
      GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.15,
      );

  static TextStyle heading1({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      );

  static TextStyle heading2({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle heading3({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle body({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  static TextStyle bodyMedium({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle caption({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle label({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.8,
      );

  static TextStyle tagline({Color color = AppColors.softWhite}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color.withOpacity(0.85),
        fontStyle: FontStyle.italic,
        height: 1.5,
      );

  static TextStyle button({Color color = AppColors.softWhite}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.3,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Premium pill-shaped primary button with gradient and shadow
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double? width;
  final IconData? icon;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B73E8), Color(0xFF5348C7)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.button,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(label, style: AppTextStyles.button()),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary button
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? textColor;

  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = textColor ?? AppColors.accent;
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: tc.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: tc.withOpacity(0.06),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: tc, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppTextStyles.button(color: tc)),
          ],
        ),
      ),
    );
  }
}

/// Glass morphism card container
class AppGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? bg;

  const AppGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg ?? AppColors.mistCard,
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        border: Border.all(color: AppColors.borderTint, width: 1.2),
      ),
      child: child,
    );
  }
}

/// Standard white card with purple shadow
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? borderRadius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(borderRadius ?? 18),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius ?? 18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? 18),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Premium input decoration
InputDecoration appInputDecoration({
  required String label,
  String? hint,
  IconData? prefixIcon,
  Widget? suffix,
  Color? fillColor,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: GoogleFonts.inter(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: GoogleFonts.inter(
      color: AppColors.textSecondary.withOpacity(0.5),
      fontSize: 14,
    ),
    filled: true,
    fillColor: fillColor ?? AppColors.bgLight,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: AppColors.accent.withOpacity(0.7), size: 20)
        : null,
    suffix: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: AppColors.divider,
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.error, width: 1.8),
    ),
  );
}

/// Section header with optional icon
class AppSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final EdgeInsets? padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
          ],
          Text(title, style: AppTextStyles.heading2()),
        ],
      ),
    );
  }
}

/// Premium chip for tags and selections
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.chipBg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
            width: 1.2,
          ),
          boxShadow: selected ? AppShadows.button : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : AppColors.accent,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated loading screen widget
class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  const AppLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.softBg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.card,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                strokeWidth: 3,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// App AppBar with gradient
PreferredSizeWidget appBar({
  required String title,
  List<Widget>? actions,
  bool centerTitle = false,
  Color? bgColor,
  bool showBackButton = true,
  VoidCallback? onBack,
  BuildContext? context,
}) {
  return AppBar(
    title: Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    centerTitle: centerTitle,
    backgroundColor: bgColor ?? AppColors.accent,
    elevation: 0,
    automaticallyImplyLeading: showBackButton,
    foregroundColor: Colors.white,
    actions: actions,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B73E8), Color(0xFF5348C7)],
        ),
      ),
    ),
  );
}

/// ThemeData for the whole app
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      secondary: AppColors.lavender,
      surface: AppColors.bgCard,
      background: AppColors.bgLight,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
    fontFamily: GoogleFonts.inter().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: AppColors.bgCard,
      surfaceTintColor: Colors.transparent,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.selected)
            ? AppColors.accent
            : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: AppColors.accent, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.all(AppColors.accent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      thumbColor: AppColors.accent,
      inactiveTrackColor: AppColors.chipBg,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.chipBg,
      selectedColor: AppColors.accent,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.accent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      side: const BorderSide(color: AppColors.divider),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.indigoDark,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
