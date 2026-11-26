import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/family/family_state.dart';
import '../../core/router/app_router.dart';
import '../../core/user/user_state.dart';

/// 「我的」页：按设计稿 1:1 还原。
/// 结构：设置入口 → 用户信息 → 会员权益横幅 → 商城 → 我的设备 → 家庭成员 → 通用列表。
/// 数据当前为本地 mock，接入后端后替换即可。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // 与健康页一致的设计稿色板
  static const Color _bg = Color(0xFFF7F2ED); // 页面暖米底
  static const Color _ink = Color(0xFF3D2E33); // 主文字
  static const Color _sub = Color(0xFFA89EA2); // 次要文字
  static const Color _brand = Color(0xFF7F6370); // 品牌紫
  static const Color _cardBg = Color(0xFFF7F5F0); // 浅暖白（设备图底/图标底）
  static const Color _divider = Color(0x66F1EAE4); // 细分隔线（与今日状态统一：同色 40% 不透明度）
  static const Color _goodBg = Color(0xFFE7F2E7); // 绿标签底
  static const Color _goodInk = Color(0xFF4E9B58); // 绿标签字
  static const Color _warnBg = Color(0xFFFBEEE0); // 橙标签底
  static const Color _warnInk = Color(0xFFD98E3B); // 橙标签字
  static const Color _redBg = Color(0xFFFBE5E5); // 红标签底
  static const Color _redInk = Color(0xFFE05A5A); // 红标签字

  /// 收起后紧凑栏的高度（不含状态栏）
  static const double _compactBarHeight = 56;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // extendBody 下 padding.bottom 已含底部胶囊 TabBar 高度，再留少量间距
    final bottomPad = bottomInset + 24.0;

    // 展开态高度 = 状态栏 + 图标行 + 用户信息 + 8 + 横幅 + 12
    final width = MediaQuery.sizeOf(context).width;
    final textScaler = MediaQuery.textScalerOf(context);
    // 行高按 1.4 估算并取 max，宁可高估（多出空白）也不要低估（Column 溢出）
    final textBlock =
        textScaler.scale(17) * 1.4 + 4 + textScaler.scale(12) * 1.4;
    final profileHeight = 20 + math.max(72.0, textBlock);
    final bannerHeight = width * 222 / 1206; // 已裁掉上下阴影留白的卡片高度
    final maxExtent = topInset + 31 + profileHeight + 8 + bannerHeight + 12;
    final minExtent = topInset + _compactBarHeight;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // 顶部右上角浅色同心圆装饰（会透过头部毛玻璃）
          const Positioned(top: -80, right: -60, child: _DecoRings()),
          CustomScrollView(
            slivers: [
              // 折叠式头部：滚动时横幅/用户信息淡出，只剩一条紧凑栏吸顶
              SliverPersistentHeader(
                pinned: true,
                delegate: _CollapsingHeaderDelegate(
                  topInset: topInset,
                  minExtent: minExtent,
                  maxExtent: maxExtent,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomPad),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(const [
                    _ShopCard(),
                    SizedBox(height: 12),
                    _DeviceCard(),
                    SizedBox(height: 12),
                    _FamilyCard(),
                    SizedBox(height: 12),
                    _GeneralList(),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 折叠式头部 delegate。
///
/// - 展开态（maxExtent）：图标行 + 用户信息 + 会员权益横幅 + 12 间距；
/// - 收起态（minExtent）：一条紧凑栏（小头像 + 昵称 + 图标），吸顶常驻。
/// 两端之间用透明度交叉过渡，避免高度突变造成的割裂感。
class _CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingHeaderDelegate({
    required this.topInset,
    required this.minExtent,
    required this.maxExtent,
  });

  final double topInset;

  @override
  final double maxExtent;

  @override
  final double minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final t = (shrinkOffset / range).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 毛玻璃底：展开时更透（顶部装饰柔和透出），收起后稍实保证文字可读
          IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      SettingsPage._bg.withValues(alpha: 0.80 + 0.12 * t),
                      SettingsPage._bg.withValues(alpha: 0.72 + 0.16 * t),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 展开态内容：随折叠淡出（被 ClipRect 从底部裁掉）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: (1 - t * 1.6).clamp(0.0, 1.0),
              // 直接放 Column：Positioned 只给 top/left/right 时高度不受限，
              // 内容保持完整高度、随头部收缩被外层 ClipRect 从底部裁掉。
              child: Column(
                children: [
                  SizedBox(height: topInset),
                  // 顶部右侧：消息铃铛 + 设置入口
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              Navigator.of(context).pushNamed(AppRoutes.news),
                          child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 23,
                              color: SettingsPage._ink),
                        ),
                        const SizedBox(width: 18),
                        GestureDetector(
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.settings),
                          child: const Icon(Icons.settings_outlined,
                              size: 22, color: SettingsPage._ink),
                        ),
                      ],
                    ),
                  ),
                  const _ProfileHeader(),
                  const SizedBox(height: 8),
                  const _MemberBanner(),
                  // 与卡片间距一致的 12
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // 收起态紧凑栏：后半程淡入
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: ((t - 0.35) / 0.65).clamp(0.0, 1.0),
              child: _CompactHeaderBar(
                topInset: topInset,
                height: minExtent - topInset,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingHeaderDelegate oldDelegate) =>
      oldDelegate.maxExtent != maxExtent ||
      oldDelegate.minExtent != minExtent ||
      oldDelegate.topInset != topInset;
}

