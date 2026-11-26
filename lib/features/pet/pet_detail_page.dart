import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pet/pet_state.dart';
import '../../core/router/app_router.dart';

/// 宠物详情页：按设计稿还原。
/// 顶部粉紫渐变标题栏（返回 / 居中标题 / 分享）→ 宠物信息卡（头像+名字+到家日期）
/// → 宠物画像卡（性格标签）→ 基础资料卡（两列键值对）。
/// 名字与头像取自当前选中宠物 [PetState]；画像与资料为本地 mock，接入后端后替换。
///
/// 动效：
/// - 顶部渐变上两团柔光缓慢呼吸漂移；
/// - 三张卡片依次淡入上移（[_Reveal]）；
/// - 头像带呼吸光晕，滚动时轻微上浮（视差）；
/// - 陪伴天数数字滚动递增；
/// - 返回 / 分享 / 编辑按钮按压回弹。
class PetDetailPage extends StatefulWidget {
  const PetDetailPage({super.key});

  // 设计稿色板（与宠物页/首页统一）
  static const Color _bg = Color(0xFFF5F0EA); // 页面暖米底
  static const Color _ink = Color(0xFF3D2E33); // 主文字
  static const Color _sub = Color(0xFFA89EA2); // 次要文字
  static const Color _pinkText = Color(0xFFB08CA0); // 编辑按钮粉
  static const Color _tagBg = Color(0xFFF6ECEF); // 编辑按钮底

  // 顶部渐变（与宠物页同款）：深紫棕→粉紫→浅粉，底部透明融入页面暖米底
  static const LinearGradient _topGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF8E6B84), // 顶部深紫棕
      Color(0xFFB48CA3), // 中部粉紫
      Color(0xFFE5D2DC), // 浅粉紫
      Color(0x00E5D2DC), // 渐变底部透明
    ],
    stops: [0.0, 0.42, 0.72, 0.89],
  );

  /// 顶部渐变背景层的总高度额外量（实际高度 = topInset + 该值）。
  static const double _gradientHeightExtra = 300.0;

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();

  /// 顶部柔光呼吸：驱动两团光斑缓慢上下漂移与明暗变化。
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _breath.dispose();
    super.dispose();
  }

  /// 顶部柔光层：右上粉光 + 左下暖白光，随 [_breath] 缓慢漂移。
  Widget _glowLayer() {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_breath.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -70 + 16 * v,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD3E4)
                          .withValues(alpha: 0.40 - 0.14 * v),
                      const Color(0x00FFD3E4),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 130 - 12 * v,
              left: -90,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.18 - 0.08 * v),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: PetDetailPage._bg,
      body: Stack(
        children: [
          // 顶部渐变背景层：标题栏与首张卡片都落在渐变上；叠加缓慢漂移的柔光
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + PetDetailPage._gradientHeightExtra,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: PetDetailPage._topGradient,
                      ),
                    ),
                  ),
                  Positioned.fill(child: IgnorePointer(child: _glowLayer())),
                ],
              ),
            ),
          ),
          // 滚动内容：三张白色卡片，依次淡入
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: topInset + 62,
                bottom: bottomInset + 24,
              ),
              child: Column(
                children: [
                  // 刻意不用 const：保证热重载时子树正常重建
                  _Reveal(child: _ProfileCard(scroll: _scroll)),
                  const SizedBox(height: 12),
                  _Reveal(
                    delay: const Duration(milliseconds: 90),
                    child: const _PortraitCard(),
                  ),
                  const SizedBox(height: 12),
                  _Reveal(
                    delay: const Duration(milliseconds: 180),
                    child: const _BaseInfoCard(),
                  ),
                ],
              ),
            ),
          ),
          // 顶部固定标题栏：返回 + 居中标题 + 分享
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

/// 顶部标题栏：白色圆形返回钮 + 居中白字标题 + 白色胶囊分享钮。
class _Header extends StatelessWidget {
  final double topInset;
  const _Header({required this.topInset});

