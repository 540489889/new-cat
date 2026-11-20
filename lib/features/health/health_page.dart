import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pet/pet_state.dart';
import 'vital_records_page.dart';

/// 健康页：本周健康概览 + 功能入口宫格 + 今日状态 + 近期异常 + 护理提醒 + AI 问答浮条。
/// UI 按设计稿 1:1 还原；数据当前为本地 mock，接入后端后替换即可。
class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  // 设计稿色板
  static const Color _bg = Color(0xFFF7F2ED); // 页面暖米底
  static const Color _ink = Color(0xFF3D2E33); // 主文字
  static const Color _body = Color(0xFF5C4A50); // 正文文字
  static const Color _sub = Color(0xFFA89EA2); // 次要文字
  static const Color _brand = Color(0xFF7F6370); // 品牌紫
  static const Color _iconBg = Color(0xFFF3E9EF); // 图标圆底
  static const Color _iconInk = Color(0xFF8A6A7E); // 图标深紫
  static const Color _goodBg = Color(0xFFE7F2E7); // 绿标签底
  static const Color _goodInk = Color(0xFF4E9B58); // 绿标签字
  static const Color _warnBg = Color(0xFFFBEEE0); // 橙标签底
  static const Color _warnInk = Color(0xFFD98E3B); // 橙标签字

  /// 标题栏高度（不含状态栏）：内容滚动盒子的上边界，
  /// 也是「状态栏 + 标题」占用的高度
  static const double _titleBarHeight = 58;

  @override
  State<HealthPage> createState() => _HealthPageState();
}

/// 页面状态：滚动盒子用 CustomScrollView，顶部头像板块为折叠头。
class _HealthPageState extends State<HealthPage> {
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
    // extendBody 下 padding.bottom 已含底部胶囊 TabBar 整体高度，
    // 只需再让出 AI 浮条（48）+ 上下间距
    final bottomPad = bottomInset + 76.0;
    return Scaffold(
      backgroundColor: HealthPage._bg,
      body: Stack(
      children: [
        // 标题栏（状态栏 + 标题 + 日期）固定在顶部，不随滚动
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TitleBar(topInset: topInset),
        ),
        // 滚动内容盒子：从标题栏下方开始。
        // 头像板块作为折叠头 pinned 在此盒子顶部：上滑收起为迷你栏，
        // 下滑展开为大头像轮播，始终保留宠物切换入口。
        Positioned(
          top: topInset + HealthPage._titleBarHeight,
          left: 0,
          right: 0,
          bottom: 0,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: const _AvatarFoldDelegate(),
              ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomPad),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 注意：这里刻意不用 const —— const 无参实例在热重载时会被
                    // 判定为 identical 而跳过整个子树重建，导致改动不生效
                    _WeeklyCard(),
                    _EntryGrid(),
                    const _TodayCard(),
                    const _AbnormalCard(),
                    const _CareCard(),
                  ]),
                ),
              ),
            ],
          ),
        ),
          // 底部 AI 问答浮条：紧贴胶囊 TabBar 上方。
          // 注意 padding.bottom 已含 TabBar 高度（extendBody 注入），
          // 勿再加大偏移，否则浮条会悬到卡片中间形成阴影块
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

/// 固定标题栏：状态栏 + 「健康 / 日期」，不随滚动。
/// 紫粉渐变与头像区、收起态迷你栏连成一条完整渐变带。
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: topInset + HealthPage._titleBarHeight,
      // 标题下沉贴底：缩短「健康」到头像区的视觉空隙
      padding: EdgeInsets.fromLTRB(0, topInset, 0, 8),
      // 顶部深紫棕 → 底部中粉紫，与下方头像区渐变起点无缝衔接
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8E6B84), Color(0xFFB48CA3)],
        ),
      ),
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('健康',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('9月28日',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85))),
            ),
          ],
        ),
      ),
    );
  }
}

/// 头像板块折叠头 delegate：上滑从大头像轮播平滑收起为迷你栏（头像 + 名字）。
/// 对齐宠物页 _ProfileCardDelegate 的做法，min/max 不等 + shrinkOffset 插值。
class _AvatarFoldDelegate extends SliverPersistentHeaderDelegate {
  const _AvatarFoldDelegate();

  static const double expandedExtent = 110;
  static const double collapsedExtent = 38;

  @override
  double get maxExtent => expandedExtent;

  @override
  double get minExtent => collapsedExtent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (expandedExtent - collapsedExtent))
        .clamp(0.0, 1.0);
    // 刻意不用 const 缓存实例：收缩比例每帧变化，需要实时重建
    return _AvatarFoldCard(collapsed: t);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

