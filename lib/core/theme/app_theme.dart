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
  ///
  /// 注意：TDesign 的按压/长按/聚焦/禁用态用的是 brandColorActive / brandColorLight /
  /// brandColorLightActive / brandColorFocus / brandColorDisabled 等独立 Token，
  /// 不覆盖会回落到默认腾讯蓝（brandColor3/8 等），导致按钮点击时变蓝，
  /// 必须与 brandColor 一并覆盖。
  static final TThemeData lightToken = _defaultToken.copyWith(
    name: 'appLight',
    colorMap: {
      'brandColor': brandColor,
      'brandColorActive': const Color(0xFF6A5460), // fill 按钮按下（加深）
      'brandColorDisabled': const Color(0xFFD9CBD2), // 禁用态
      'brandColorLight': const Color(0xFFF4EEF1), // 长按高亮
      'brandColorLightActive': const Color(0xFFEADCE3), // 按下激活
      'brandColorFocus': const Color(0xFFF4EEF1), // 聚焦
      'bgColorPage': const Color(0xFFF7F7F8),
    },
  );

  /// 深色主题 Token，基于默认深色主题派生。
  static final TThemeData darkToken = (_defaultToken.dark ?? _defaultToken)
      .copyWith(
        name: 'appDark',
        colorMap: {
          'brandColor': const Color(0xFFA88C99),
          'brandColorActive': const Color(0xFF8F7582),
          'brandColorDisabled': const Color(0xFF3A3036),
          'brandColorLight': const Color(0xFF3A3036),
          'brandColorLightActive': const Color(0xFF463A41),
          'brandColorFocus': const Color(0xFF3A3036),
        },
      );

  /// 浅色 ThemeData。
  static ThemeData get light => TThemeBuilder.light(lightToken);

  /// 深色 ThemeData。
  static ThemeData get dark => TThemeBuilder.dark(darkToken);
}
