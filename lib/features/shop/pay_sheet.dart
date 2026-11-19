import 'package:flutter/material.dart';
import 'package:tobias/tobias.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/shop/shop_api.dart';
import 'shop_theme.dart';

/// 调起支付方式选择弹窗（微信/支付宝）并执行支付。
///
/// 返回支付方式名称（'微信支付' / '支付宝'）表示支付已确认并调起：
/// - 微信：直接返回（后端暂未实装微信支付参数）；
/// - 支付宝：已成功拉起收银台并确认支付。
/// 返回 null = 用户取消、蒙层关闭或支付失败/取消。
Future<String?> showPaySheet(
  BuildContext context, {
  required int orderId,
  required String sn,
  required double amount,
}) async {
  int payMethod = 0; // 0 微信 / 1 支付宝
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏：居中标题 + 右上角关闭
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Stack(
                  children: [
                    const Center(
                      child: Text('确认支付',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: ShopColors.ink)),
                    ),
                    Positioned(
                      right: 0,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: const Icon(Icons.close,
                            size: 22, color: ShopColors.sub),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1EAE4)),
              // 金额 + 订单号（居中）
              const SizedBox(height: 22),
              const Text('应付金额',
                  style: TextStyle(fontSize: 13, color: ShopColors.sub)),
              const SizedBox(height: 6),
              Text('¥${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: ShopColors.price)),
              const SizedBox(height: 8),
              Text('订单号：$sn',
                  style:
                      const TextStyle(fontSize: 12, color: ShopColors.sub)),
              const SizedBox(height: 24),
              // 支付方式
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('选择支付方式',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ShopColors.ink)),
                    const SizedBox(height: 14),
                    _payOption(
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF07C160),
                      label: '微信支付',
                      index: 0,
                      selected: payMethod,
                      onSelect: (i) => setSheet(() => payMethod = i),
                    ),
                    const SizedBox(height: 12),
                    _payOption(
                      icon: Icons.payment,
                      color: const Color(0xFF1677FF),
                      label: '支付宝',
                      index: 1,
                      selected: payMethod,
                      onSelect: (i) => setSheet(() => payMethod = i),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // 底部全宽确认按钮
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    // 不固定高度：TButtonSize.large 最小高度为 48，
                    // 强行压缩会裁切文字
                    width: double.infinity,
                    child: TButton(
                      size: TButtonSize.large,
                      variant: TButtonVariant.fill,
                      colorPreset: TButtonColorPreset.primary,
                      shape: TButtonShape.round,
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('确认支付'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return null;

  // 执行支付
  final payLabel = payMethod == 0 ? '微信支付' : '支付宝';
  final payType = payMethod == 0 ? 'wechat' : 'alipay';
  final res = await ShopApiService.payOrder(
    orderId: orderId,
    payType: payType,
  );
  if (!context.mounted) return null;
  if (!res.isSuccess) {
    TToast.showText(res.message, context: context);
    return null;
  }
  if (payType == 'alipay') {
    // 支付宝：data 为订单 info 串，交 Tobias 拉起支付宝收银台
    final payInfo = res.data?.toString() ?? '';
    if (payInfo.isEmpty) {
      TToast.showText('支付参数异常，请稍后重试', context: context);
      return null;
    }
    try {
      final result = await Tobias().pay(payInfo);
      final status = result['resultStatus']?.toString() ?? '4000';
      if (status != '9000' && status != '8000') {
        TToast.showText(
            status == '6001' ? '已取消支付' : '支付未完成',
            context: context);
        return null;
      }
    } catch (e) {
      TToast.showText('支付宝拉起失败：$e', context: context);
      return null;
    }
  } else {
    // 微信支付：后端暂未返回参数化支付字段（旧版同为直接进入成功页），
    // 待后端实装微信支付参数后在此接 wechat_bridge.pay。
  }
  if (!context.mounted) return null;
  return payLabel;
}

/// 支付方式选项卡片（白底描边，选中品牌粉框 + 实心勾）。
Widget _payOption({
  required IconData icon,
  required Color color,
  required String label,
  required int index,
  required int selected,
  required ValueChanged<int> onSelect,
}) {
  final active = selected == index;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onSelect(index),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? ShopColors.pink : const Color(0xFFECE5E8),
          width: active ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontSize: 15, color: ShopColors.ink)),
          const Spacer(),
          active
              ? Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: ShopColors.pink,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.check, color: Colors.white, size: 14),
                )
              : Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFDCD3D8)),
                  ),
                ),
        ],
      ),
    ),
  );
}
