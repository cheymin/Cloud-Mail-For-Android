import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/storage.dart';

/// UI 风格枚举
enum UiStyle { google, apple }

extension UiStyleX on UiStyle {
  String get label => this == UiStyle.google ? 'google' : 'apple';
  static UiStyle fromString(String s) =>
      s == 'apple' ? UiStyle.apple : UiStyle.google;
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  UiStyle _uiStyle = UiStyle.google;

  // 个性化
  Color? _customPrimaryColor;
  String? _customFontFamily;
  String? _customBackgroundImage;
  // 用户导入的自定义字体文件路径（持久化到文档目录）
  String? _customFontPath;

  ThemeMode get themeMode => _themeMode;
  UiStyle get uiStyle => _uiStyle;
  bool get isGoogle => _uiStyle == UiStyle.google;
  bool get isApple => _uiStyle == UiStyle.apple;

  Color? get customPrimaryColor => _customPrimaryColor;
  String? get customFontFamily => _customFontFamily;
  String? get customBackgroundImage => _customBackgroundImage;
  String? get customFontPath => _customFontPath;

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
    _uiStyle = UiStyleX.fromString(StorageService.uiStyle);
    final colorVal = StorageService.customPrimaryColor;
    _customPrimaryColor = colorVal == null ? null : Color(colorVal);
    _customFontFamily = StorageService.customFontFamily;
    _customFontPath = StorageService.customFontPath;
    _customBackgroundImage = StorageService.customBackgroundImage;
    // 如果有导入的自定义字体文件，异步加载（不阻塞 init）
    if (_customFontPath != null && _customFontFamily != null) {
      _loadFontFile(_customFontPath!, _customFontFamily!);
    }
    notifyListeners();
  }

  /// 加载字体文件到 Flutter 字体注册表
  Future<void> _loadFontFile(String path, String familyName) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final loader = FontLoader(familyName);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    } catch (_) {}
  }

  /// 导入自定义字体文件
  /// [sourcePath] file_picker 返回的源文件路径
  /// [displayName] 字体显示名（用于 fontFamily 引用）
  Future<void> importCustomFont(String sourcePath, String displayName) async {
    // 复制到应用文档目录持久化（file_picker 缓存路径可能被系统清理）
    final dir = await getApplicationDocumentsDirectory();
    final fontsDir = Directory('${dir.path}/fonts');
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }
    final ext = sourcePath.contains('.')
        ? sourcePath.split('.').last
        : 'ttf';
    final destPath = '${fontsDir.path}/$displayName.$ext';
    await File(sourcePath).copy(destPath);

    // 加载字体到注册表
    await _loadFontFile(destPath, displayName);

    _customFontPath = destPath;
    _customFontFamily = displayName;
    StorageService.customFontPath = destPath;
    StorageService.customFontFamily = displayName;
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

  void setUiStyle(UiStyle style) {
    _uiStyle = style;
    StorageService.uiStyle = style.label;
    notifyListeners();
  }

  /// 自定义主题色，传 null 恢复默认
  void setCustomPrimaryColor(Color? color) {
    _customPrimaryColor = color;
    StorageService.customPrimaryColor = color?.value;
    notifyListeners();
  }

  /// 自定义字体，传 null 恢复默认
  /// 切换字体家族名时不清除已导入的字体文件路径，
  /// 这样用户可以随时在导入字体和内置字体之间切换
  void setCustomFontFamily(String? family) {
    _customFontFamily = family;
    StorageService.customFontFamily = family;
    notifyListeners();
  }

  /// 自定义背景图路径，传 null 移除
  void setCustomBackgroundImage(String? path) {
    _customBackgroundImage = path;
    StorageService.customBackgroundImage = path;
    notifyListeners();
  }

  /// 当前是否启用了自定义背景图
  bool get hasCustomBackground => _customBackgroundImage != null;
}

