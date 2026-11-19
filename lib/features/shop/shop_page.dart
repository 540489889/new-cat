import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/http/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/shop/shop_api.dart';
import '../../core/shop/shop_models.dart';
import '../../shared/widgets/status_bar_style.dart';
import 'shop_theme.dart';

/// 商城首页：品牌渐变头部 + Banner 轮播 + 两列商品网格。
///
/// 相比参考项目优化点：品牌色系（紫粉替代橙色）、两列网格卡片、
/// 下拉刷新 + 上拉分页加载、统一的加载/空态/错误态。
/// 控件优先使用 TDesign（TEmpty/TTag/TToast/TLoading）。
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  static const Color _bg = ShopColors.bg; // 页面暖米底（与宠物页一致）
  static const Color _ink = ShopColors.ink; // 主文字
  static const Color _sub = ShopColors.sub; // 次要文字
  static const Color _pink = ShopColors.pink; // 品牌/标签粉
  static const Color _price = ShopColors.price; // 价格暖红（与品牌色和谐）

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final ScrollController _scrollController = ScrollController();

  List<ShopBanner> _banners = const [];
  final List<MallProduct> _products = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.extentAfter < 400) _loadMore();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    final results =
        await Future.wait([ShopApiService.banners(), _fetchProducts(1)]);
    if (!mounted) return;
    final bannerRes = results[0];
    final productRes = results[1];
    setState(() {
      _loading = false;
      if (bannerRes.isSuccess) {
        _banners = bannerRes.asList
            .whereType<Map<String, dynamic>>()
            .map(ShopBanner.fromJson)
            .toList();
      }
      if (productRes.isSuccess) {
        _products
          ..clear()
          ..addAll(_parseProducts(productRes));
        _hasMore = _products.length < _totalOf(productRes);
      } else {
        _error = productRes.message;
        _products.clear();
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final res = await _fetchProducts(_page + 1);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (res.isSuccess) {
        _page += 1;
        _products.addAll(_parseProducts(res));
        _hasMore = _products.length < _totalOf(res);
      }
    });
  }

  static int _totalOf(ApiResponse res) =>
      parseNum(res.asMap['total'])?.toInt() ?? 0;

  static List<MallProduct> _parseProducts(ApiResponse res) =>
      ((res.asMap['records'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MallProduct.fromJson)
          .toList();

  Future<ApiResponse> _fetchProducts(int page) =>
      ShopApiService.products(pageNum: page, pageSize: 10);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: ShopPage._bg,
        // 标题条用固定 Container（不走 Sliver 布局，规避
        // pinned header 的 layoutExtent/paintExtent 取整冲突）
        body: Column(
          children: [
            _TitleBar(topInset: topInset),
            Expanded(
              child: RefreshIndicator(
                color: ShopPage._pink,
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Banner 轮播（随内容滚动）
                    SliverToBoxAdapter(
                      child: _BannerSection(banners: _banners),
                    ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: ShopPage._pink),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorView(error: _error!, onRetry: _refresh),
                )
              else if (_products.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyView(),
                )
              else ...[
                const SliverToBoxAdapter(child: _SectionTitle()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _GoodsCard(product: _products[i]),
                      childCount: _products.length,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 14, bottom: 32),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: _loadingMore
                          ? const TLoading(size: 16, text: '加载中…')
                          : Text(
                              _hasMore ? '上拉加载更多' : '— 已经到底啦 —',
                              style: const TextStyle(
                                  fontSize: 12, color: ShopPage._sub),
                            ),
                    ),
                  ),
                ),
                ],
              ],
            ),
          ),
        ),
        ],
      ),
    ),
  );
}
}

