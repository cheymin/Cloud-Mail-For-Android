import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/storage.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void init() {
    final stored = StorageService.themeMode;
    switch (stored) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    switch (mode) {
      case ThemeMode.light:
        StorageService.themeMode = 'light';
        break;
      case ThemeMode.dark:
        StorageService.themeMode = 'dark';
        break;
      case ThemeMode.system:
        StorageService.themeMode = 'system';
        break;
    }
    notifyListeners();
  }
}

/// Mimestream 风格主题
/// 灵感来自 macOS 原生邮件客户端：蓝色强调色、简洁留白、内嵌式列表、柔和阴影
class AppTheme {
  // macOS 系统蓝色（Mimestream 跟随系统强调色，默认蓝）
  static const Color primary = Color(0xFF007AFF);
  static const Color secondary = Color(0xFF5856D6);
  static const Color accent = Color(0xFF34C759);

  // 账户标识色板（Mimestream 的 color-coded accounts）
  static const List<Color> accountColors = [
    Color(0xFFFF3B30), // 红
    Color(0xFFFF9500), // 橙
    Color(0xFFFFCC00), // 黄
    Color(0xFF34C759), // 绿
    Color(0xFF00C7BE), // 青
    Color(0xFF007AFF), // 蓝
    Color(0xFF5856D6), // 靛
    Color(0xFFAF52DE), // 紫
    Color(0xFFFF2D55), // 粉
  ];

  static Color accountColor(String email) {
    final hash = email.hashCode;
    return accountColors[hash.abs() % accountColors.length];
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE3F0FF),
        onPrimaryContainer: Color(0xFF0A3D6E),
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accent,
        error: Color(0xFFFF3B30),
        onError: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF1C1C1E),
        surfaceVariant: Color(0xFFF2F2F7),
        onSurfaceVariant: Color(0xFF3C3C43),
        outline: Color(0xFFC6C6C8),
        outlineVariant: Color(0xFFE5E5EA),
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: Color(0xFF1C1C1E),
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Color(0xFF007AFF)),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minVerticalPadding: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFE5E5EA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E5EA),
        thickness: 0.5,
        space: 0.5,
        indent: 0,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF007AFF),
        size: 22,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E), height: 1.1),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E), height: 1.1),
        headlineLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E)),
        titleLarge: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E)),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E)),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E)),
        bodyLarge: TextStyle(
            fontSize: 16, color: Color(0xFF1C1C1E), height: 1.4),
        bodyMedium: TextStyle(
            fontSize: 14, color: Color(0xFF1C1C1E), height: 1.4),
        bodySmall: TextStyle(
            fontSize: 12, color: Color(0xFF8E8E93), height: 1.4),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: Color(0xFF007AFF)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C1E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE5E5EA),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF0A84FF),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF0A3D6E),
        onPrimaryContainer: Color(0xFFB0D4FF),
        secondary: Color(0xFF5E5CE6),
        onSecondary: Colors.white,
        tertiary: Color(0xFF30D158),
        error: Color(0xFFFF453A),
        onError: Colors.white,
        surface: Color(0xFF1C1C1E),
        onSurface: Colors.white,
        surfaceVariant: Color(0xFF2C2C2E),
        onSurfaceVariant: Color(0xFFEBEBF5),
        outline: Color(0xFF38383A),
        outlineVariant: Color(0xFF2C2C2E),
      ),
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Color(0xFF0A84FF)),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF1C1C1E),
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minVerticalPadding: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A84FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0A84FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF0A84FF),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF38383A),
        thickness: 0.5,
        space: 0.5,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF0A84FF),
        size: 22,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.bold,
            color: Colors.white, height: 1.1),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold,
            color: Colors.white, height: 1.1),
        headlineLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
        bodySmall: TextStyle(
            fontSize: 12, color: Color(0xFF8E8E93), height: 1.4),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: Color(0xFF0A84FF)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C2C2E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        labelStyle: const TextStyle(fontSize: 13, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
      ),
    );
  }
}