/// 头像折叠卡：t=0 大头像轮播，t=1 收起为通栏迷你栏（小头像 + 名字 + 箭头）。
class _AvatarFoldCard extends StatelessWidget {
  const _AvatarFoldCard({required this.collapsed});

  final double collapsed;

  @override
  Widget build(BuildContext context) {
    final t = collapsed.clamp(0.0, 1.0);
    final petState = context.watch<PetState>();
    final selected = petState.selectedPet;
    final name = selected?.nickname ?? '';

    // 背景层始终不透明：展开时与标题栏底部同色渐隐到页面暖米底，
    // 收起时加深为通栏色带。避免过去两层半透明叠加露出白色蒙层。
    final bgTop = Color.lerp(
      const Color(0xFFB48CA3), const Color(0xFFB48CA3), t)!;
    final bgBottom = Color.lerp(
      HealthPage._bg, const Color(0xFFC9A4B6), t)!;

    return Stack(
      children: [
        // 单一不透明背景层
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgBottom],
              ),
            ),
          ),
        ),
        // 展开态内容：大头像轮播，随收起淡出
        Positioned.fill(
          child: Opacity(
            opacity: 1 - t,
            child: IgnorePointer(
              ignoring: t > 0.9,
              child: const Center(child: _PetAvatarCarousel()),
            ),
          ),
        ),
        // 收起态内容：小头像 + 名字 + 箭头，点击切换下一只宠物
        Positioned.fill(
          child: Opacity(
            opacity: t,
            child: IgnorePointer(
              ignoring: t < 0.1,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final pets = petState.pets;
                  if (pets.isEmpty) return;
                  petState.selectPet(
                      (petState.selectedIndex + 1) % pets.length);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _PetAvatar(
                          head: selected?.headimg ?? '',
                          ringed: true,
                          size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name.isEmpty ? '我的宠物' : name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 头像描边色（与宠物页一致）
const Color _ring = Color(0xFFC48FA5);

/// 圆形头像（白色描边，可选粉色描边）；headimg 为空时回退本地图。
class _PetAvatar extends StatelessWidget {
  final String head;
  final bool ringed;
  final double size;
  const _PetAvatar({
    required this.head,
    required this.ringed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ringed ? 5 : 2),
      decoration: ringed
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ring, width: 2),
            )
          : const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        // headimg 为空时回退到本地图
        child: head.isNotEmpty
            ? Image.network(head, fit: BoxFit.cover)
            : Image.asset('assets/images/group-1.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// 头像轮播：对齐宠物页，多宠物可左右滑动/点击切换；单宠物退化为静态大头像。
/// 接入 PetState（app 级 provider），与宠物页共享选中态。
class _PetAvatarCarousel extends StatefulWidget {
  const _PetAvatarCarousel();

  @override
  State<_PetAvatarCarousel> createState() => _PetAvatarCarouselState();
}

class _PetAvatarCarouselState extends State<_PetAvatarCarousel> {
  PageController? _pageCtrl;
  int _petCount = 0;
  PetState? _pet; // 缓存引用，dispose 时安全移除监听（避免卸载查祖先）
  bool _listenerAttached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pet = context.read<PetState>();
    if (!_listenerAttached) {
      _pet = pet;
      pet.addListener(_syncPage); // 选中项变化（宠物页/选择弹窗）时跟随
      _listenerAttached = true;
    }
    final pets = pet.pets;
    if (pets.length != _petCount) {
      // 宠物数量变化（首帧为空 -> 加载完成）时重建控制器并对齐当前选中项
      _petCount = pets.length;
      _pageCtrl?.dispose();
      _pageCtrl = PageController(
        viewportFraction: 0.34,
        initialPage: pets.isEmpty
            ? 0
            : pet.selectedIndex.clamp(0, pets.length - 1),
      );
    } else if (_pageCtrl != null && pets.isNotEmpty) {
      // 选中项被外部改变时平滑跟随
      final target = pet.selectedIndex.clamp(0, pets.length - 1);
      if (_pageCtrl!.hasClients && (_pageCtrl!.page?.round() ?? -1) != target) {
        _pageCtrl!.animateToPage(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _syncPage() {
    final pets = _pet?.pets ?? [];
    if (pets.isEmpty || _pageCtrl?.hasClients != true) return;
    final target = (_pet?.selectedIndex ?? 0).clamp(0, pets.length - 1);
    if ((_pageCtrl!.page?.round() ?? -1) != target) {
      _pageCtrl!.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _tapNext() {
    final pets = _pet?.pets ?? [];
    if (pets.isEmpty) return;
    final cur = _pageCtrl?.page?.round() ?? _pet!.selectedIndex;
    _pet?.selectPet((cur + 1) % pets.length);
  }

  @override
  void dispose() {
    if (_listenerAttached) _pet?.removeListener(_syncPage);
    _pageCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetState>();
    final pets = pet.pets;
    if (pets.isEmpty) {
      // 无数据：退化为静态大头像（同样占 92 高度，保证与轮播一致的下间距）
      return SizedBox(
        height: 92,
        child: Center(
          child: const _PetAvatar(head: '', ringed: true, size: 80),
        ),
      );
    }
    return GestureDetector(
      onTap: _tapNext,
      child: SizedBox(
        height: 92,
        child: PageView.builder(
          controller: _pageCtrl,
          itemCount: pets.length,
          clipBehavior: Clip.none,
          onPageChanged: (i) => _pet?.selectPet(i),
          itemBuilder: (_, i) {
            final head = pets[i].headimg;
            return AnimatedBuilder(
              animation: _pageCtrl!,
              builder: (ctx, __) {
                final page = _pageCtrl!.page ?? pet.selectedIndex.toDouble();
                final diff = i - page;
                final scale = (1 - diff.abs() * 0.42).clamp(0.55, 1.0);
                final angle = diff * 0.12;
                final ringed = diff.abs() < 0.5; // 仅当前头像带粉色描边
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0016)
                    ..rotateY(angle),
                  child: Transform.scale(
                    scale: scale,
                    child: Center(
                      child: _PetAvatar(head: head, ringed: ringed, size: 80),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// 通用白卡：圆角 16，左右 12 边距，卡间 12 间距。
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// 卡片标题行：左侧标题（可带副注）+ 右侧「xxx ›」。
class _CardHeader extends StatelessWidget {
  final String title;
  final String? note;
  final String action;
  const _CardHeader({required this.title, this.note, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 左侧标题 + 日期说明，按基线对齐
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HealthPage._ink,
              ),
            ),
            if (note != null) ...[
              const SizedBox(width: 6),
              Text(
                note!,
                style: const TextStyle(fontSize: 10, color: HealthPage._sub),
              ),
            ],
          ],
        ),
        const Spacer(),
        // 右侧「详情 ›」整体垂直居中
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action,
              style: const TextStyle(fontSize: 11, color: HealthPage._sub),
            ),
            const Icon(Icons.chevron_right, size: 14, color: HealthPage._sub),
          ],
        ),
      ],
    );
  }
}

/// 小状态标签（绿/橙）。
class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color ink;
  const _Tag(this.text, {required this.bg, required this.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ink),
      ),
    );
  }
}

/// 本周健康概览卡。
class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard();

  @override
  Widget build(BuildContext context) {
    // 概览行开头展示当前宠物昵称（如「超级神虎」）
    final petName = context.watch<PetState>().selectedPet?.nickname ?? '';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '本周健康', note: '9月5日 至 8月11日', action: '详情'),
          const SizedBox(height: 8),
          Row(
            children: [
              if (petName.isNotEmpty) ...[
                Text(
                  petName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: HealthPage._ink,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Expanded(
                child: Text(
                  '本周整体稳定，状态良好～',
                  style: TextStyle(fontSize: 11, color: HealthPage._sub),
                ),
              ),
              const _Tag(
                '完美状态',
                bg: HealthPage._goodBg,
                ink: HealthPage._goodInk,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 参考稿：两条要点放在浅米色圆角内衬容器里
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4E8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bullet(
                  color: HealthPage._goodInk,
                  text: '饮水量较上周增加 8%，已恢复到日常范围。',
                ),
                SizedBox(height: 8),
                _Bullet(color: HealthPage._warnInk, text: '周三出现一次进食量偏低，次日恢复。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 要点条目：彩色圆点 + 文字。
class _Bullet extends StatelessWidget {
  final Color color;
  final String text;
  const _Bullet({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: HealthPage._body,
            ),
          ),
        ),
      ],
    );
  }
}

/// 功能入口宫格：左侧「体征记录」整高卡 + 右侧「健康/护理」「智能报告」两卡叠放。
class _EntryGrid extends StatelessWidget {
  const _EntryGrid();

  @override
  Widget build(BuildContext context) {
    Widget card({required Widget child}) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );

    // 标题 + 紧随其后的箭头
    Widget titleRow(String title) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: HealthPage._ink,
          ),
        ),
        const Icon(Icons.chevron_right, size: 15, color: HealthPage._sub),
      ],
    );

    Widget subText(String sub) =>
        Text(sub, style: const TextStyle(fontSize: 11, color: HealthPage._sub));

    // withNoTextScaling：该宫格是固定尺寸的图标卡，系统大字体缩放会把
    // IntrinsicHeight 预估高度撑爆，导致偶发 bottom overflow
    return MediaQuery.withNoTextScaling(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左：体征记录高卡（标题 + 副标题 + 标签，右下角大图标绝对定位）
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VitalRecordsPage()),
                  ),
                  child: card(
                    // 图标用 Positioned 移出 Column 固定高度链：
                    // Column 固定内容只剩 ~71px，即使 dry/wet 布局有几 px
                    // 差异也不会再溢出（原来图标 56px 在链上极易触顶）
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleRow('体征记录'),
                            const SizedBox(height: 4),
                            subText('体重/睡眠/如厕'),
                            const SizedBox(height: 8),
                            const _Tag(
                              '健康良好',
                              bg: HealthPage._goodBg,
                              ink: HealthPage._goodInk,
                            ),
                          ],
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEEFA),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/icon/m-b1.png',
                              width: 34,
                              height: 34,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 右：两卡上下叠放，图标在右侧垂直居中
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: card(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  titleRow('健康/护理'),
                                  const SizedBox(height: 4),
                                  subText('清洁/疫苗/用药'),
                                ],
                              ),
                            ),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5F3EE),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/images/icon/m-b2.png',
                                width: 26,
                                height: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: card(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  titleRow('智能报告'),
                                  const SizedBox(height: 4),
                                  subText('周报/月报/年报'),
                                ],
                              ),
                            ),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2EDF4),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/images/icon/m-b3.png',
                                width: 26,
                                height: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 今日状态卡：饮水 / 进食 / 运动 三项实时数据。
