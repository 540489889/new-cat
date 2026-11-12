import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pet/pet_state.dart';

/// 宠物详情页：按设计稿还原。
/// 顶部粉紫渐变标题栏（返回 / 居中标题 / 分享）→ 宠物信息卡（头像+名字+到家日期）
/// → 宠物画像卡（性格标签）→ 基础资料卡（两列键值对）。
/// 名字与头像取自当前选中宠物 [PetState]；画像与资料为本地 mock，接入后端后替换。
class PetDetailPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // 顶部渐变背景层：标题栏与首张卡片都落在渐变上
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + PetDetailPage._gradientHeightExtra,
            child: Container(
              decoration:
                  const BoxDecoration(gradient: PetDetailPage._topGradient),
            ),
          ),
          // 滚动内容：三张白色卡片
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: topInset + 62,
                bottom: bottomInset + 24,
              ),
              child: Column(
                children: const [
                  // 刻意不用 const：保证热重载时子树正常重建
                  _ProfileCard(),
                  SizedBox(height: 12),
                  _PortraitCard(),
                  SizedBox(height: 12),
                  _BaseInfoCard(),
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
          GestureDetector(
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
          GestureDetector(
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
                  SizedBox(width: 5),
                  Text('分享',
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
class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  // 与宠物页档案卡同款配色
  static const Color _ring = Color(0xFFC48FA5); // 大头像描边
  static const Color _statIcon = Color(0xFFB98CA0); // 属性图标
  static const Color _statText = Color(0xFF5C4A50); // 属性文字

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetState>().selectedPet;
    final name =
        (pet?.nickname.isNotEmpty == true) ? pet!.nickname : '超级神虎';
    final head = pet?.headimg ?? '';

    ImageProvider avatarImg(String h) => h.isNotEmpty
        ? NetworkImage(h)
        : const AssetImage('assets/images/group-1.png');

    // 静态大头像（带粉色描边）+ 右下角相机角标（carme-ico.png，更换头像入口）
    Widget bigAvatar(String h) => Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _ring, width: 2),
              ),
              child: CircleAvatar(backgroundImage: avatarImg(h)),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Image.asset('assets/images/icon/carme-ico.png',
                  width: 26, height: 26),
            ),
          ],
        );

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
                bigAvatar(head),
                const SizedBox(height: 8),
                // 名字（详情页不切换宠物，无右箭头）
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PetDetailPage._ink)),
                const SizedBox(height: 4),
                Text('和$name的第108天',
                    style: const TextStyle(
                        fontSize: 13, color: PetDetailPage._sub)),
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
                Expanded(child: _PersonaTile(data: _personas[0])),
                const SizedBox(width: 10),
                Expanded(child: _PersonaTile(data: _personas[1])),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _PersonaTile(data: _personas[2])),
                const SizedBox(width: 10),
                Expanded(child: _PersonaTile(data: _personas[3])),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 通栏标签
          _PersonaTile(data: _personas[4]),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
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
              GestureDetector(
                onTap: () {}, // TODO: 编辑资料
                behavior: HitTestBehavior.opaque,
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
            Row(
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