/// 收起后吸顶的紧凑栏：小头像 + 昵称 + 消息/设置入口
class _CompactHeaderBar extends StatelessWidget {
  const _CompactHeaderBar({required this.topInset, required this.height});

  final double topInset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserState>();
    final avatarUrl = user.avatarUrl;
    return Column(
      children: [
        SizedBox(height: topInset),
        SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Image.asset(
                                'assets/images/group-1.png',
                                fit: BoxFit.cover),
                          )
                        : Image.asset('assets/images/group-1.png',
                            fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SettingsPage._ink,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.news),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.notifications_none_rounded,
                        size: 21, color: SettingsPage._ink),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.settings_outlined,
                        size: 20, color: SettingsPage._ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 白色圆角卡片容器（统一圆角 16、内边距 14）
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// 图标方块：png 资源，无背景（与健康页一致）
class _IconBox extends StatelessWidget {
  final String asset;
  final double size;
  const _IconBox({required this.asset, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(asset, width: size * 0.6, height: size * 0.6),
      ),
    );
  }
}

/// 会员权益横幅。
///
/// `u-member.png` 为 1206×318 的设计稿切图，真正不透明的卡片只占 y=36~257，
/// 上方 36px、下方 60px 都是渐隐阴影 + 透明留白。直接铺满会让它和上下卡片
/// 之间的视觉间距比其它卡片间距大很多，所以这里按宽度等比裁到卡片边缘，
/// 间距统一交给外层 SizedBox 控制。
class _MemberBanner extends StatelessWidget {
  const _MemberBanner();

  static const double _srcWidth = 1206;
  static const double _srcHeight = 318;
  static const double _srcTrimTop = 36; // 上方阴影/透明留白（源图像素）
  static const double _srcTrimBottom = 60; // 下方阴影/透明留白（源图像素）

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final imageHeight = width * _srcHeight / _srcWidth;
        final trimTop = width * _srcTrimTop / _srcWidth;
        final trimBottom = width * _srcTrimBottom / _srcWidth;
        return ClipRect(
          child: SizedBox(
            height: imageHeight - trimTop - trimBottom,
            // OverflowBox：让图片按原始比例（imageHeight）布局，
            // 否则会被 SizedBox 的紧约束压扁（BoxFit.fill 会纵向拉伸变形）
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: width,
              maxWidth: width,
              minHeight: imageHeight,
              maxHeight: imageHeight,
              child: Transform.translate(
                offset: Offset(0, -trimTop),
                child: Image.asset(
                  'assets/images/icon/u-member.png',
                  width: width,
                  height: imageHeight,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 用户信息：圆头像 + 昵称 + 手机号，右侧箭头（点击进入个人资料页）
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    // 登录/资料变更后自动刷新（UserState 由登录响应 memberInfo 与 /app/member/info 驱动）
    final userState = context.watch<UserState>();
    final mobile = userState.maskedMobile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          Navigator.of(context).pushNamed(AppRoutes.userProfile),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 20, 0),
        child: Row(
          children: [
            // 头像：有网络头像用网络图，否则用本地猫图占位
            // 白色边框（白底 + 内间距形成白环）+ 内间距 + 阴影
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A3D2E33),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: userState.avatarUrl != null
                    ? Image.network(
                        userState.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/group-1.png',
                            fit: BoxFit.cover),
                      )
                    : Image.asset('assets/images/group-1.png',
                        fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userState.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: SettingsPage._ink)),
                  const SizedBox(height: 4),
                  Text(mobile.isEmpty ? '未绑定手机号' : mobile,
                      style: const TextStyle(
                          fontSize: 12, color: SettingsPage._sub)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: SettingsPage._sub),
          ],
        ),
      ),
    );
  }
}

