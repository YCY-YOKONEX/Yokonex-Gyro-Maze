import 'package:flutter/material.dart';

/// 一张地图对应一套完整的视觉令牌，避免只替换背景而留下风格断层。
@immutable
class MazeThemeData {
  const MazeThemeData({
    required this.id,
    required this.background,
    required this.board,
    required this.path,
    required this.wall,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.ballLight,
    required this.ballDark,
    required this.text,
    required this.muted,
  });

  final String id;
  final Color background;
  final Color board;
  final Color path;
  final Color wall;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color ballLight;
  final Color ballDark;
  final Color text;
  final Color muted;

  static const tide = MazeThemeData(
    id: 'tide',
    background: Color(0xFF080B10),
    board: Color(0xFF101B22),
    path: Color(0xFF1A2931),
    wall: Color(0xFF091017),
    border: Color(0xFF506A72),
    primary: Color(0xFFA7E8E4),
    secondary: Color(0xFFE7B66C),
    ballLight: Color(0xFFF4FFFF),
    ballDark: Color(0xFF5DB5C6),
    text: Color(0xFFEDF3F3),
    muted: Color(0xFF83939A),
  );

  static const ember = MazeThemeData(
    id: 'ember',
    background: Color(0xFF1D0F11),
    board: Color(0xFF34191A),
    path: Color(0xFF563026),
    wall: Color(0xFF140B0C),
    border: Color(0xFFA65E44),
    primary: Color(0xFFFF8A5B),
    secondary: Color(0xFFFFD166),
    ballLight: Color(0xFFFFE0A6),
    ballDark: Color(0xFFE84A36),
    text: Color(0xFFFFF1E6),
    muted: Color(0xFFD8B4A6),
  );

  static const moon = MazeThemeData(
    id: 'moon',
    background: Color(0xFF0D1623),
    board: Color(0xFF16273D),
    path: Color(0xFF2B4160),
    wall: Color(0xFF07101B),
    border: Color(0xFF6C9AB8),
    primary: Color(0xFF9BD8FF),
    secondary: Color(0xFFB8F2E6),
    ballLight: Color(0xFFF5FBFF),
    ballDark: Color(0xFF6FA9D8),
    text: Color(0xFFEAF6FF),
    muted: Color(0xFFA9BDD2),
  );

  static const aurora = MazeThemeData(
    id: 'aurora',
    background: Color(0xFF071A1A),
    board: Color(0xFF103533),
    path: Color(0xFF1B5149),
    wall: Color(0xFF061110),
    border: Color(0xFF4A9C88),
    primary: Color(0xFF63E6BE),
    secondary: Color(0xFFE8F5A2),
    ballLight: Color(0xFFF6FFD1),
    ballDark: Color(0xFF45B98A),
    text: Color(0xFFF0FFF8),
    muted: Color(0xFFA8CDC0),
  );

  static const dusk = MazeThemeData(
    id: 'dusk',
    background: Color(0xFF171226),
    board: Color(0xFF28203D),
    path: Color(0xFF44345D),
    wall: Color(0xFF0E0A19),
    border: Color(0xFF8C70B8),
    primary: Color(0xFFD59BFF),
    secondary: Color(0xFFFFC58A),
    ballLight: Color(0xFFFFE7BD),
    ballDark: Color(0xFFB86AE8),
    text: Color(0xFFF8F0FF),
    muted: Color(0xFFC5B4D8),
  );

  static const oxide = MazeThemeData(
    id: 'oxide',
    background: Color(0xFF171716),
    board: Color(0xFF2A2924),
    path: Color(0xFF4A473B),
    wall: Color(0xFF11110F),
    border: Color(0xFF9C8D63),
    primary: Color(0xFFE1C16E),
    secondary: Color(0xFFE98B5F),
    ballLight: Color(0xFFFFE1A6),
    ballDark: Color(0xFFBF583F),
    text: Color(0xFFFFF7E4),
    muted: Color(0xFFC9BEA4),
  );

  static const presets = [tide, ember, moon, aurora, dusk, oxide];
}

/// MaterialApp 和游戏画布共用的当前主题。
class MazeThemeCatalog {
  static final ValueNotifier<MazeThemeData> current =
      ValueNotifier(MazeThemeData.tide);
}

/// 将地图主题转换为 Flutter 控件主题，保证弹窗、按钮和页面底色一起切换。
ThemeData buildMazeMaterialTheme(MazeThemeData style) {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: style.background,
    fontFamily: 'sans-serif',
    colorScheme: ColorScheme.fromSeed(
      seedColor: style.primary,
      brightness: Brightness.dark,
    ).copyWith(
      surface: style.board,
      primary: style.primary,
      secondary: style.secondary,
      onSurface: style.text,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: style.board,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: style.border.withValues(alpha: 0.7)),
      ),
      titleTextStyle: TextStyle(
        color: style.text,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        fontFamily: 'serif',
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: style.board,
      contentTextStyle: TextStyle(color: style.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
