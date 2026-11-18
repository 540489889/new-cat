import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pet/pet_state.dart';
import '../../core/router/app_router.dart';

/// 宠物页：宠物档案卡 + 功能入口宫格 + 今日冒险日记 + 今日集锦 + AI 问答浮条。
/// UI 按设计稿 1:1 还原；数据当前为本地 mock，接入后端后替换即可。
class PetPage extends StatefulWidget {
  const PetPage({super.key});

  // 设计稿色板
  static const Color _bg = Color(0xFFF5F0EA); // 页面暖米底
  static const Color _ink = Color(0xFF3D2E33); // 主文字
  static const Color _sub = Color(0xFFA89EA2); // 次要文字
  static const Color _pinkText = Color(0xFFB08CA0); // 链接/标签粉
  static const Color _tagBg = Color(0xFFF6ECEF); // 标签底
  static const Color _brand = Color(0xFF7F6370); // 品牌紫（AI 浮条）
  // 顶部渐变（与健康页同款）：深紫棕→粉紫→浅粉，底部透明融入页面暖米底
  static const LinearGradient _topGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF8E6B84), // 顶部深紫棕
      Color(0xFFB48CA3), // 中部粉紫
      Color(0xFFE5D2DC), // 浅粉紫
      Color(0x00E5D2DC), // 渐变底部透明，卡片可透过显示
    ],
    stops: [0.0, 0.42, 0.72, 0.89],
  );

  /// 顶部渐变背景层的总高度额外量（实际高度 = topInset + 该值）。
  /// 标题栏渐变按同一总高度映射，保证两段渐变无缝融为一体。
  static const double _gradientHeightExtra = 300.0;

  /// 标题栏高度（不含状态栏）：内容滚动盒子的上边界，
  /// 也是「状态栏 + 标题」占用的高度（与健康页一致）
  static const double _titleBarHeight = 58;

  /// 取顶部渐变在纵向 [y]（相对渐变层顶部）处的颜色（分段线性插值）。
  /// 用于档案卡收起态背景，使其与背后渐变完全衔接、融为一体。
  static Color gradientColorAt(double y, double bgH) {
    final p = (y / bgH).clamp(0.0, 1.0);
    final stops = _topGradient.stops!;
    final colors = _topGradient.colors;
    for (int i = 0; i < stops.length - 1; i++) {
      if (p <= stops[i + 1]) {
        final f = ((p - stops[i]) / (stops[i + 1] - stops[i])).clamp(0.0, 1.0);
        return Color.lerp(colors[i], colors[i + 1], f)!;
      }
    }
    return colors.last;
  }

  @override
  State<PetPage> createState() => _PetPageState();
}

/// 页面状态：承载滚动监听，驱动档案卡「被标题栏遮挡部分渐隐」效果
class _PetPageState extends State<PetPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // extendBody 下 padding.bottom 已含底部胶囊 TabBar 高度，再留少量间距（与健康页一致）
    final bottomPad = bottomInset + 76.0;
    return Scaffold(
      backgroundColor: PetPage._bg,
      body: Stack(
        children: [
          // 顶部渐变背景层（置于内容之后）：标题区与档案卡初始位置都落在渐变上；
          // 滚动时白色卡片盖住渐变，仅在卡片四周/间隙透出渐变，档案卡随内容一起滚动
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + PetPage._gradientHeightExtra,
            child: Container(
              decoration: const BoxDecoration(gradient: PetPage._topGradient),
            ),
          ),
          // 顶部固定标题栏：自带渐变背景，仅放标题，不随滚动移动。
          // 与健康页一致——内容被限制在标题栏下沿以下，不会遮住它
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Header(topInset: topInset),
          ),
          // 滚动内容盒子：高度 = 一屏 − 状态栏 − 标题栏（与健康页同一结构），
          // 内容只在盒子内滚动，越过盒子上边界的部分被 ScrollView 自身裁剪，
          // 因此永远不会遮挡状态栏 / 标题栏
          Positioned(
            top: topInset + PetPage._titleBarHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // 档案卡折叠头：pinned 固定在标题栏正下方，
                // 上滑时收起为「小头像 + 名字」紧凑条，下滑展开为完整卡片
                const SliverPersistentHeader(
                  pinned: true,
                  delegate: _ProfileCardDelegate(),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FeatureGrid(),
                        _AdventureDiaryCard(),
                        _HighlightsCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 底部 AI 问答浮条：与健康页一致，紧贴胶囊 TabBar 上方
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 8,
            child: const _AiBar(),
          ),
        ],
      ),
    );
  }
}

