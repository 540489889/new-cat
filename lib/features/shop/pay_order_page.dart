import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/shop/shop_api.dart';
import '../../core/shop/shop_models.dart';
import '../../shared/widgets/status_bar_style.dart';
import 'address_page.dart';
import 'pay_sheet.dart';
import 'pay_success_page.dart';
import 'shop_theme.dart';

/// 确认订单页：收货地址 + 商品信息 + 数量 + 备注 + 提交订单与支付。
class PayOrderPage extends StatefulWidget {
  const PayOrderPage({super.key, required this.productId});

  final int productId;

  @override
  State<PayOrderPage> createState() => _PayOrderPageState();
}

class _PayOrderPageState extends State<PayOrderPage> {
  MallProduct? _product;
  List<ShopAddress> _addresses = const [];
  ShopAddress? _selectedAddress;
  bool _loading = true;
  bool _submitting = false;

  int _quantity = 1;
  final TextEditingController _remarkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final results = await Future.wait([
      ShopApiService.productDetail(widget.productId),
      ShopApiService.addresses(),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0].isSuccess && results[0].isMap) {
        _product = MallProduct.fromJson(results[0].asMap);
      }
      if (results[1].isSuccess) {
        _addresses = results[1].asList
            .whereType<Map<String, dynamic>>()
            .map(ShopAddress.fromJson)
            .toList();
        // 优先默认地址，否则取第一条；无地址时保持 null（提示添加）
        ShopAddress? picked;
        for (final a in _addresses) {
          if (a.isDefault) {
            picked = a;
            break;
          }
        }
        _selectedAddress = picked ?? (_addresses.isNotEmpty ? _addresses.first : null);
      }
    });
  }

  double get _total => (_product?.price ?? 0) * _quantity;

  /// 数量步进器：极简无边框 —— 只有 − / 数字 / +，干净扁平。
  /// 按钮点击区仍保持 40×40（TStepper 最大仅 26px，太小不好点）。
  Widget _quantityStepper() {
    final canMinus = _quantity > 1;
    final canAdd = _quantity < 99;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn(Icons.remove, canMinus, () => setState(() => _quantity--)),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text('$_quantity',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ShopColors.ink)),
        ),
        _stepBtn(Icons.add, canAdd, () => setState(() => _quantity++)),
      ],
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon,
            size: 18,
            color: enabled ? ShopColors.ink : ShopColors.sub),
      ),
    );
  }

  Future<void> _pickAddress() async {
    if (_addresses.isEmpty) {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AddressPage()),
      );
      if (changed == true) _fetch();
      return;
    }
    // 弹窗前刷新地址列表
    final res = await ShopApiService.addresses();
    if (!mounted) return;
    if (res.isSuccess) {
      _addresses = res.asList
          .whereType<Map<String, dynamic>>()
          .map(ShopAddress.fromJson)
          .toList();
    }
    if (!mounted) return;

    final picked = await showModalBottomSheet<ShopAddress>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.72,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏：居中标题 + 右上角关闭
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    child: Stack(
                      children: [
                        const Center(
                          child: Text(
                            '选择收货地址',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: ShopColors.ink,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: const Icon(Icons.close,
                                size: 22, color: ShopColors.sub),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1EAE4)),
                  // 地址列表
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _addresses.length,
                      itemBuilder: (_, i) {
                        final a = _addresses[i];
                        final selected =
                            a.id == (_selectedAddress?.id ?? -1);
                        return Column(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setSheet(() => _selectedAddress = a);
                                Navigator.pop(ctx, a);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    // 勾选圆钮
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected
                                            ? ShopColors.pink
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: selected
                                              ? ShopColors.pink
                                              : const Color(0xFFDCD3D8),
                                          width: 2,
                                        ),
                                      ),
                                      child: selected
                                          ? const Icon(Icons.check,
                                              color: Colors.white,
                                              size: 12)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    // 地址内容
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(a.name,
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: ShopColors
                                                          .ink)),
                                              const SizedBox(width: 12),
                                              Text(a.phone,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          ShopColors.sub)),
                                              const Spacer(),
                                              if (a.isDefault)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        ShopColors.tagBg,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(4),
                                                  ),
                                                  child: const Text('默认',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: ShopColors
                                                              .pink)),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${a.region} ${a.detail}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: ShopColors.sub),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 编辑入口
                                    GestureDetector(
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final changed =
                                            await Navigator.of(context)
                                                .push<bool>(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  AddressEditPage(
                                                      address: a)),
                                        );
                                        if (!mounted) return;
                                        if (changed == true) _fetch();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.edit_outlined,
                                            size: 18,
                                            color: ShopColors.sub),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (i != _addresses.length - 1)
                              const Padding(
                                padding: EdgeInsets.only(left: 52),
                                child: Divider(
                                    height: 1, color: Color(0xFFF1EAE4)),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 底部：添加新地址
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
                          variant: TButtonVariant.outline,
                          colorPreset: TButtonColorPreset.primary,
                          shape: TButtonShape.round,
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final changed =
                                await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AddressEditPage()),
                            );
                            if (!mounted) return;
                            if (changed == true) _fetch();
                          },
                          child: const Text('添加新地址'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedAddress = picked);
    }
  }

  Future<void> _submit() async {
    if (_product == null) return;
    if (_selectedAddress == null) {
      TToast.showText('请先添加收货地址', context: context);
      return;
    }
    setState(() => _submitting = true);
    final res = await ShopApiService.createOrder(
      productId: _product!.id,
      quantity: _quantity,
      addressId: _selectedAddress!.id,
      remark: _remarkCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!res.isSuccess) {
      TToast.showText(res.message, context: context);
      return;
    }
    final order = CreateOrderResult.fromJson(res.asMap);
    final payLabel = await showPaySheet(
      context,
      orderId: order.id,
      sn: order.sn,
      amount: order.totalPrice,
    );
    if (payLabel == null || !mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.shopPaySuccess,
      arguments: PaySuccessArgs(
        amount: order.totalPrice,
        sn: order.sn,
        payTypeLabel: payLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final p = _product;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F2),
        appBar: TNavBar(
          title: const Text('确认订单'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: ShopColors.pink))
            : p == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('商品信息加载失败',
                            style: TextStyle(
                                fontSize: 13, color: ShopColors.sub)),
                        const SizedBox(height: 12),
                        TButton(
                          variant: TButtonVariant.outline,
                          colorPreset: TButtonColorPreset.primary,
                          size: TButtonSize.small,
                          shape: TButtonShape.round,
                          onPressed: () {
                            setState(() => _loading = true);
                            _fetch();
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // 地址卡
                        _whiteCard(
                          onTap: _pickAddress,
                          child: _selectedAddress == null
                              ? Row(
                                  children: [
                                    Icon(Icons.add_location_alt_outlined,
                                        size: 20, color: ShopColors.pink),
                                    const SizedBox(width: 8),
                                    const Text('添加收货地址',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: ShopColors.ink)),
                                    const Spacer(),
                                    const Icon(Icons.chevron_right,
                                        size: 18, color: ShopColors.sub),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (_selectedAddress!.isDefault)
                                          Container(
                                            margin: const EdgeInsets.only(
                                                right: 8),
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ShopColors.tagBg,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text('默认',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        ShopColors.pink)),
                                          ),
                                        Text(
                                          '${_selectedAddress!.name}  ${_selectedAddress!.phone}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: ShopColors.ink,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.chevron_right,
                                            size: 18, color: ShopColors.sub),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_selectedAddress!.region} ${_selectedAddress!.detail}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: ShopColors.sub,
                                          height: 1.4),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 10),
                        // 商品卡
                        _whiteCard(
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      p.imglogo ?? '',
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(
                                        width: 72,
                                        height: 72,
                                        color: const Color(0xFFF1EBEE),
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.pets,
                                            size: 22, color: ShopColors.pink),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: ShopColors.ink,
                                            height: 1.3,
                                          ),
                                        ),
                                        if (p.model?.isNotEmpty == true)
                                          ...[
                                            const SizedBox(height: 4),
                                            Text('型号：${p.model}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        ShopColors.sub)),
                                          ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    '¥${p.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: ShopColors.price,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 数量独立一行（京东确认订单样式）
                              Row(
                                children: [
                                  const Text('数量',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: ShopColors.sub)),
                                  const Spacer(),
                                  _quantityStepper(),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 价格汇总 + 备注
                        _whiteCard(
                          child: Column(
                            children: [
                              _summaryRow('商品金额',
                                  '¥${p.price.toStringAsFixed(2)}'),
                              _summaryRow('运费', '免运费'),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF1EAE4)),
                              const SizedBox(height: 12),
                              // 订单备注：行式（label + 无边框输入 + 计数）
                              Row(
                                children: [
                                  const Text('订单备注',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: ShopColors.ink)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _remarkCtrl,
                                      maxLength: 100,
                                      style: const TextStyle(
                                          fontSize: 14, color: ShopColors.ink),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        counterText: '',
                                        hintText: '选填，给商家留言（100 字内）',
                                        hintStyle: const TextStyle(
                                            fontSize: 14,
                                            color: ShopColors.sub),
                                        // 全局主题可能给输入框设了边框，逐个状态显式关闭
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _remarkCtrl,
                                    builder: (context, v, _) => Text(
                                        '${v.text.length}/100',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: ShopColors.sub)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
        bottomNavigationBar: p == null
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 10, 16, bottomInset > 0 ? bottomInset * 0.3 : 12),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Row(
                    children: [
                      Text.rich(
                        TextSpan(
                          text: '应付  ',
                          style: const TextStyle(
                              fontSize: 12, color: ShopColors.sub),
                          children: [
                            TextSpan(
                              text: '¥${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ShopColors.price,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 140,
                        child: TButton(
                          size: TButtonSize.large,
                          variant: TButtonVariant.fill,
                          colorPreset: TButtonColorPreset.primary,
                          shape: TButtonShape.round,
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('提交订单'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: ShopColors.sub)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: ShopColors.ink,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}