class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    // 分隔线：1px 逻辑像素，适中不透明度 → 清晰可见的细发丝线（不过粗也不过淡）
    Widget divider() => Container(height: 1, color: const Color(0x66F1EAE4));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '今日状态', action: '历史数据'),
          const SizedBox(height: 12),
          const _TodayRow(
            icon: 'assets/images/icon/m-c1.png',
            iconBg: Color(0xFF80BFD0),
            title: '饮水',
            note: '来自饮水器 A',
            tag: _Tag('正常', bg: HealthPage._goodBg, ink: HealthPage._goodInk),
            stats: [('饮水量', '180ml'), ('次数', '6')],
          ),
          const SizedBox(height: 12),
          divider(),
          const SizedBox(height: 12),
          const _TodayRow(
            icon: 'assets/images/icon/m-c2.png',
            iconBg: Color(0xFFE8B99F),
            title: '进食',
            note: '粮仓 A 为主',
            tag: _Tag('偏少', bg: HealthPage._warnBg, ink: HealthPage._warnInk),
            stats: [('饮水量', '180g'), ('次数', '3')],
          ),
          const SizedBox(height: 12),
          divider(),
          const SizedBox(height: 12),
          const _TodayRow(
            icon: 'assets/images/icon/m-c3.png',
            iconBg: Color(0xFF82BFA9),
            title: '运动',
            note: '来自摄像头 A',
            tag: _Tag('稳定', bg: HealthPage._goodBg, ink: HealthPage._goodInk),
            stats: [('最近一次', '1.5h')],
          ),
        ],
      ),
    );
  }
}

