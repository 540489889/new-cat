import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 全局主题配置。
///
/// TDesign 1.x 的主题入口是 [TThemeData]（设计 Token）+ [TThemeBuilder]
/// （Token -> Material ThemeData）。品牌色只要覆盖 `brandColor` Token，
/// 其它组件颜色都会按 TDesign 的引用关系自动跟随。
class AppTheme {
  AppTheme._();

  /// TDesign 内置默认 Token（含浅色 `light` 与深色 `dark`）。
  static final TThemeData _defaultToken = TThemeData.defaultData();

  /// 品牌主色，替换成自己的品牌色即可。
  static const Color brandColor = Color(0xFF7F6370);

  /// 浅色主题 Token。
  static final TThemeData lightToken = _defaultToken.copyWith(
    name: 'appLight',
    colorMap: {
      'brandColor': brandColor,
      'bgColorPage': const Color(0xFFF7F7F8),
    },
  );

  /// 深色主题 Token，基于默认深色主题派生。
  static final TThemeData darkToken = (_defaultToken.dark ?? _defaultToken)
      .copyWith(
        name: 'appDark',
        colorMap: {'brandColor': const Color(0xFFA88C99)},
      );

  /// 浅色 ThemeData。
  static ThemeData get light => TThemeBuilder.light(lightToken);

  /// 深色 ThemeData。
  static ThemeData get dark => TThemeBuilder.dark(darkToken);
}