/// 浅色同心圆装饰组（与宠物页档案卡四角一致）。
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

/// 商城 / 我的订单入口：同一张白卡内两行，行间分隔线左对齐文字。
class _ShopCard extends StatelessWidget {
  const _ShopCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            context,
            asset: 'assets/images/icon/m-d2.png', // 购物袋 → 商城
            title: '商城',
            note: '购买智能设备，解锁更多功能',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.shop),
          ),
          const SizedBox(height: 12),
          const Padding(
            // 卡片内边距 14 + 图标 40 + 间距 12 = 66，与标题文字左对齐
            padding: EdgeInsets.only(left: 52),
            child: Divider(height: 1, color: SettingsPage._divider),
          ),
          const SizedBox(height: 12),
          _row(
            context,
            asset: 'assets/images/icon/m-d6.png', // 文档列表 → 订单
            title: '我的订单',
            note: '查看订单与物流',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.shopOrderList),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String asset,
    required String title,
    required String note,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          _IconBox(asset: asset),
          const SizedBox(width: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SettingsPage._ink)),
          const Spacer(),
          Text(note,
              style: const TextStyle(
                  fontSize: 11, color: SettingsPage._sub)),
          const Icon(Icons.chevron_right, size: 16, color: SettingsPage._sub),
        ],
      ),
    );
  }
}

/// 我的设备：标题 + 添加设备 + 设备列表（本地 mock）
class _DeviceCard extends StatelessWidget {
  const _DeviceCard();

  @override
  Widget build(BuildContext context) {
    const devices = [
      (
        image: 'assets/images/device/device1.png',
        name: '智能饮水机 PRO',
        tag: ('水量充足', SettingsPage._goodBg, SettingsPage._goodInk),
        online: true,
        battery: '85%',
      ),
      (
        image: 'assets/images/device/device2.png',
        name: '智能喂食器 Mini',
        tag: ('存粮不足', SettingsPage._redBg, SettingsPage._redInk),
        online: true,
        battery: '85%',
      ),
      (
        image: 'assets/images/device/device3.png',
        name: '智能猫砂盆 Smart',
        tag: ('', SettingsPage._goodBg, SettingsPage._goodInk),
        online: false,
        battery: '85%',
      ),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('我的设备',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SettingsPage._ink)),
              const SizedBox(width: 4),
              const Text('3',
                  style: TextStyle(fontSize: 11, color: SettingsPage._sub)),
              const Spacer(),
              // 「+ 添加设备」靠右同行（品牌紫）
              GestureDetector(
                onTap: () {}, // TODO: 添加设备流程
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: SettingsPage._brand),
                    SizedBox(width: 2),
                    Text('添加设备',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SettingsPage._brand)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < devices.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: SettingsPage._divider),
              const SizedBox(height: 12),
            ],
            _DeviceRow(data: devices[i]),
          ],
        ],
      ),
    );
  }
}

/// 设备行：设备图 + 名称/状态标签 + 在线状态与电量
class _DeviceRow extends StatelessWidget {
  final ({
    String image,
    String name,
    (String, Color, Color) tag,
    bool online,
    String battery,
  }) data;