/// 顶部渐变标题栏：仅放标题（宠物 + 数量 + 添加按钮），渐变与健康页同款；
/// 固定不滚，滚动内容被限制在其下沿以下（由滚动盒子的上边界裁剪）。
class _Header extends StatelessWidget {
  final double topInset;
  const _Header({required this.topInset});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<PetState>().pets.length;
    // 标题栏自身高度（= 顶部留白 + 按钮36 + 底部留白）
    final titleH = topInset + 10 + 36 + 12;
    // 与背景层共用同一渐变总高（改背景层高度时两处自动同步）
    final bgH = topInset + PetPage._gradientHeightExtra;
    // 把渐变 end 推到「背景总高度」处：标题栏只取整条渐变的顶部一段，
    // 其下沿颜色与下方背景层在同一 y 的颜色完全一致 → 上下无缝融为一体
    final endY = 2 * bgH / titleH - 1;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(0.0, -1.0),
          end: Alignment(0.0, endY),
          colors: PetPage._topGradient.colors,
          stops: PetPage._topGradient.stops,
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: topInset + 10,
        bottom: 12,
      ),
      child: Row(
        children: [
          const Text(
            '宠物',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: PetPage._ink,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, color: Color(0xFFB9AEB2)),
          ),
          const Spacer(),
          // 添加宠物：白色胶囊按钮（浅色圆 + 号 + 文字）
          GestureDetector(
            onTap: () {}, // TODO: 添加宠物
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 浅色小圆 + 深色加号
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFF1EBEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        size: 13,
                        color: Color(0xFF5C4A50),
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '添加宠物',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PetPage._ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 档案卡折叠头 delegate：pinned 在标题栏下方，
/// 随滚动偏移把 shrinkOffset 映射为 collapsed（0=展开，1=收起）传给卡片。
class _ProfileCardDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileCardDelegate();

  // 展开态总高（顶部留白4 + 完整卡片 + 底部间距12）与收起态总高（横向迷你栏）
  static const double expandedExtent = 240;
  static const double collapsedExtent = 64;

  @override
  double get maxExtent => expandedExtent;

  @override
  double get minExtent => collapsedExtent;

  /// 收缩比例 t 对应的 pinned extent（供卡片背景做渐变对齐计算）
  static double extentFor(double t) =>
      lerpDouble(expandedExtent, collapsedExtent, t)!;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t =
        (shrinkOffset / (expandedExtent - collapsedExtent)).clamp(0.0, 1.0);
    // 刻意不用 const 缓存实例：收缩比例每帧变化，需要实时重建
    return _PetProfileCard(collapsed: t);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

/// 宠物档案卡：头像轮播（可滑动/点击切换宠物）+ 名字（可点选择）+ 陪伴天数 + 属性行，
/// 卡片左上/右下带浅色同心圆装饰。
/// [collapsed] 0=完整展开，1=收起为「小头像+名字」紧凑条，中间连续插值。
class _PetProfileCard extends StatefulWidget {
  const _PetProfileCard({required this.collapsed});

  final double collapsed;

  @override
  State<_PetProfileCard> createState() => _PetProfileCardState();
}

class _PetProfileCardState extends State<_PetProfileCard> {
  static const Color _ring = Color(0xFFC48FA5); // 大头像描边
  static const Color _statIcon = Color(0xFFB98CA0); // 属性图标
  static const Color _statText = Color(0xFF5C4A50); // 属性文字

  PageController? _pageCtrl;
  int _petCount = 0; // 记录已绑定控制器的宠物数量，变化时重建
  PetState? _pet; // 缓存 PetState 引用，供 dispose 安全移除监听（避免卸载时查祖先）

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pet = context.read<PetState>();
    _pet = pet; // 缓存引用，dispose 时用它安全移除监听
    // 宠物数量变化（首帧为空 -> 加载完成）时重建控制器，
    // 否则会沿用首次创建时的旧 viewportFraction（热重载后看不到效果）
    if (_pageCtrl == null || _petCount != pet.pets.length) {
      _pageCtrl?.dispose();
      pet.removeListener(_syncPage);
      _petCount = pet.pets.length;
      if (pet.pets.isNotEmpty) {
        final idx = pet.selectedIndex.clamp(0, pet.pets.length - 1);
        // viewportFraction 取小值让相邻头像紧贴当前头像右侧探出（还原设计稿效果）
        _pageCtrl = PageController(initialPage: idx, viewportFraction: 0.3);
        pet.addListener(_syncPage);
      } else {
        _pageCtrl = null;
      }
    }
  }

  // 外部（底部面板）切换宠物时，同步轮播到对应页
  void _syncPage() {
    final pet = context.read<PetState>();
    if (_pageCtrl?.hasClients == true && pet.pets.isNotEmpty) {
      final target = pet.selectedIndex.clamp(0, pet.pets.length - 1);
      if (_pageCtrl!.page?.round() != target) {
        _pageCtrl!.animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // 点击头像切换到下一个宠物
  void _tapNext(PetState pet) {
    if (pet.pets.length < 2) return;
    final next = (pet.selectedIndex + 1) % pet.pets.length;
    pet.selectPet(next);
  }

  @override
  void dispose() {
    _pet?.removeListener(_syncPage);
    _pageCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petState = context.watch<PetState>();
    final selected = petState.selectedPet;
    final name = (selected?.nickname.isNotEmpty == true)
        ? selected!.nickname
        : '超级神虎';
    final pets = petState.pets;
    const stats = [
      (Icons.local_florist, '金渐层'),
      (Icons.female, '妹妹'),
      (Icons.cake, '2岁'),
      (Icons.content_cut, '已绝育'),
      (Icons.monitor_weight, '3kg'),
    ];

    // 收缩插值：t=0 完整展开，t=1 收起为横向迷你档案栏
    final t = widget.collapsed.clamp(0.0, 1.0);
    final vPad = lerpDouble(20, 6, t)!;
    // 纵向轮播随收起淡出（高度收为 0），由横向迷你栏接管
    final avatarH = lerpDouble(96, 0, t)!;
    final avatarSize = lerpDouble(80, 36, t)!;
    // 天数 / 属性行：收缩到一半时开始淡出，收起后完全隐藏
    final fadeOut = (1 - t * 2).clamp(0.0, 1.0);
    // 收起时卡片融入标题栏：白底渐变为「与背后渐变衔接的颜色」、
    // 深色文字渐变为白色。收起条背景对齐背后渐变的对应区段，
    // 既遮住从下方滚过的内容，视觉上又与标题那块渐变融为一体。
    final topInset = MediaQuery.of(context).padding.top;
    final bgH = topInset + PetPage._gradientHeightExtra;
    // 卡片顶部相对渐变层顶部的 y（盒顶 = 状态栏 + 标题栏，加自身顶部边距）
    final cardTopY =
        topInset + PetPage._titleBarHeight + lerpDouble(4, 0, t)!;
    // 卡片实际高度 = pinned extent − 上下 margin
    final cardH = _ProfileCardDelegate.extentFor(t) - 12 - lerpDouble(4, 0, t)!;
    final g0 = PetPage.gradientColorAt(cardTopY, bgH);
    final g1 = PetPage.gradientColorAt(cardTopY + cardH, bgH);
    final nameColor = Color.lerp(PetPage._ink, Colors.white, t)!;

    ImageProvider avatarImg(String h) => h.isNotEmpty
        ? NetworkImage(h)
        : const AssetImage('assets/images/group-1.png');

    // 大头像（当前宠物带粉色描边圆，侧边探出的不带）
    Widget bigAvatar(String h, {bool ringed = true}) => Container(
      width: avatarSize,
      height: avatarSize,
      padding: EdgeInsets.all(ringed ? 5 : 0),
      decoration: ringed
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ring, width: 2),
            )
          : null,
      child: CircleAvatar(backgroundImage: avatarImg(h)),
    );

    // 头像轮播：3D 封面流，多宠物可左右滑动/点击切换；单宠物退化为静态大头像
    final avatarWidget = pets.isEmpty
        ? bigAvatar(selected?.headimg ?? '')
        : GestureDetector(
            onTap: () => _tapNext(petState),
            child: SizedBox(
              height: avatarH,
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: pets.length,
                clipBehavior: Clip.none,
                onPageChanged: (i) => petState.selectPet(i),
                itemBuilder: (_, i) {
                  final head = pets[i].headimg;
                  return AnimatedBuilder(
                    animation: _pageCtrl!,
                    builder: (ctx, __) {
                      final page =
                          _pageCtrl!.page ?? petState.selectedIndex.toDouble();
                      final diff = i - page;
                      // 侧边头像明显缩小（约0.6倍），贴近当前头像，还原设计稿
                      final scale = (1 - diff.abs() * 0.42).clamp(0.55, 1.0);
                      // 轻微透视即可，设计稿侧头像基本是平的
                      final angle = diff * 0.12;
                      final ringed = diff.abs() < 0.5; // 仅当前头像带粉色描边
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0016) // 透视深度
                          ..rotateY(angle),
                        child: Transform.scale(
                          scale: scale,
                          child: Center(child: bigAvatar(head, ringed: ringed)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );

    return Container(
      // 收起时去掉圆角、宽度占满，与标题区融为完整一块
      margin: EdgeInsets.fromLTRB(
        lerpDouble(12, 0, t)!,
        lerpDouble(4, 0, t)!,
        lerpDouble(12, 0, t)!,
        12,
      ),
      // 白卡样式（保留原始设计）：白色圆角卡片 + 四角浅色同心圆装饰，
      // 浮于渐变头部之上，渐变在卡片四周/上方透出作为页面顶部背景；
      // 收起时白底渐变为与背后衔接的渐变色，与标题栏融为一体
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(lerpDouble(20, 0, t)!),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(Colors.white, g0, t)!,
            Color.lerp(Colors.white, g1, t)!,
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 装饰：左上 / 右下 浅色同心圆（收起时随卡片一起淡出，避免浮在渐变上突兀）
          Positioned(top: -80, left: -60, child: Opacity(
            opacity: 1 - t,
            child: const _DecoRings(),
          )),
          Positioned(bottom: -80, right: -60, child: Opacity(
            opacity: 1 - t,
            child: const _DecoRings(),
          )),
          // 收起时内容顶部对齐、底部溢出部分裁剪（天数/属性行已淡出，无视觉突兀）
          // 注意：只放宽高度约束，宽度沿用父级——否则属性行的 Spacer 无法布局
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: vPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    avatarWidget,
                    // 名字 + 右箭头（点击进入宠物详情）：
                    // 收起时整行隐藏（heightFactor 收为 0 + 同步淡出），只留小头像
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 1 - t,
                        child: Opacity(
                          opacity: fadeOut,
                          child: Column(
                            children: [
                              SizedBox(height: lerpDouble(8, 4, t)),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.of(context)
                                    .pushNamed('/pet/detail'),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: nameColor,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: nameColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 陪伴天数行：点击进入宠物详情页（收起时淡出并被裁剪）
                    Opacity(
                      opacity: fadeOut,
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                Navigator.of(context).pushNamed('/pet/detail'),
                            child: Text(
                              '和$name的第108天',
                              style: const TextStyle(
                                fontSize: 13,
                                color: PetPage._sub,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 属性行：品种/性别/年龄/绝育/体重，均匀分布
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                for (int i = 0; i < stats.length; i++) ...[
                                  if (i > 0) const Spacer(),
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          stats[i].$1,
                                          size: 15,
                                          color: _statIcon,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            stats[i].$2,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: _statText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 收起态：横向迷你档案栏淡入接管（头像 + 名字 + 陪伴天数 + 箭头），
          // 填满通栏渐变，避免只有孤立小头像的空旷感
          Positioned.fill(
            child: Opacity(
              opacity: t,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pushNamed('/pet/detail'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: avatarImg(selected?.headimg ?? ''),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '陪伴的第108天',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
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

/// 浅色同心圆装饰组（档案卡四角）。
class _DecoRings extends StatelessWidget {
  const _DecoRings();

  @override
  Widget build(BuildContext context) {
    const size = 170.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final d in const [size, size * 0.7, size * 0.42])
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF0E6E1), width: 1),
              ),
            ),
        ],
      ),
    );
  }
}

/// 功能入口宫格：精彩瞬间 / 真实回忆 / 时间胶囊 / 冒险日记。
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('assets/images/icon/m-a1.png', '精彩瞬间', '瞬间照片捕捉', Color(0xFFF2EDF4)),
      ('assets/images/icon/m-a2.png', '真实回忆', '细节成长记录', Color(0xFFEDF3F5)),
      ('assets/images/icon/m-a3.png', '时间胶囊', '成长关键节点', Color(0xFFEEF3EA)),
      ('assets/images/icon/m-a4.png', '冒险日记', 'AI宠物故事', Color(0xFFFAEDE8)),
    ];
    // 手动 2×2 布局：避免 GridView 嵌在滚动容器里 shrinkWrap 测高不准、撑出空隙
    Widget tile((String, String, String, Color) it, {VoidCallback? onTap}) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 76,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        it.$2,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: PetPage._ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        it.$3,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB4A8AC),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: it.$4,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(it.$1, width: 26, height: 26),
                ),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: tile(
                  items[0],
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.highlights),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: tile(items[1])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: tile(items[2])),
              const SizedBox(width: 10),
              Expanded(child: tile(items[3])),
            ],
          ),
        ],
      ),
    );
  }
}

/// 通用卡片头：标题（可带数量角标）+ 右侧「全部 >」。
class _CardHeader extends StatelessWidget {
  final String title;
  final int? count;
  const _CardHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: PetPage._ink,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, color: Color(0xFFB9AEB2)),
          ),
        ],
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // TODO: 全部列表页
          child: const Row(
            children: [
              Text(
                '全部',
                style: TextStyle(fontSize: 12, color: PetPage._pinkText),
              ),
              Icon(Icons.chevron_right, size: 16, color: PetPage._pinkText),
            ],
          ),
        ),
      ],
    );
  }
}