/// 今日状态单行：圆角方底图标（m-c 系列）+ 名称/来源 + 状态标签 + 标签/数值行。
class _TodayRow extends StatelessWidget {
  final String icon; // 图标资源路径
  final Color iconBg; // 图标圆角方底背景色
  final String title;
  final String note;
  final _Tag tag;
  final List<(String, String)> stats; // (灰色标签, 深色数值)
  const _TodayRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.note,
    required this.tag,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 圆角方底图标（同宠物页功能图标样式）
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: Image.asset(icon, width: 24, height: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HealthPage._ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    note,
                    style: const TextStyle(
                      fontSize: 10,
                      color: HealthPage._sub,
                    ),
                  ),
                  const Spacer(),
                  tag,
                ],
              ),
              const SizedBox(height: 6),
              // 数值行：灰色标签 + 深色数值，项间细分隔线
              Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 10,
                        color: const Color(0xFFE8E0DA),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      stats[i].$1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HealthPage._sub,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      stats[i].$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: HealthPage._ink,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 近期异常卡：异常列表 + 底部「问问AI」按钮。
class _AbnormalCard extends StatelessWidget {
  const _AbnormalCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '近期异常', action: '全部'),
          const SizedBox(height: 12),
          const _AbnormalItem(
            dotAsset: 'assets/images/icon/lb-ico.png',
            title: '进食量降低',
            tag: _Tag('已恢复', bg: HealthPage._goodBg, ink: HealthPage._goodInk),
            body: '8月2日进食仅28g，远低于日均58g，持续1天已恢复。',
            date: '2026-09-28',
          ),
          const SizedBox(height: 12),
          const _AbnormalItem(
            dotAsset: 'assets/images/icon/lb-ico.png',
            title: '饮水离线',
            tag: _Tag('待处理', bg: HealthPage._warnBg, ink: HealthPage._warnInk),
            body: '智能饮水机离线24小时，期间无饮水数据，设备数据持续异常，需人工处理。',
            date: '2026-09-28',
          ),
          const SizedBox(height: 12),
          // 问问AI 按钮
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: HealthPage._iconBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: HealthPage._iconInk,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '问问AI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HealthPage._iconInk,
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

