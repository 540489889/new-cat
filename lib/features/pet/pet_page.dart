import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pet/pet_state.dart';
import '../../shared/widgets/pet_picker.dart';

/// 宠物页：宠物档案卡 + 功能入口宫格 + 今日冒险日记 + 今日集锦 + AI 问答浮条。
/// UI 按设计稿 1:1 还原；数据当前为本地 mock，接入后端后替换即可。
class PetPage extends StatelessWidget {
  const PetPage({super.key});

  // 设计稿色板
  static const Color _bg = Color(0xFFF5F0EA); // 页面暖米底
  static const Color _ink = Color(0xFF3D2E33); // 主文字
  static const Color _sub = Color(0xFFA89EA2); // 次要文字
  static const Color _pinkText = Color(0xFFB08CA0); // 链接/标签粉
  static const Color _iconPinkBg = Color(0xFFF4E3E6); // 功能卡图标底
  static const Color _tagBg = Color(0xFFF6ECEF); // 标签底

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // 底部让出：悬浮胶囊 TabBar（约56 + 间距12）+ 安全区
    final bottomBarHeight = MediaQuery.of(context).padding.bottom + 80;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            // 顶部留白 = 固定标题栏高度，避免首张卡片被标题遮挡
            padding: EdgeInsets.only(top: topInset + 56, bottom: bottomBarHeight + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 注意：这里刻意不用 const —— const 无参实例在热重载时会被
                // 判定为 identical 而跳过整个子树重建，导致改动不生效
                _PetProfileCard(),
                _FeatureGrid(),
                _AdventureDiaryCard(),
                _HighlightsCard(),
              ],
            ),
          ),
          // 顶部固定标题栏（不随滚动移动）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Header(topInset: topInset),
          ),
        ],
      ),
    );
  }
}

/// 顶部标题栏：宠物 + 数量角标 + 右侧添加按钮。
class _Header extends StatelessWidget {
  final double topInset;
  const _Header({required this.topInset});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<PetState>().pets.length;
    return Container(
      // 固定标题栏背景与页面同色，滚动时卡片从其下方滑过
      color: PetPage._bg,
      padding: EdgeInsets.only(left: 16, right: 16, top: topInset + 10, bottom: 12),
      child: Row(
        children: [
          const Text('宠物',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: PetPage._ink)),
          const SizedBox(width: 4),
          Text('$count',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB9AEB2))),
          const Spacer(),
          GestureDetector(
            onTap: () {}, // TODO: 添加宠物
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7F6370), Color(0xFF9E6F84)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// 宠物档案卡：头像轮播（可滑动/点击切换宠物）+ 名字（可点选择）+ 陪伴天数 + 属性行，
/// 卡片左上/右下带浅色同心圆装饰。
class _PetProfileCard extends StatefulWidget {
  const _PetProfileCard();

  @override
  State<_PetProfileCard> createState() => _PetProfileCardState();
}

class _PetProfileCardState extends State<_PetProfileCard> {
  static const Color _ring = Color(0xFFC48FA5); // 大头像描边
  static const Color _statIcon = Color(0xFFB98CA0); // 属性图标
  static const Color _statText = Color(0xFF5C4A50); // 属性文字

  PageController? _pageCtrl;
  int _petCount = 0; // 记录已绑定控制器的宠物数量，变化时重建

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pet = context.read<PetState>();
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
        _pageCtrl!.animateToPage(target,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
    context.read<PetState>().removeListener(_syncPage);
    _pageCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petState = context.watch<PetState>();
    final selected = petState.selectedPet;
    final name =
        (selected?.nickname.isNotEmpty == true) ? selected!.nickname : '超级神虎';
    final pets = petState.pets;
    const stats = [
      (Icons.local_florist, '金渐层'),
      (Icons.female, '妹妹'),
      (Icons.cake, '2岁'),
      (Icons.content_cut, '已绝育'),
      (Icons.monitor_weight, '3kg'),
    ];

    ImageProvider avatarImg(String h) => h.isNotEmpty
        ? NetworkImage(h)
        : const AssetImage('assets/images/hero_cat.jpg');

    // 大头像（当前宠物带粉色描边圆，侧边探出的不带）
    Widget bigAvatar(String h, {bool ringed = true}) => Container(
          width: 104,
          height: 104,
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
              height: 112,
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
                      final page = _pageCtrl!.page ??
                          petState.selectedIndex.toDouble();
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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 装饰：左上 / 右下 浅色同心圆
          const Positioned(top: -80, left: -60, child: _DecoRings()),
          const Positioned(bottom: -80, right: -60, child: _DecoRings()),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                avatarWidget,
                const SizedBox(height: 8),
                // 名字 + 右箭头（点击弹出宠物选择）
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showPetPicker(context, petState),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: PetPage._ink)),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 18, color: PetPage._ink),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('和$name的第108天',
                    style: const TextStyle(fontSize: 13, color: PetPage._sub)),
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
                              Icon(stats[i].$1, size: 15, color: _statIcon),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(stats[i].$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14, color: _statText)),
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
      (Icons.photo_camera, '精彩瞬间', '瞬间照片捕捉'),
      (Icons.image, '真实回忆', '细节成长记录'),
      (Icons.access_time_filled, '时间胶囊', '成长关键节点'),
      (Icons.menu_book, '冒险日记', 'AI宠物故事'),
    ];
    // 手动 2×2 布局：避免 GridView 嵌在滚动容器里 shrinkWrap 测高不准、撑出空隙
    Widget tile((IconData, String, String) it) => Container(
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
                    Text(it.$2,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: PetPage._ink)),
                    const SizedBox(height: 5),
                    Text(it.$3,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFB4A8AC))),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PetPage._iconPinkBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(it.$1, size: 22, color: const Color(0xFF9E6F84)),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: tile(items[0])),
            const SizedBox(width: 10),
            Expanded(child: tile(items[1])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: tile(items[2])),
            const SizedBox(width: 10),
            Expanded(child: tile(items[3])),
          ]),
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
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PetPage._ink)),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text('$count',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB9AEB2))),
        ],
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // TODO: 全部列表页
          child: const Row(
            children: [
              Text('全部',
                  style: TextStyle(fontSize: 12, color: PetPage._pinkText)),
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
                  'assets/images/cat_playing.jpg',
                  width: 96,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('窗台守望者',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PetPage._ink)),
                    SizedBox(height: 4),
                    Text(
                      '今天阳光特别好，窗户外那只橙色的大橙大虎走过… 小白拍了…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: PetPage._sub, height: 1.4),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text('冒险日记 · 第12周',
                            style: TextStyle(
                                fontSize: 11, color: PetPage._pinkText)),
                        Spacer(),
                        Text('09-28 10:30',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFC0B5B9))),
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
        image: 'assets/images/cat_eating.jpg',
        duration: '0:32',
        title: '超级神虎第一次喝水',
        date: '2026-09-28 10:30',
        tags: ['精彩瞬间', '设备记录', 'AI识别'],
      ),
      (
        image: 'assets/images/cat_cleaning.jpg',
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
  final ({String image, String duration, String title, String date, List<String> tags})
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
            const Center(
              child: SizedBox(
                height: 180,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x66FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.play_arrow,
                          color: Colors.white, size: 28),
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
                child: const Text('纪实',
                    style: TextStyle(fontSize: 10, color: Colors.white)),
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
                child: Text(data.duration,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(data.title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PetPage._ink)),
        const SizedBox(height: 4),
        Text(data.date,
            style: const TextStyle(fontSize: 11, color: Color(0xFFC0B5B9))),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < data.tags.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PetPage._tagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(data.tags[i],
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFA97F8C))),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