/// 今日冒险日记卡：左图右文 + 底部来源与时间。
class _AdventureDiaryCard extends StatelessWidget {
  const _AdventureDiaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const _CardHeader(title: '今日冒险日记'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/icon/group-banner-1.png',
                  width: 80,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '窗台守望者',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PetPage._ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '今天阳光特别好。窗外那只橘色的家伙大摇大摆走过， 小白拍了…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: PetPage._sub,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // 标签胶囊：第12周（粉）
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: PetPage._tagBg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            '第12周',
                            style: TextStyle(
                              fontSize: 11,
                              color: PetPage._pinkText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 标签胶囊：已更新（绿）
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F2E7),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            '已更新',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF5E9E6A),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '09-28 10:30',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFC0B5B9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 今日集锦卡：竖排视频集锦（封面 + 播放按钮 + 时长 + 标题 + 日期 + 标签）。
class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        image: 'assets/images/group-1.png',
        duration: '0:32',
        title: '超级神虎第一次喝水',
        date: '2026-09-28 10:30',
        tags: ['精彩瞬间', '设备记录', 'AI识别'],
      ),
      (
        image: 'assets/images/group-1.png',
        duration: '0:24',
        title: '超级神虎学会了使用猫砂盆',
        date: '2026-09-28 08:22',
        tags: ['真实回忆', '设备记录', 'AI识别'],
      ),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _CardHeader(title: '今日集锦', count: items.length),
          const SizedBox(height: 12),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _HighlightItem(data: items[i]),
          ],
        ],
      ),
    );
  }
}