  @override
  Widget build(BuildContext context) {
    // 标题栏自带与背景层同款的渐变背景：取整条渐变的顶部一段，
    // 使其下沿颜色与背景层在同 y 处完全一致 → 上下无缝融为一体；
    // 同时保证滑动时下方白色卡片上移也不会穿透到标题（标题始终有底色）。
    final titleH = topInset + 10 + 36 + 8;
    final bgH = topInset + PetDetailPage._gradientHeightExtra;
    final endY = 2 * bgH / titleH - 1;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(0.0, -1.0),
          end: Alignment(0.0, endY),
          colors: PetDetailPage._topGradient.colors,
          stops: PetDetailPage._topGradient.stops,
        ),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: topInset + 10, bottom: 8),
      child: Row(
        children: [
          // 返回：白色圆形按钮
          _Pressable(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.chevron_left,
                  size: 22, color: PetDetailPage._ink),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('宠物详情',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          // 分享：白色胶囊按钮
          _Pressable(
            onTap: () {}, // TODO: 分享
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/icon/share-ico.png',
                      width: 15, height: 15),
                  const SizedBox(width: 5),
                  const Text('分享',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PetDetailPage._ink)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 宠物信息卡：与宠物页档案卡同款（粉圈头像 + 名字 + 陪伴天数 + 属性行），
/// 去除了轮播，仅静态展示当前选中宠物；保留同心圆装饰（左上 / 右下，同宠物页）。
/// 这里额外加了头像呼吸光晕、虚线环微摆、滚动视差与天数数字滚动。
class _ProfileCard extends StatefulWidget {
  /// 页面滚动控制器：用于头像轻微上浮的视差效果。
  final ScrollController scroll;
  const _ProfileCard({required this.scroll});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard>
    with SingleTickerProviderStateMixin {
  // 与宠物页档案卡同款配色
  static const Color _ring = Color(0xFFC48FA5); // 大头像描边
  static const Color _statIcon = Color(0xFFB98CA0); // 属性图标
  static const Color _statText = Color(0xFF5C4A50); // 属性文字

  /// 头像光晕呼吸 + 虚线环微摆（双向循环，成本低、只重绘头像区域）。
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  ImageProvider _avatarImg(String h) => h.isNotEmpty
      ? NetworkImage(h)
      : const AssetImage('assets/images/group-1.png');

  /// 大头像：呼吸光晕 + 粉色描边圆。
  Widget _avatarBlock(String head) {
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 呼吸光晕
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final v = Curves.easeInOut.transform(_pulse.value);
              return Container(
                width: 96 + 14 * v,
                height: 96 + 14 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF2D6E2).withValues(alpha: 0.55 - 0.3 * v),
                      const Color(0x00F2D6E2),
                    ],
                  ),
                ),
              );
            },
          ),
          // 头像本体
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ring, width: 2),
              color: Colors.white,
            ),
            child: CircleAvatar(backgroundImage: _avatarImg(head)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetState>().selectedPet;
    final name =
        (pet?.nickname.isNotEmpty == true) ? pet!.nickname : '超级神虎';
    final head = pet?.headimg ?? '';

    // 属性行：品种/性别/年龄/绝育/体重（mock，与宠物页一致）
    const stats = [
      (Icons.local_florist, '金渐层'),
      (Icons.female, '妹妹'),
      (Icons.cake, '2岁'),
      (Icons.content_cut, '已绝育'),
      (Icons.monitor_weight, '3kg'),
    ];

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6B84).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 装饰：左上 / 右下 浅色同心圆（与宠物页同款）
          const Positioned(top: -80, left: -60, child: _DecoRings()),
          const Positioned(bottom: -80, right: -60, child: _DecoRings()),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                // 头像视差：向上滚动时轻微上浮，制造层次
                AnimatedBuilder(
                  animation: widget.scroll,
                  builder: (context, child) {
                    final offset =
                        widget.scroll.hasClients ? widget.scroll.offset : 0.0;
                    final dy = -(offset * 0.06).clamp(-8.0, 0.0);
                    return Transform.translate(
                        offset: Offset(0, dy), child: child);
                  },
                  child: _avatarBlock(head),
                ),
                const SizedBox(height: 6),
                // 名字（详情页不切换宠物，无右箭头）
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PetDetailPage._ink)),
                const SizedBox(height: 4),
                // 陪伴天数：数字从 0 滚动到目标值
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: 108),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  builder: (context, days, _) => Text('和$name的第$days天',
                      style: const TextStyle(
                          fontSize: 13, color: PetDetailPage._sub)),
                ),
                const SizedBox(height: 16),
                // 属性行：品种/性别/年龄/绝育/体重，均匀分布
                _Reveal(
                  delay: const Duration(milliseconds: 160),
                  dy: 0.12,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 浅色同心圆装饰组（信息卡两角）。
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

/// 宠物画像卡：性格标签（2×2 + 1 条通栏），数据当前为本地 mock。
class _PortraitCard extends StatelessWidget {
  const _PortraitCard();

  // (图标, 图标色, 底色, 标题, 描述)
  static const List<_Persona> _personas = [
    _Persona(
      icon: Icons.dark_mode,
      color: Color(0xFF8B6FA8),
      bg: Color(0xFFF3EBF6),
      title: '夜猫子',
      desc: '深夜认真巡逻，安静守护小家。',
    ),
    _Persona(
      icon: Icons.explore,
      color: Color(0xFF4CAF6D),
      bg: Color(0xFFE9F4EC),
      title: '小小探险家',
      desc: '探索新家，好奇心拉满！',
    ),
    _Persona(
      icon: Icons.restaurant,
      color: Color(0xFFE8975A),
      bg: Color(0xFFFBEFE3),
      title: '准时饭搭子',
      desc: '饭点雷达，精准定位！',
    ),
    _Persona(
      icon: Icons.wb_sunny,
      color: Color(0xFFF0A24A),
      bg: Color(0xFFFCF4E3),
      title: '阳光观察员',
      desc: '有它陪着，感觉家里都暖了～',
    ),
    _Persona(
      icon: Icons.verified_user,
      color: Color(0xFF5B8DEF),
      bg: Color(0xFFEAF1FC),
      title: '认家小卫士',
      desc: '熟悉每种声音，只为等你回家。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6B84).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片头：标题 + 来源说明
          const Row(
            children: [
              Text('宠物画像',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: PetDetailPage._ink)),
              Spacer(),
              Text('来自日常行为观察',
                  style: TextStyle(
                      fontSize: 12, color: PetDetailPage._sub)),
            ],
          ),
          const SizedBox(height: 14),
          // 2×2 网格（手动布局，避免 GridView 嵌滚动容器测高不准）
          // IntrinsicHeight 让同行的两个格子按内部最高者等高，且不触发无限高度
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Reveal(
                    delay: const Duration(milliseconds: 40),
                    dy: 0.08,
                    child: _PersonaTile(data: _personas[0]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Reveal(
                    delay: const Duration(milliseconds: 120),
                    dy: 0.08,
                    child: _PersonaTile(data: _personas[1]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Reveal(
                    delay: const Duration(milliseconds: 200),
                    dy: 0.08,
                    child: _PersonaTile(data: _personas[2]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Reveal(
                    delay: const Duration(milliseconds: 280),
                    dy: 0.08,
                    child: _PersonaTile(data: _personas[3]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 通栏标签
          _Reveal(
            delay: const Duration(milliseconds: 360),
            dy: 0.08,
            child: _PersonaTile(data: _personas[4]),
          ),
        ],
      ),
    );
  }
}

/// 单个画像标签数据。
class _Persona {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String desc;
  const _Persona({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.desc,
  });
}

/// 单个画像标签：白圆彩icon + 标题 + 描述。
class _PersonaTile extends StatelessWidget {
  final _Persona data;
  const _PersonaTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: data.color.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(data.icon, size: 16, color: data.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PetDetailPage._ink)),
                const SizedBox(height: 4),
                Text(data.desc,
                    style: const TextStyle(
                        fontSize: 12,
                        color: PetDetailPage._sub,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 基础资料卡：标题 + 编辑按钮 + 两列键值对，数据当前为本地 mock。
class _BaseInfoCard extends StatelessWidget {
  const _BaseInfoCard();

  // 每行两个键值对
  static const List<List<(String, String)>> _rows = [
    [('类型', '猫猫'), ('品种', '英国短毛猫')],
    [('性别', '♂ 公'), ('年龄', '2岁')],
    [('体重', '3.5kg'), ('绝育', '已绝育')],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6B84).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片头：标题 + 编辑胶囊
          Row(
            children: [
              const Text('基础资料',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: PetDetailPage._ink)),
              const Spacer(),
              _Pressable(
                onTap: () async {
                  final petState = context.read<PetState>();
                  final pet = petState.selectedPet;
                  if (pet == null) return;
                  final changed = await Navigator.of(context).pushNamed<bool>(
                    AppRoutes.petEdit,
                    arguments: pet,
                  );
                  if (changed == true) {
                    await petState.refresh();
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: PetDetailPage._tagBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('编辑',
                      style: TextStyle(
                          fontSize: 12, color: PetDetailPage._pinkText)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 两列键值对
          for (int i = 0; i < _rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _Reveal(
              delay: Duration(milliseconds: 60 * i),
              dy: 0.16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int j = 0; j < _rows[i].length; j++) ...[
                    if (j > 0) const SizedBox(width: 16),
                    Expanded(
                      child: _InfoItem(
                          label: _rows[i][j].$1, value: _rows[i][j].$2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个键值对：灰 label + 深色 value。
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 14, color: PetDetailPage._sub)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: PetDetailPage._ink)),
        ),
      ],
    );
  }
}

/// 入场揭示：淡入 + 轻微上移，可设置延迟做依次出现的节奏。
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.child,
    this.delay = Duration.zero,
    this.dy = 0.05,
  });

  final Widget child;

  /// 出现延迟，用于交错（stagger）节奏。
  final Duration delay;

  /// 初始下移量（相对自身高度的比例）。
  final double dy;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    // 首帧后再置位，保证隐式动画有初值可比对
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _on = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _on ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _on ? Offset.zero : Offset(0, widget.dy),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// 按压缩放反馈：按下轻微缩小，松开回弹。
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