/// 异常条目：彩点 + 标题/状态标签 + 正文 + 日期。
class _AbnormalItem extends StatelessWidget {
  final String dotAsset; // 前置图标资源路径（替换原来的彩色圆点）
  final String title;
  final _Tag tag;
  final String body;
  final String date;
  const _AbnormalItem({
    required this.dotAsset,
    required this.title,
    required this.tag,
    required this.body,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(dotAsset, width: 16, height: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: HealthPage._ink,
              ),
            ),
            const Spacer(),
            tag,
          ],
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: HealthPage._sub,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: const TextStyle(fontSize: 11, color: HealthPage._sub),
        ),
      ],
    );
  }
}

/// 护理提醒卡：疫苗 / 清洁 / 洗护 列表。
class _CareCard extends StatelessWidget {
  const _CareCard();

  @override
  Widget build(BuildContext context) {
    // 分隔线：与「今日状态」卡同款的 1px 细发丝线
    Widget divider() => Container(height: 1, color: const Color(0x66F1EAE4));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '护理提醒', action: '全部'),
          const SizedBox(height: 12),
          const _CareRow(
            iconAsset: 'assets/images/icon/w-1.png',
            title: '健康',
            sub: '猫三联疫苗',
            date: '2026-09-28',
          ),
          const SizedBox(height: 12),
          divider(),
          const SizedBox(height: 12),
          const _CareRow(
            iconAsset: 'assets/images/icon/w-2.png',
            title: '清洁',
            sub: '驱虫 Rachel',
            date: '2026-09-28',
          ),
          const SizedBox(height: 12),
          divider(),
          const SizedBox(height: 12),
          const _CareRow(
            iconAsset: 'assets/images/icon/w-3.png',
            title: '洗护',
            sub: '修剪指甲',
            date: '2026-09-28',
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '还有 8 项护理待关注',
              style: const TextStyle(fontSize: 10, color: HealthPage._sub),
            ),
          ),
        ],
      ),
    );
  }
}

/// 护理提醒单行：圆底图标 + 标题/副标 + 右侧「即将过期」标签和日期。
class _CareRow extends StatelessWidget {
  final String iconAsset; // 前置图标资源路径
  final String title;
  final String sub;
  final String date;
  const _CareRow({
    required this.iconAsset,
    required this.title,
    required this.sub,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE5F3EE),
          ),
          alignment: Alignment.center,
          child: Image.asset(iconAsset, width: 22, height: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HealthPage._ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: const TextStyle(fontSize: 11, color: HealthPage._sub),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _Tag(
              '即将过期',
              bg: HealthPage._warnBg,
              ink: HealthPage._warnInk,
            ),
            const SizedBox(height: 3),
            Text(
              date,
              style: const TextStyle(fontSize: 10, color: HealthPage._sub),
            ),
          ],
        ),
      ],
    );
  }
}

/// 底部 AI 问答浮条：AI 图标 + 提示语 + 麦克风 + 发送按钮。
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
          const Icon(Icons.auto_awesome, size: 18, color: HealthPage._brand),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '有什么问题都可以问我~',
              style: TextStyle(fontSize: 13, color: HealthPage._sub),
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
              color: HealthPage._brand,
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