/// 单条集锦：视频封面（播放按钮/纪实角标/时长）+ 标题 + 日期 + 标签。
class _HighlightItem extends StatelessWidget {
  final ({
    String image,
    String duration,
    String title,
    String date,
    List<String> tags,
  })
  data;
  const _HighlightItem({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 封面
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                data.image,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            // 居中播放按钮
            Center(
              child: SizedBox(
                height: 180,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Image.asset(
                          'assets/images/icon/vector-ico.png',
                          width: 22,
                          height: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 左下「纪实」角标
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '纪实',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ),
            // 右下时长
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.duration,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          data.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: PetPage._ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.date,
          style: const TextStyle(fontSize: 11, color: Color(0xFFC0B5B9)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < data.tags.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PetPage._tagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.tags[i],
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFA97F8C),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 底部 AI 问答浮条：与健康页一致（白底 + 阴影，紧贴胶囊 TabBar 上方）。
class _AiBar extends StatelessWidget {
  const _AiBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143D2E33),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: PetPage._brand),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '有什么问题都可以问我~',
              style: TextStyle(fontSize: 13, color: PetPage._sub),
            ),
          ),
          Image.asset(
            'assets/images/icon/voice-ico.png',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PetPage._brand,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/icon/send-ico.png',
              width: 18,
              height: 18,
            ),
          ),
        ],
      ),
    );
  }
}
