import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 商城模块设计色板（跨页面共享）。
///
/// 品牌色系与全局一致：紫粉替代参考项目的橙色，价格用暖红。
class ShopColors {
  ShopColors._();

  static const Color bg = Color(0xFFF7F4F2); // 页面暖米底（与宠物页一致）
  static const Color ink = Color(0xFF3D2E33); // 主文字
  static const Color sub = Color(0xFFA89EA2); // 次要文字
  static const Color pink = Color(0xFFB08CA0); // 品牌/标签粉（主按钮色）
  static const Color tagBg = Color(0xFFF6ECEF); // 标签底
  static const Color price = Color(0xFFCF5B4E); // 价格暖红（与品牌色和谐）

  /// 固定标题条渐变：紫粉渐变，全部不透明
  /// （内容从固定头下方滚过时不能透出）。
  static const LinearGradient titleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF8E6B84), Color(0xFFB48CA3), Color(0xFFE5D2DC)],
    stops: [0.0, 0.45, 1.0],
  );
}
