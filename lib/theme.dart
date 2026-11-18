import 'package:flutter/material.dart';

// المُلزم — Midnight Intelligence identity (dark). One palette shared by every screen.
const kBg = Color(0xFF0B1020);        // main background
const kSurface = Color(0xFF151D32);   // cards
const kSurface2 = Color(0xFF1D2943);  // elevated surfaces / inputs
const kAccent = Color(0xFF657CFF);    // primary (indigo)
const kCyan = Color(0xFF42D9E8);      // secondary (cyan)
const kInk = Color(0xFFF2F5FF);       // primary text
const kInk2 = Color(0xFF9BA9C5);      // secondary text
const kOk = Color(0xFF35B985);        // success
const kWarn = Color(0xFFE9AE51);      // warning
const kErr = Color(0xFFE66C78);       // error
const kOutline = Color(0xFF2A3654);

// Aliases kept so the study screens (ex-Al-Murshid) and the focus screens (ex-Focus Lock) share one palette
const kMoss = kAccent;
const kForest = kAccent;
const kGold = kWarn;
const kBrown = kCyan;
const kBrownLight = Color(0xFF2A3566); // selected chip / nav indicator
const kBrownDark = kInk;               // titles

const kFont = 'Tajawal';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kAccent, brightness: Brightness.dark).copyWith(
    primary: kAccent,
    onPrimary: Colors.white,
    secondary: kCyan,
    onSecondary: kBg,
    tertiary: kCyan,
    surface: kSurface,
    onSurface: kInk,
    surfaceContainerHighest: kSurface2,
    outline: kOutline,
    error: kErr,
  );
  final shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: kFont,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent, // AppBackdrop paints the page
    canvasColor: kBg,
    dividerColor: kOutline,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kAccent),
    listTileTheme: const ListTileThemeData(iconColor: kAccent),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kBrownLight,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w700)),
    ),
    chipTheme: ChipThemeData(
      selectedColor: kBrownLight,
      backgroundColor: kSurface2,
      side: const BorderSide(color: kOutline),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: kInk, fontFamily: kFont),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: kFont, fontSize: 20, fontWeight: FontWeight.w800, color: kInk),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: shape14,
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        side: const BorderSide(color: kOutline),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: shape14,
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kCyan)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: kAccent, foregroundColor: Colors.white),
    dialogTheme: DialogThemeData(backgroundColor: kSurface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kSurface2,
      contentTextStyle: const TextStyle(color: kInk, fontFamily: kFont),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
  );
}

/// Rounded card used by lists everywhere (16px; main panels 22px)
BoxDecoration cardBox([double r = 16]) => BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: kOutline),
    );

/// Page background: midnight with a soft indigo glow in the top corner
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kBg,
          gradient: RadialGradient(center: Alignment(0.9, -1.0), radius: 1.3, colors: [Color(0xFF16204A), kBg]),
        ),
        child: child,
      );
}
