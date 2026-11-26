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

  /// 标题栏高度（不含状态栏）：内容滚动盒子的上边界，
  /// 也是「状态栏 + 标题」占用的高度（与健康页一致）
  static const double _titleBarHeight = 58;

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
          // 顶部背景图（置于内容之后）：深紫棕底 + 底部白色波浪，
          // 按屏幕宽度等比铺满；白色波浪与页面底色自然衔接，
          // 滚动时白色卡片盖住背景图，只在卡片四周 / 间隙透出
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/icon/top_bg.png',
              fit: BoxFit.fitWidth,
            ),
          ),
          // 滚动区铺满整屏：标题栏与档案卡都在同一个折叠头里，
          // 上滑时标题一起淡出、迷你栏吸顶，收起后就是「标题栏本身变成了迷你栏」，
          // 而不是标题栏下方再挂一条悬浮卡
          Positioned.fill(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PetHeaderDelegate(topInset: topInset),
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
class _TitleRow extends StatelessWidget {
  const _TitleRow();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<PetState>().pets.length;
    // 高度固定 58：折叠头按「状态栏 + 标题行 + 卡片」叠成一条，
    // 上滑时整体淡出并被头部边界裁切，收起后由迷你栏接管这一行
    return SizedBox(
      height: PetPage._titleBarHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            // 标题压在深紫棕背景图上，用白字保证对比度
            const Text(
              '宠物',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            // 添加宠物：直接用设计稿切图（紫色胶囊 + 号 + 文案），
            // 高度 30、宽度按图片比例自适应；点开引导页，返回 true 说明新增成功
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final changed = await Navigator.of(
                  context,
                ).pushNamed<bool>(AppRoutes.petAdd);
                if (changed == true && context.mounted) {
                  await context.read<PetState>().refresh();
                }
              },
              child: Image.asset(
                'assets/images/icon/btn1.png',
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 折叠头 delegate：标题行 + 档案卡作为一个整体随滚动收起，
/// 收起后迷你栏吸顶——视觉上就是「标题栏本身变成了迷你栏」，
/// 而不是标题栏下方再挂一条悬浮卡。
class _PetHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PetHeaderDelegate({required this.topInset});

  final double topInset;

  /// 档案卡展开高度（含卡片上下 margin）
  static const double cardExtent = 240;

  /// 收起态高度（不含状态栏）：迷你栏一行
  static const double miniBarHeight = 56;

  @override
  double get maxExtent => topInset + PetPage._titleBarHeight + cardExtent;

  @override
  double get minExtent => topInset + miniBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    // 展开内容整体淡出：标题行比卡片消失得早一些，避免露出被裁一半的文字
    final titleFade = (1 - t * 2.2).clamp(0.0, 1.0);
    final cardFade = (1 - t * 1.6).clamp(0.0, 1.0);
    // 迷你栏在展开内容基本让位后淡入
    final miniFade = ((t - 0.45) / 0.55).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        children: [
          // 折叠头背景：与页面顶层完全一致（米白底 + 同一张 top_bg.png），
          // 既保证收起后这块区域不透明、能挡住下方滚上来的内容，
          // 又不会在顶部留下任何额外色块
          const Positioned.fill(child: ColoredBox(color: PetPage._bg)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/icon/top_bg.png',
              fit: BoxFit.fitWidth,
            ),
          ),
          // 展开态：状态栏留白 + 标题行 + 完整档案卡，保持原始尺寸整体淡出，
          // 超出折叠头高度的部分由外层 ClipRect 从上沿裁掉（内容不做形变）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(height: topInset),
                Opacity(opacity: titleFade, child: const _TitleRow()),
                SizedBox(
                  height: cardExtent,
                  child: Opacity(
                    opacity: cardFade,
                    child: const _PetProfileCard(collapsed: 0),
                  ),
                ),
              ],
            ),
          ),
          // 收起态：迷你栏吸顶，占据原来标题行的位置。
          // 必须按 miniFade 关闭命中测试——Opacity 只影响绘制，
          // 展开态下这层不可见但仍会吃掉标题行（含「添加宠物」按钮）的点击
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: miniFade < 0.05,
              child: Opacity(
                opacity: miniFade,
                child: _PetMiniBar(topInset: topInset, height: miniBarHeight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PetHeaderDelegate oldDelegate) =>
      oldDelegate.topInset != topInset;
}

/// 收起后吸顶的迷你栏：小头像 + 名字 + 陪伴天数 + 箭头。
/// 直接压在背景图上（和展开态标题行同一位置），所以文字用白色
class _PetMiniBar extends StatelessWidget {
  const _PetMiniBar({required this.topInset, required this.height});

  final double topInset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final petState = context.watch<PetState>();
    final selected = petState.selectedPet;
    final name = selected?.nickname ?? '我的宠物';
    final head = selected?.headimg ?? '';
    return Column(
      children: [
        SizedBox(height: topInset),
        SizedBox(
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed('/pet/detail'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: head.isNotEmpty
                        ? NetworkImage(head)
                        : const AssetImage('assets/images/group-1.png'),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
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
      ],
    );
  }
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
  int? _animatingTo; // 正在进行的分页动画目标，用于去重（避免同一目标被反复重启）

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
      _animatingTo = null;
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

  /// 统一的分页动画入口。
  /// 同一目标正在进行时直接忽略——否则 selectPet 触发的监听、
  /// 接口回来后的 notify 都会再启动一次动画，视觉上就是「走到一半被拽回去重跑」。
  void _animateToPage(int target) {
    final ctrl = _pageCtrl;
    if (ctrl == null || !ctrl.hasClients) return;
    if ((ctrl.page?.round() ?? -1) == target) return;
    if (_animatingTo == target) return;
    _animatingTo = target;
    ctrl
        .animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _animatingTo = null);
  }

  // 外部（底部面板）切换宠物时，同步轮播到对应页
  void _syncPage() {
    final pet = context.read<PetState>();
    if (pet.pets.isEmpty) return;
    _animateToPage(pet.selectedIndex.clamp(0, pet.pets.length - 1));
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

    // ===== 收起动画 =====
    // 关键：收起过程中展开内容的「布局完全不变」（头像高度、行距、内边距都是常量）。
    // 卡片变矮只靠外层 ClipRect 从上沿裁切，内容本身不位移、不重排，
    // 因此不会出现"内容被挤到上面去"的挤压感。
    // 内容在收起阶段极早处（t<0.35）就整体淡出，裁切过程肉眼几乎看不到。
    final t = widget.collapsed.clamp(0.0, 1.0);
    // 几何量统一走缓出曲线（只用于卡片的圆角 / 边距收拢）
    final et = Curves.easeOutCubic.transform(t);
    // 展开内容的固定布局尺寸（不随 t 变化）
    const vPad = 20.0;
    const avatarH = 96.0;
    final avatarSize = lerpDouble(80, 68, et)!;
    // 错峰淡出：属性行最先消失，天数其次，名字最后，头像最后收尾。
    // 系数放大到内容在 1/3 行程内全部退场，避免与卡片收缩同时发生导致拥挤
    final statsFade = Curves.easeIn.transform((1 - t * 6.0).clamp(0.0, 1.0));
    final daysFade = Curves.easeIn.transform((1 - t * 4.5).clamp(0.0, 1.0));
    final nameFade = Curves.easeIn.transform((1 - t * 3.5).clamp(0.0, 1.0));
    final avatarFade = (1 - t * 3.0).clamp(0.0, 1.0);
    // 内容全部退场后（t>0.35）迷你栏再淡入，两段完全不重叠
    final miniFade = ((t - 0.35) / 0.65).clamp(0.0, 1.0);

    ImageProvider avatarImg(String h) => h.isNotEmpty
        ? NetworkImage(h)
        : const AssetImage('assets/images/group-1.png');

    // 大头像（当前宠物带粉色描边，侧边探出的不带）。
    // padding 固定为 5：若随 ringed 在 5 / 0 之间切换，轮播跨页时头像内容
    // 尺寸会突变（差 10dp），看起来就是「跳一下」——描边只改颜色不改几何
    Widget bigAvatar(String h, {bool ringed = true}) => Container(
      width: avatarSize,
      height: avatarSize,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringed ? _ring : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(backgroundImage: avatarImg(h)),
    );

    // 头像轮播：3D 封面流，只支持左右滑动切换（点击不切换）；
    // 单宠物退化为静态大头像
    final avatarWidget = pets.isEmpty
        ? bigAvatar(selected?.headimg ?? '')
        : SizedBox(
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
          );

    return Container(
      // 收起时左右留白略微内收（12→16）、圆角加大，卡面变成一枚白色胶囊，
      // 始终浮在背景图上
      margin: EdgeInsets.fromLTRB(
        lerpDouble(12, 16, et)!,
        lerpDouble(4, 8, et)!,
        lerpDouble(12, 16, et)!,
        12,
      ),
      // 卡面恒为白色：白卡与背景图的深紫棕形成浮层关系，
      // 收起过程中不会出现「卡片褪色」的色块拼接感
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(lerpDouble(20, 26, et)!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 装饰：左上 / 右下 浅色同心圆（收起时随卡片一起淡出，避免浮在渐变上突兀）
          Positioned(
            top: -80,
            left: -60,
            child: Opacity(opacity: 1 - t, child: const _DecoRings()),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Opacity(opacity: 1 - t, child: const _DecoRings()),
          ),
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
                    // 大头像轮播：随卡片收缩淡出，最后让位给迷你栏的小头像
                    Opacity(opacity: avatarFade, child: avatarWidget),
                    // 名字 / 陪伴天数 / 属性行：收起时自下而上错峰淡出。
                    // 不做高度裁剪——裁剪会让名字残半截、与下方天数行叠出重影
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        // 名字 + 右箭头（点击进入宠物详情）：最后消失
                        Opacity(
                          opacity: nameFade,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                Navigator.of(context).pushNamed('/pet/detail'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: PetPage._ink,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: PetPage._ink,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 陪伴天数行：点击进入宠物详情页（先于名字消失）
                        Opacity(
                          opacity: daysFade,
                          child: GestureDetector(
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
                        ),
                        const SizedBox(height: 16),
                        // 属性行：品种/性别/年龄/绝育/体重（最先消失）
                        Opacity(
                          opacity: statsFade,
                          child: Padding(
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 收起态：白色胶囊里的横向迷你档案栏（小头像 + 名字 + 陪伴天数 + 箭头）。
          // 白底上统一用深色文字，与展开态同一套配色，不出现「白字→黑字」突变。
          // 同样按 miniFade 关闭命中测试，避免透明层吃掉卡片内的点击
          Positioned.fill(
            child: IgnorePointer(
              ignoring: miniFade < 0.05,
              child: Opacity(
                opacity: miniFade,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pushNamed('/pet/detail'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                              color: PetPage._ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '陪伴的第108天',
                          style: TextStyle(fontSize: 11, color: PetPage._sub),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: PetPage._ink,
                        ),
                      ],
                    ),
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
