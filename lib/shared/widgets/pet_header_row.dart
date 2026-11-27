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
    this.fallbackName = '超级喵克，哎喵',
  });

  /// 宠物名文字颜色与字号。
  final Color titleColor;
  final double titleFontSize;
  final FontWeight titleFontWeight;

  /// 名字右侧切换箭头颜色。
  final Color arrowColor;

  /// 右侧消息铃铛尺寸。
  final double bellSize;

  /// 还没选到宠物时的占位名。
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetState>();
    final name = pet.selectedPet?.nickname.isNotEmpty == true
        ? pet.selectedPet!.nickname
        : fallbackName;
    return Row(
      children: [
        // 只让名字与铃铛响应点击，避免整行拦截下方内容的手势
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showPetPicker(context, pet),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                // 首帧/分屏时宽度可能小于 120，直接相减会得到负约束并触发
                // BoxConstraints 断言，这里兜底到最小 80
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(context).width - 120).clamp(
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
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Image(
                image: const AssetImage('assets/images/icon/swich-1.png'),
                width: 10,
                height: 10,
                color: arrowColor,
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.news),
          child: Image.asset(
            'assets/images/icon/lb-ico.png',
            width: bellSize,
            height: bellSize,
          ),
        ),
      ],
    );
  }
}
