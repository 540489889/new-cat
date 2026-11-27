import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pet/pet_state.dart';
import '../../core/router/app_router.dart';
import 'pet_picker.dart';

/// 顶部「宠物名 + 切换箭头 + 消息铃铛」的统一一行。
///
/// 首页的透明切换条与滚动后的毛玻璃吸顶条共用它，
/// 保证两处的名字来源、字号、箭头与点击行为完全一致
/// （后续其它页面需要同样的宠物切换入口时也直接复用）。
class PetHeaderRow extends StatelessWidget {
  const PetHeaderRow({
    super.key,
    this.titleColor = Colors.black,
    this.titleFontSize = 15,
    this.titleFontWeight = FontWeight.w700,
    this.arrowColor = const Color(0xFF7F6370),
    this.bellSize = 28,
    this.bellColor,
    this.fallbackName = '超级喵克，哎喵',
    this.pill = false,
  });

  /// 宠物名文字颜色与字号。
  final Color titleColor;
  final double titleFontSize;
  final FontWeight titleFontWeight;

  /// 名字右侧切换箭头颜色。
  final Color arrowColor;

  /// 右侧消息铃铛尺寸。
  final double bellSize;

  /// 铃铛染色；为 null 时保留图标原色（玫瑰色实心图）。
  final Color? bellColor;

  /// 还没选到宠物时的占位名。
  final String fallbackName;

  /// 是否为「玻璃胶囊」形态：名字组与铃铛各垫一颗半透明白胶囊，
  /// 压在视频/头图上依然读得清；吸顶条本身已有底，不需要再套。
  final bool pill;

  /// 胶囊高度（圆角取一半，得到标准胶囊）。
  static const double _pillHeight = 36;

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetState>();
    final name = pet.selectedPet?.nickname.isNotEmpty == true
        ? pet.selectedPet!.nickname
        : fallbackName;

    // 只让名字与铃铛响应点击，避免整行拦截下方内容的手势
    final nameGroup = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showPetPicker(context, pet),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            // 首帧/分屏时宽度可能小于 120，直接相减会得到负约束并触发
            // BoxConstraints 断言，这里兜底到最小 80
            constraints: BoxConstraints(
              maxWidth: (MediaQuery.sizeOf(context).width - 160).clamp(
                80.0,
                double.infinity,
              ),
            ),
            child: Text(
              name,
              style: TextStyle(
                color: titleColor,
                fontSize: titleFontSize,
                fontWeight: titleFontWeight,
                height: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Image(
            image: const AssetImage('assets/images/icon/swich-1.png'),
            // 固定 8px：两处共用同一尺寸，滚动接管时箭头不会跳
            width: 8,
            height: 8,
            color: arrowColor,
          ),
        ],
      ),
    );

    final bellButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.news),
      // 统一用矢量铃铛：位图 lb-ico.png 缩到 20px 时底边会糊成一个圆点，
      // 且两处（透明条 / 毛玻璃条）会换图标、滚动接管时跳风格
      child: Icon(
        Icons.notifications_none_rounded,
        size: bellSize + 2,
        color: bellColor ?? titleColor,
      ),
    );

    if (!pill) {
      return Row(
        children: [
          nameGroup,
          const Spacer(),
          bellButton,
        ],
      );
    }

    // 左右各一颗胶囊：中间留空让视频透出来，两端各自成组
    return Row(
      children: [
        _GlassPill(
          height: _pillHeight,
          horizontalPadding: 14,
          child: nameGroup,
        ),
        const Spacer(),
        _GlassPill(
          height: _pillHeight,
          width: _pillHeight,
          child: bellButton,
        ),
      ],
    );
  }
}

/// 顶部信息用的浅色玻璃胶囊：模糊背后画面 + 半透明白 + 一道细白边。
class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.child,
    required this.height,
    this.width,
    this.horizontalPadding = 0,
  });

  final Widget child;
  final double height;
  final double? width;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          width: width,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}