/// 账户标识色板（两种风格共用）
class AppTheme {
  static const List<Color> accountColors = [
    Color(0xFFEA4335), // Google 红
    Color(0xFFFF9500), // 橙
    Color(0xFFFFCC00), // 黄
    Color(0xFF34C759), // 绿
    Color(0xFF00C7BE), // 青
    Color(0xFF1A73E8), // Google 蓝
    Color(0xFF5856D6), // 靛
    Color(0xFFAF52DE), // 紫
    Color(0xFFFF2D55), // 粉
  ];

  static Color accountColor(String email) {
    final hash = email.hashCode;
    return accountColors[hash.abs() % accountColors.length];
  }

  // ==================== Google 风主题 ====================

  static ThemeData googleLight() {
    const primary = Color(0xFF1A73E8);
    const surface = Color(0xFFFEFBFF);
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFD3E3FD),
        onPrimaryContainer: Color(0xFF001D35),
        secondary: Color(0xFF565E71),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFDAE2F9),
        onSecondaryContainer: Color(0xFF131C2B),
        tertiary: Color(0xFF6C5777),
        onTertiary: Colors.white,
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: surface,
        onBackground: Color(0xFF1B1B1F),
        surface: surface,
        onSurface: Color(0xFF1B1B1F),
        surfaceVariant: Color(0xFFE1E2EC),
        onSurfaceVariant: Color(0xFF44474F),
        outline: Color(0xFF74777F),
        outlineVariant: Color(0xFFC4C6D0),
        inverseSurface: Color(0xFF303034),
        onInverseSurface: Color(0xFFF2F0F4),
        inversePrimary: Color(0xFFA4C8FF),
        surfaceTint: primary,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: Color(0xFF1B1B1F),
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
        iconTheme: IconThemeData(color: primary),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minVerticalPadding: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFE1E2EC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999), // pill
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          side: const BorderSide(color: Color(0xFF74777F)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFC4C6D0),
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: primary, size: 24),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 57, fontWeight: FontWeight.w400,
            color: Color(0xFF1B1B1F), height: 1.12),
        displayMedium: TextStyle(
            fontSize: 45, fontWeight: FontWeight.w400,
            color: Color(0xFF1B1B1F), height: 1.16),
        displaySmall: TextStyle(
            fontSize: 36, fontWeight: FontWeight.w400,
            color: Color(0xFF1B1B1F), height: 1.22),
        headlineLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w400,
            color: Color(0xFF1B1B1F), height: 1.25),
        headlineMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w400,
            color: Color(0xFF1B1B1F), height: 1.29),
        headlineSmall: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w400,
            color: Color(0xFF1B1B1F), height: 1.33),
        titleLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w500,
            color: Color(0xFF1B1B1F), height: 1.27),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500,
            color: Color(0xFF1B1B1F), height: 1.5, letterSpacing: 0.15),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: Color(0xFF1B1B1F), height: 1.43, letterSpacing: 0.1),
        bodyLarge: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w400,
            color: Color(0xFF1B1B1F), height: 1.5, letterSpacing: 0.5),
        bodyMedium: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400,
            color: Color(0xFF1B1B1F), height: 1.43, letterSpacing: 0.25),
        bodySmall: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w400,
            color: Color(0xFF44474F), height: 1.33, letterSpacing: 0.4),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: primary, height: 1.43, letterSpacing: 0.1),
        labelMedium: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: Color(0xFF44474F), height: 1.33, letterSpacing: 0.5),
        labelSmall: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: Color(0xFF44474F), height: 1.45, letterSpacing: 0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF313033),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE1E2EC),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF1B1B1F)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: CircleBorder(),
      ),
    );
  }

  static ThemeData googleDark() {
    const primary = Color(0xFFA4C8FF);
    const surface = Color(0xFF1B1B1F);
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Color(0xFF002F65),
        primaryContainer: Color(0xFF00468A),
        onPrimaryContainer: Color(0xFFD3E3FD),
        secondary: Color(0xFFBEC6DC),
        onSecondary: Color(0xFF283041),
        secondaryContainer: Color(0xFF3E4759),
        onSecondaryContainer: Color(0xFFDAE2F9),
        tertiary: Color(0xFFD7BFE3),
        onTertiary: Color(0xFF3B2947),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        background: surface,
        onBackground: Color(0xFFE3E2E6),
        surface: surface,
        onSurface: Color(0xFFE3E2E6),
        surfaceVariant: Color(0xFF44474F),
        onSurfaceVariant: Color(0xFFC4C6D0),
        outline: Color(0xFF8E9099),
        outlineVariant: Color(0xFF44474F),
        inverseSurface: Color(0xFFE3E2E6),
        onInverseSurface: Color(0xFF1B1B1F),
        inversePrimary: Color(0xFF1A73E8),
        surfaceTint: primary,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF2B2B2F),
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minVerticalPadding: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF44474F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF002F65),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF002F65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          side: const BorderSide(color: Color(0xFF8E9099)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF44474F),
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: primary, size: 24),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 57, fontWeight: FontWeight.w400,
            color: Colors.white, height: 1.12),
        displayMedium: TextStyle(
            fontSize: 45, fontWeight: FontWeight.w400,
            color: Colors.white, height: 1.16),
        displaySmall: TextStyle(
            fontSize: 36, fontWeight: FontWeight.w400,
            color: Colors.white, height: 1.22),
        headlineLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w400,
            color: Colors.white, height: 1.25),
        headlineMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w400,
            color: Colors.white, height: 1.29),
        headlineSmall: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w400,
            color: Colors.white, height: 1.33),
        titleLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w500,
            color: Colors.white, height: 1.27),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500,
            color: Colors.white, height: 1.5, letterSpacing: 0.15),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: Colors.white, height: 1.43, letterSpacing: 0.1),
        bodyLarge: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w400,
            color: Colors.white, height: 1.5, letterSpacing: 0.5),
        bodyMedium: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400,
            color: Colors.white, height: 1.43, letterSpacing: 0.25),
        bodySmall: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w400,
            color: Color(0xFFC4C6D0), height: 1.33, letterSpacing: 0.4),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: primary, height: 1.43, letterSpacing: 0.1),
        labelMedium: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: Color(0xFFC4C6D0), height: 1.33, letterSpacing: 0.5),
        labelSmall: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: Color(0xFFC4C6D0), height: 1.45, letterSpacing: 0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFE3E2E6),
        contentTextStyle: const TextStyle(color: Color(0xFF1B1B1F), fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF44474F),
        labelStyle: const TextStyle(fontSize: 13, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Color(0xFF002F65),
        elevation: 3,
        shape: CircleBorder(),
      ),
    );
  }

  // ==================== Apple 风主题 ====================

  static ThemeData appleLight() {
    const primary = Color(0xFF007AFF);
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE3F0FF),
        onPrimaryContainer: Color(0xFF0A3D6E),
        secondary: Color(0xFF5856D6),
        onSecondary: Colors.white,
        tertiary: Color(0xFF34C759),
        error: Color(0xFFFF3B30),
        onError: Colors.white,
        background: Color(0xFFF2F2F7),
        onBackground: Color(0xFF1C1C1E),
        surface: Colors.white,
        onSurface: Color(0xFF1C1C1E),
        surfaceVariant: Color(0xFFE5E5EA),
        onSurfaceVariant: Color(0xFF3C3C43),
        outline: Color(0xFFC6C6C8),
        outlineVariant: Color(0xFFE5E5EA),
        inverseSurface: Color(0xFF3C3C43),
        onInverseSurface: Color(0xFFF2F2F7),
        inversePrimary: Color(0xFF6BA8FF),
        surfaceTint: primary,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: Color(0xFF1C1C1E),
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
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
      ),
      iconTheme: const IconThemeData(color: primary, size: 22),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E), height: 1.1),
        headlineLarge: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E), height: 1.1),
        headlineMedium: TextStyle(
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
            color: primary),
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
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 1,
        shape: CircleBorder(),
      ),
    );
  }

  static ThemeData appleDark() {
    const primary = Color(0xFF0A84FF);
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF0A3D6E),
        onPrimaryContainer: Color(0xFFB0D4FF),
        secondary: Color(0xFF5E5CE6),
        onSecondary: Colors.white,
        tertiary: Color(0xFF30D158),
        error: Color(0xFFFF453A),
        onError: Colors.white,
        background: Colors.black,
        onBackground: Colors.white,
        surface: Color(0xFF1C1C1E),
        onSurface: Colors.white,
        surfaceVariant: Color(0xFF2C2C2E),
        onSurfaceVariant: Color(0xFFEBEBF5),
        outline: Color(0xFF38383A),
        outlineVariant: Color(0xFF2C2C2E),
        inverseSurface: Color(0xFFEBEBF5),
        onInverseSurface: Color(0xFF3C3C43),
        inversePrimary: Color(0xFF0A84FF),
        surfaceTint: primary,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
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
        color: Color(0xFF38383A),
        thickness: 0.5,
        space: 0.5,
      ),
      iconTheme: const IconThemeData(color: primary, size: 22),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.bold,
            color: Colors.white, height: 1.1),
        headlineLarge: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold,
            color: Colors.white, height: 1.1),
        headlineMedium: TextStyle(
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
            color: primary),
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
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 1,
        shape: CircleBorder(),
      ),
    );
  }

  /// 根据 UI 风格 + 明暗模式返回对应主题
  /// [customPrimary] 自定义主题色（覆盖默认 primary）
  /// [fontFamily] 自定义字体家族（应用到全局文字）
  static ThemeData resolve(
    UiStyle style,
    Brightness brightness, {
    Color? customPrimary,
    String? fontFamily,
  }) {
    ThemeData theme;
    if (style == UiStyle.google) {
      theme = brightness == Brightness.dark ? googleDark() : googleLight();
    } else {
      theme = brightness == Brightness.dark ? appleDark() : appleLight();
    }

    if (customPrimary != null || fontFamily != null) {
      theme = theme.copyWith(
        colorScheme: customPrimary == null
            ? theme.colorScheme
            : theme.colorScheme.copyWith(
                primary: customPrimary,
                primaryContainer: _lighten(customPrimary, brightness == Brightness.dark ? -0.3 : 0.85),
                onPrimaryContainer: brightness == Brightness.dark
                    ? _lighten(customPrimary, 0.6)
                    : _darken(customPrimary, 0.5),
                inversePrimary: _lighten(customPrimary, 0.3),
                surfaceTint: customPrimary,
              ),
        appBarTheme: theme.appBarTheme.copyWith(
          iconTheme: customPrimary == null
              ? null
              : IconThemeData(color: customPrimary),
        ),
        iconTheme: customPrimary == null
            ? null
            : IconThemeData(color: customPrimary, size: theme.iconTheme.size),
        textTheme: fontFamily == null
            ? null
            : _applyFontFamily(theme.textTheme, fontFamily),
        primaryTextTheme: fontFamily == null
            ? null
            : _applyFontFamily(theme.primaryTextTheme, fontFamily),
      );
    }
    return theme;
  }

  /// 给 TextTheme 中所有样式应用字体家族
  static TextTheme _applyFontFamily(TextTheme base, String family) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFamily: family),
      displayMedium: base.displayMedium?.copyWith(fontFamily: family),
      displaySmall: base.displaySmall?.copyWith(fontFamily: family),
      headlineLarge: base.headlineLarge?.copyWith(fontFamily: family),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: family),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: family),
      titleLarge: base.titleLarge?.copyWith(fontFamily: family),
      titleMedium: base.titleMedium?.copyWith(fontFamily: family),
      titleSmall: base.titleSmall?.copyWith(fontFamily: family),
      bodyLarge: base.bodyLarge?.copyWith(fontFamily: family),
      bodyMedium: base.bodyMedium?.copyWith(fontFamily: family),
      bodySmall: base.bodySmall?.copyWith(fontFamily: family),
      labelLarge: base.labelLarge?.copyWith(fontFamily: family),
      labelMedium: base.labelMedium?.copyWith(fontFamily: family),
      labelSmall: base.labelSmall?.copyWith(fontFamily: family),
    );
  }

  /// 颜色调亮（amount 0~1）
  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// 颜色调暗（amount 0~1）
  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
