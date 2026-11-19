import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/shop/shop_api.dart';
import '../../core/shop/shop_models.dart';
import '../../shared/widgets/status_bar_style.dart';
import 'shop_theme.dart';

/// 商品详情页：大图 + 价格信息卡 + 保障条 + 底部通栏「立即购买」。
///
/// 列表页可预传 [product] 先展示，同时按 [productId] 拉取详情刷新。
class GoodsDetailPage extends StatefulWidget {
  const GoodsDetailPage({super.key, this.product, this.productId});

  final MallProduct? product;
  final int? productId;

  @override
  State<GoodsDetailPage> createState() => _GoodsDetailPageState();
}

class _GoodsDetailPageState extends State<GoodsDetailPage> {
  MallProduct? _product;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _loading = _product == null;
    _fetch();
  }

  Future<void> _fetch() async {
    final id = _product?.id ?? widget.productId;
    if (id == null || id <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final res = await ShopApiService.productDetail(id);
    if (!mounted) return;
    if (res.isSuccess && res.isMap) {
      setState(() {
        _product = MallProduct.fromJson(res.asMap);
        _loading = false;
        _error = null;
      });
    } else {
      setState(() {
        _loading = false;
        _error = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final p = _product;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F2),
        appBar: TNavBar(
          title: const Text('商品详情'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: ShopColors.pink))
            : _error != null && p == null
                ? _buildError()
                : _buildBody(p!),
        bottomNavigationBar: p == null
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 10, 16, bottomInset > 0 ? bottomInset * 0.3 : 12),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: TButton(
                    size: TButtonSize.large,
                    variant: TButtonVariant.fill,
                    colorPreset: TButtonColorPreset.primary,
                    shape: TButtonShape.round,
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.shopPayOrder,
                      arguments: p.id,
                    ),
                    child: const Text('立即购买'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44, color: ShopColors.sub),
          const SizedBox(height: 12),
          Text(_error ?? '加载失败',
              style: const TextStyle(fontSize: 13, color: ShopColors.sub)),
          const SizedBox(height: 16),
          TButton(
            variant: TButtonVariant.outline,
            colorPreset: TButtonColorPreset.primary,
            size: TButtonSize.small,
            shape: TButtonShape.round,
            onPressed: () {
              setState(() => _loading = true);
              _fetch();
            },
            child: const Text('点击重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(MallProduct p) {
    final hasPromo = p.subtitle?.isNotEmpty == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主图
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1.1,
                  child: Image.network(
                    p.imglogo ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF1EBEE),
                      alignment: Alignment.center,
                      child: const Icon(Icons.pets, color: ShopColors.pink),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 价格信息卡
          _whiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${p.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.price,
                      ),
                    ),
                    if (p.orgPrice != null && p.orgPrice! > p.price) ...[
                      const SizedBox(width: 8),
                      Text(
                        '¥${p.orgPrice!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ShopColors.sub,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '已售${p.sales} · 剩余${p.stock}',
                      style: const TextStyle(
                          fontSize: 12, color: ShopColors.sub),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.ink,
                    height: 1.3,
                  ),
                ),
                if (p.model?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text('型号：${p.model}',
                      style: const TextStyle(
                          fontSize: 12, color: ShopColors.sub)),
                ],
                if (hasPromo) ...[
                  const SizedBox(height: 10),
                  TTag(
                    p.subtitle!,
                    colorPreset: TTagColorPreset.primary,
                    variant: TTagVariant.light,
                    size: TTagSize.small,
                    shape: TTagShape.round,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 保障条
          _whiteCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final e in const [
                  ('verified_user_outlined', '品质保证'),
                  ('local_shipping_outlined', '准时发货'),
                  ('support_agent', '专属客服'),
                  ('assignment_turned_in_outlined', '先行赔付'),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icon(e.$1), size: 14, color: ShopColors.pink),
                      const SizedBox(width: 4),
                      Text(e.$2,
                          style: const TextStyle(
                              fontSize: 11, color: ShopColors.ink)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(String name) => switch (name) {
        'verified_user_outlined' => Icons.verified_user_outlined,
        'local_shipping_outlined' => Icons.local_shipping_outlined,
        'support_agent' => Icons.support_agent,
        _ => Icons.assignment_turned_in_outlined,
      };

  Widget _whiteCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
