import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/http/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/shop/shop_api.dart';
import '../../core/shop/shop_models.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/status_bar_style.dart';
import 'pay_sheet.dart';
import 'pay_success_page.dart';
import 'shop_theme.dart';

/// 订单列表页：状态 Tab + 分页加载 + 操作（取消/支付/删除/再次购买）。
///
/// Tab 与接口 status 映射：Tab index - 1（Tab 0=全部 → status 不传）。
class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['全部', '待付款', '已付款', '已发货', '已完成'];
  static const _statusText = {
    -1: '已取消',
    0: '待付款',
    1: '已付款',
    2: '已发货',
    3: '已完成',
    4: '售后/退货',
  };
  static const _statusColor = {
    0: Color(0xFFFF4D26),
    1: Color(0xFF07C160),
    2: Color(0xFF3D7FFF),
    3: Color(0xFF07C160),
    -1: Color(0xFF999999),
    4: Color(0xFFB08CA0),
  };

  late final TabController _tabCtrl =
      TabController(length: _tabs.length, vsync: this);
  final ScrollController _scrollController = ScrollController();

  final List<ShopOrder> _orders = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    _refresh();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.extentAfter < 400) _loadMore();
  }

  int? get _statusParam =>
      _tabCtrl.index == 0 ? null : _tabCtrl.index - 1;

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _page = 1;
      _hasMore = true;
    });
    final res = await ShopApiService.orders(
      pageNum: 1,
      pageSize: 10,
      status: _statusParam,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _orders
        ..clear()
        ..addAll(_parse(res));
      _hasMore = _orders.length < _totalOf(res);
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final res = await ShopApiService.orders(
      pageNum: _page + 1,
      pageSize: 10,
      status: _statusParam,
    );
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (res.isSuccess) {
        _page += 1;
        _orders.addAll(_parse(res));
        _hasMore = _orders.length < _totalOf(res);
      }
    });
  }

  static int _totalOf(ApiResponse res) =>
      parseNum(res.asMap['total'])?.toInt() ?? 0;

  static List<ShopOrder> _parse(ApiResponse res) =>
      ((res.asMap['records'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShopOrder.fromJson)
          .toList();

  Future<void> _cancel(ShopOrder o) async {
    final ok = await showConfirmDialog(
      context,
      content: '确定取消订单 ${o.sn} 吗？取消后无法恢复。',
      confirmText: '取消订单',
      danger: true,
    );
    if (!ok) return;
    final res = await ShopApiService.cancelOrder(o.id);
    if (!mounted) return;
    TToast.showText(res.isSuccess ? '订单已取消' : res.message, context: context);
    if (res.isSuccess) _refresh();
  }

  Future<void> _delete(ShopOrder o) async {
    final res = await ShopApiService.deleteOrder(o.id);
    if (!mounted) return;
    TToast.showText(res.isSuccess ? '已删除' : res.message, context: context);
    if (res.isSuccess) _refresh();
  }

  void _goDetail(ShopOrder o) {
    if (o.productId > 0) {
      Navigator.of(context).pushNamed(
        AppRoutes.shopGoodsDetail,
        arguments: o.productId,
      );
    }
  }

  Future<void> _goPay(ShopOrder o) async {
    // 对已有待付款订单直接调起支付方式选择弹窗并执行支付
    final payLabel = await showPaySheet(
      context,
      orderId: o.id,
      sn: o.sn,
      amount: o.totalPrice,
    );
    if (payLabel == null || !mounted) return;
    Navigator.of(context).pushNamed(
      AppRoutes.shopPaySuccess,
      arguments: PaySuccessArgs(
        amount: o.totalPrice,
        sn: o.sn,
        payTypeLabel: payLabel,
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F2),
        appBar: TNavBar(
          title: const Text('我的订单'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: Column(
          children: [
            // 状态 Tab（TNavBar 不支持 bottom，放 body 顶部）
            Container(
              color: Colors.white,
              child: TTabsBar(
                controller: _tabCtrl,
                // 5 个 Tab 均分占满整行
                tabs: [for (final t in _tabs) TTab(text: t)],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: ShopColors.pink))
                  : _orders.isEmpty
                      ? const TEmpty(emptyText: '暂无相关订单')
                      : RefreshIndicator(
                          color: ShopColors.pink,
                          onRefresh: _refresh,
                          child: ListView.separated(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(12, 12, 12, 32),
                            itemCount: _orders.length +
                                (_hasMore || _loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              if (i >= _orders.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: TLoading(size: 20),
                                  ),
                                );
                              }
                              return _orderCard(_orders[i]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(ShopOrder o) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：订单号 + 状态
          Row(
            children: [
              Expanded(
                child: Text(
                  '订单号：${o.sn}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: ShopColors.sub),
                ),
              ),
              Text(
                _statusText[o.status] ?? '未知',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusColor[o.status] ?? ShopColors.sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 商品行
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _goDetail(o),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    o.image ?? '',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFFF1EBEE),
                      alignment: Alignment.center,
                      child:
                          const Icon(Icons.pets, size: 22, color: ShopColors.pink),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.title ?? '宠物商品',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ShopColors.ink,
                          height: 1.3,
                        ),
                      ),
                      if (o.model?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text('型号：${o.model}',
                            style: const TextStyle(
                                fontSize: 11, color: ShopColors.sub)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('x${o.quantity}',
                    style:
                        const TextStyle(fontSize: 12, color: ShopColors.sub)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 合计
          Row(
            children: [
              const Spacer(),
              Text(
                '共${o.quantity}件  合计 ',
                style: const TextStyle(fontSize: 12, color: ShopColors.sub),
              ),
              Text(
                '¥${o.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ShopColors.price,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 操作按钮区
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (o.status == 0) ...[
                _actionBtn('取消订单', () => _cancel(o), filled: false),
                const SizedBox(width: 8),
                _actionBtn('去支付', () => _goPay(o), filled: true),
              ] else if (o.status == -1) ...[
                _actionBtn('删除订单', () => _delete(o), filled: false),
              ] else ...[
                _actionBtn('再次购买', () => _goDetail(o), filled: false),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap, {required bool filled}) {
    return TButton(
      size: TButtonSize.small,
      variant:
          filled ? TButtonVariant.fill : TButtonVariant.outline,
      colorPreset: filled
          ? TButtonColorPreset.primary
          : TButtonColorPreset.defaultTheme,
      shape: TButtonShape.round,
      onPressed: onTap,
      child: Text(label),
    );
  }
}