/// 固定标题条：渐变背景 + 居中标题 + 左侧返回按钮（普通 Container，不参与 Sliver 布局）。
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.topInset});

  final double topInset;

  /// 状态栏下方的导航行高度（与 TNavBar 视觉规格一致）。
  static const double _barHeight = 52;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: topInset + _barHeight,
      padding: EdgeInsets.only(top: topInset),
      // 不透明渐变：内容从固定头下方滚过时不会透出
      decoration: const BoxDecoration(gradient: ShopColors.titleGradient),
      child: Stack(
        children: [
          // 标题：水平垂直居中
          const Center(
            child: Text(
              '宠物商城',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          // 返回按钮：左侧垂直居中
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 44,
                height: _barHeight,
                alignment: Alignment.center,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner 轮播（PageView 自实现，免第三方依赖；自动轮播逻辑内聚于此）。
class _BannerSection extends StatefulWidget {
  const _BannerSection({required this.banners});

  final List<ShopBanner> banners;

  @override
  State<_BannerSection> createState() => _BannerSectionState();
}

class _BannerSectionState extends State<_BannerSection> {
  final PageController _bannerController = PageController();
  int _index = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(_BannerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _index = 0;
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _bannerTimer?.cancel();
    if (widget.banners.length < 2) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.banners.length < 2) return;
      final current = _bannerController.hasClients
          ? (_bannerController.page?.round() ?? 0)
          : 0;
      _bannerController.animateToPage(
        (current + 1) % widget.banners.length,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox(height: 12);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      height: 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            PageView.builder(
              controller: _bannerController,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _handleTap(banners[i]),
                child: Image.network(
                  banners[i].image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE8DCE2),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            // 右下角圆点指示器
            Positioned(
              right: 12,
              bottom: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < banners.length; i++)
                    Container(
                      width: i == _index ? 14 : 5,
                      height: 5,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: i == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(ShopBanner banner) {
    if (banner.linkType == 'h5' && banner.url.isNotEmpty) {
      launchUrl(Uri.parse(banner.url), mode: LaunchMode.externalApplication);
      return;
    }
    if (banner.targetId != null && banner.targetId! > 0) {
      Navigator.of(context).pushNamed(
        AppRoutes.shopGoodsDetail,
        arguments: banner.targetId,
      );
      return;
    }
    TToast.showText('活动即将开始', context: context);
  }
}

/// 区块标题行：全部商品 + 保障说明。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          const Text(
            '全部商品',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ShopPage._ink,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.verified_user_outlined,
              size: 14, color: ShopPage._pink),
          const SizedBox(width: 4),
          const Text('正品保证 · 快速配送',
              style: TextStyle(fontSize: 11, color: ShopPage._sub)),
        ],
      ),
    );
  }
}

/// 商品卡：竖式卡片（上图下文）。
class _GoodsCard extends StatelessWidget {
  const _GoodsCard({required this.product});

  final MallProduct product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.shopGoodsDetail,
        arguments: product,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Image.network(
                  product.imglogo ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF1EBEE),
                    alignment: Alignment.center,
                    child: const Icon(Icons.pets, color: ShopPage._pink),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ShopPage._ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (product.subtitle?.isNotEmpty == true) ...[
                    TTag(
                      product.subtitle!,
                      colorPreset: TTagColorPreset.primary,
                      variant: TTagVariant.light,
                      size: TTagSize.small,
                      shape: TTagShape.round,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          '¥${product.price.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ShopPage._price,
                          ),
                        ),
                      ),
                      if (product.orgPrice != null &&
                          product.orgPrice! > product.price) ...[
                        const SizedBox(width: 4),
                        Text(
                          '¥${product.orgPrice!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: ShopPage._sub,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        product.sales > 0 ? '已售${product.sales}' : '',
                        style: const TextStyle(
                            fontSize: 10, color: ShopPage._sub),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 加载失败视图（TDesign 空态 + 重试按钮）。
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return TEmpty(
      emptyText: '加载失败：$error',
      operation: TButton(
        variant: TButtonVariant.outline,
        colorPreset: TButtonColorPreset.primary,
        size: TButtonSize.small,
        shape: TButtonShape.round,
        onPressed: onRetry,
        child: const Text('点击重试'),
      ),
    );
  }
}

/// 空商品视图（TDesign 空态）。
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const TEmpty(emptyText: '商品上架中，敬请期待');
  }
}
