import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/router/app_router.dart';
import '../../shared/widgets/status_bar_style.dart';
import 'shop_theme.dart';

/// 支付成功页参数。
class PaySuccessArgs {
  const PaySuccessArgs({
    required this.amount,
    required this.sn,
    required this.payTypeLabel,
  });

  final double amount;
  final String sn;
  final String payTypeLabel;
}

/// 支付成功页：白卡结果面板 + 查看订单 / 继续逛逛。
class PaySuccessPage extends StatelessWidget {
  const PaySuccessPage({super.key, this.args});

  final PaySuccessArgs? args;

  @override
  Widget build(BuildContext context) {
    final amount = args?.amount;
    final payLabel = args?.payTypeLabel ?? '在线支付';
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: TNavBar(
          title: const Text('支付成功'),
          useDefaultBack: false,
          useSafeArea: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            // 结果卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 44, 16, 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ShopColors.pink.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 成功图标 + 四周装饰点
                  SizedBox(
                    width: 92,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _dot(const Color(0xFFEADCE3), 8,
                            top: 2, left: 12),
                        _dot(ShopColors.pink.withValues(alpha: 0.35), 9,
                            top: 8, right: 12),
                        _dot(const Color(0xFFF4EEF1), 12,
                            bottom: 4, left: 2),
                        _dot(ShopColors.pink.withValues(alpha: 0.25), 7,
                            bottom: 12, right: 6),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFB48CA3), Color(0xFF8E6B84)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ShopColors.pink.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 34),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('支付成功',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: ShopColors.ink)),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      text: '$payLabel已支付  ',
                      style: const TextStyle(
                          fontSize: 13, color: ShopColors.sub),
                      children: [
                        TextSpan(
                          text: amount != null
                              ? '¥${amount.toStringAsFixed(2)}'
                              : '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: ShopColors.price,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (args?.sn.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text('订单号：${args!.sn}',
                        style: const TextStyle(
                            fontSize: 12, color: ShopColors.sub)),
                  ],
                  const SizedBox(height: 30),
                  const Divider(height: 1, color: Color(0xFFF1EAE4)),
                  const SizedBox(height: 26),
                  SizedBox(
                    // 不固定高度：TButtonSize.large 最小高度为 48，
                    // 强行压缩会裁切文字
                    width: 160,
                    child: TButton(
                      size: TButtonSize.large,
                      variant: TButtonVariant.outline,
                      colorPreset: TButtonColorPreset.primary,
                      shape: TButtonShape.round,
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.shopOrderList,
                          (route) => route.isFirst,
                        );
                      },
                      child: const Text('查看订单'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 发货提示
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ShopColors.tagBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 18, color: ShopColors.pink),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '订单已支付成功，商家将尽快为您发货',
                      style: TextStyle(
                          fontSize: 12, color: ShopColors.ink, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, bottomInset > 0 ? bottomInset * 0.3 : 12),
            child: TButton(
              size: TButtonSize.large,
              variant: TButtonVariant.fill,
              colorPreset: TButtonColorPreset.primary,
              shape: TButtonShape.round,
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.shop,
                  (route) => route.isFirst,
                );
              },
              child: const Text('继续逛逛'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color, double size,
      {double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