  const _DeviceRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final (tagText, tagBg, tagInk) = data.tag;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 设备图（浅暖白方底）
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: SettingsPage._cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(6),
          child: Image.asset(data.image, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(data.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SettingsPage._ink)),
                  ),
                  if (tagText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(tagText,
                          style: TextStyle(fontSize: 10, color: tagInk)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  // 在线/离线状态胶囊（带状态圆点）
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: data.online
                          ? SettingsPage._goodBg
                          : SettingsPage._warnBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: data.online
                                ? SettingsPage._goodInk
                                : SettingsPage._warnInk,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(data.online ? '在线' : '离线',
                            style: TextStyle(
                                fontSize: 10,
                                color: data.online
                                    ? SettingsPage._goodInk
                                    : SettingsPage._warnInk)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Image.asset('assets/images/icon/m-d7.png',
                      width: 14, height: 14),
                  const SizedBox(width: 2),
                  Text('电量 ${data.battery}',
                      style: const TextStyle(
                          fontSize: 11, color: SettingsPage._sub)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 家庭成员入口：展示当前家庭成员数，点击进入「我的家庭」页。
class _FamilyCard extends StatefulWidget {
  const _FamilyCard();

  @override
  State<_FamilyCard> createState() => _FamilyCardState();
}

class _FamilyCardState extends State<_FamilyCard> {
  Future<void> _open() async {
    await Navigator.of(context).pushNamed(AppRoutes.family);
    // 从家庭页返回后强制同步一次，避免成员/家庭名变更后入口文案滞后
    if (!mounted) return;
    await context.read<FamilyState>().load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyState>();
    // 按需加载：未加载且不在请求中时补一次（登录态变化后也会自动触发）
    if (!family.loaded && !family.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<FamilyState>().load();
      });
    }
    final String note;
    if (!family.loaded) {
      note = '';
    } else if (family.hasFamily) {
      note = '${family.memberCount} 位成员';
    } else {
      note = '未加入';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: _Card(
        child: Row(
          children: [
            const _IconBox(asset: 'assets/images/icon/m-d3.png'),
            const SizedBox(width: 12),
            const Text('家庭成员',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SettingsPage._ink)),
            const Spacer(),
            Text(note,
                style: const TextStyle(
                    fontSize: 11, color: SettingsPage._sub)),
            const Icon(Icons.chevron_right, size: 16, color: SettingsPage._sub),
          ],
        ),
      ),
    );
  }
}

/// 通用列表：客服 / 投诉建议 / 检查更新 / 关于我们
class _GeneralList extends StatelessWidget {
  const _GeneralList();

  @override
  Widget build(BuildContext context) {
    Widget row(Widget leading, String title,
        {String? note, VoidCallback? onTap}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, color: SettingsPage._ink)),
              const Spacer(),
              if (note != null) ...[
                Text(note,
                    style: const TextStyle(
                        fontSize: 11, color: SettingsPage._sub)),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right,
                  size: 16, color: SettingsPage._sub),
            ],
          ),
        ),
      );
    }

    Widget png(String asset) => _IconBox(asset: asset, size: 36);

    Widget icon(IconData data) => SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(data, size: 20, color: SettingsPage._brand),
          ),
        );

    return _Card(
      child: Column(
        children: [
          row(png('assets/images/icon/m-d1.png'), '客服',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.service)),
          Container(height: 1, color: SettingsPage._divider),
          row(png('assets/images/icon/m-d6.png'), '投诉建议',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.feedback)),
          Container(height: 1, color: SettingsPage._divider),
          row(png('assets/images/icon/m-d4.png'), '检查更新',
              note: '最新版本',
              onTap: () => TToast.showSuccess('已是最新版本', context: context)),
          Container(height: 1, color: SettingsPage._divider),
          row(icon(Icons.notifications_active_outlined), '消息设置',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.noticeSettings)),
          Container(height: 1, color: SettingsPage._divider),
          row(png('assets/images/icon/m-d5.png'), '关于我们',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.aboutUs)),
        ],
      ),
    );
  }
}
