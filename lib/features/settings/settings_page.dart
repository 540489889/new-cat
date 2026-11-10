import 'package:flutter/material.dart';

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
  static const Color _iconBg = Color(0xFFF3E9EF); // 图标圆底
  static const Color _cardBg = Color(0xFFF7F5F0); // 浅暖白（设备图底/图标底）
  static const Color _divider = Color(0xFFF1EAE4); // 细分隔线
  static const Color _goodBg = Color(0xFFE7F2E7); // 绿标签底
  static const Color _goodInk = Color(0xFF4E9B58); // 绿标签字
  static const Color _warnBg = Color(0xFFFBEEE0); // 橙标签底
  static const Color _warnInk = Color(0xFFD98E3B); // 橙标签字
  static const Color _redBg = Color(0xFFFBE5E5); // 红标签底
  static const Color _redInk = Color(0xFFE05A5A); // 红标签字

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // extendBody 下 padding.bottom 已含底部胶囊 TabBar 高度，再留少量间距
    final bottomPad = bottomInset + 24.0;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // 顶部右上角浅色同心圆装饰（与宠物页档案卡装饰风格一致）
          const Positioned(top: -80, right: -60, child: _DecoRings()),
          SingleChildScrollView(
            padding: EdgeInsets.only(top: topInset, bottom: bottomPad),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部右侧设置入口
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {}, // TODO: 跳转设置页
                  child: const Icon(Icons.settings_outlined,
                      size: 22, color: _ink),
                ),
              ),
            ),
            const _ProfileHeader(),
            // 会员权益：直接使用设计稿图片（icon/u-member.png，图片自带四周间距，故上下不再额外加间距）
            Image.asset('assets/images/icon/u-member.png',
                width: double.infinity, fit: BoxFit.fitWidth),
            const _ShopCard(),
            const SizedBox(height: 12),
            const _DeviceCard(),
            const SizedBox(height: 12),
            const _FamilyCard(),
            const SizedBox(height: 12),
            const _GeneralList(),
          ],
        ),
        ),
        ],
      ),
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

/// 用户信息：圆头像 + 昵称 + 手机号，右侧箭头
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 20, 0),
      child: Row(
        children: [
          // 头像（本地猫图占位，接入用户中心后替换为真实头像）
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SettingsPage._iconBg,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/images/group-1.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('赵德柱呀',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: SettingsPage._ink)),
                SizedBox(height: 4),
                Text('182 **** 3210',
                    style: TextStyle(
                        fontSize: 12, color: SettingsPage._sub)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: SettingsPage._sub),
        ],
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

/// 商城入口：图标 + 标题 + 右侧说明
class _ShopCard extends StatelessWidget {
  const _ShopCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          const _IconBox(asset: 'assets/images/icon/m-d2.png'),
          const SizedBox(width: 12),
          const Text('商城',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SettingsPage._ink)),
          const Spacer(),
          const Text('购买智能设备，解锁更多功能',
              style: TextStyle(fontSize: 11, color: SettingsPage._sub)),
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

/// 家庭成员入口
class _FamilyCard extends StatelessWidget {
  const _FamilyCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
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
          const Text('1 个关联账号',
              style: TextStyle(fontSize: 11, color: SettingsPage._sub)),
          const Icon(Icons.chevron_right, size: 16, color: SettingsPage._sub),
        ],
      ),
    );
  }
}

/// 通用列表：客服 / 投诉建议 / 检查更新 / 关于我们
class _GeneralList extends StatelessWidget {
  const _GeneralList();

  @override
  Widget build(BuildContext context) {
    Widget row(String asset, String title, {String? note}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _IconBox(asset: asset, size: 36),
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
      );
    }

    return _Card(
      child: Column(
        children: [
          row('assets/images/icon/m-d1.png', '客服'),
          Container(height: 1, color: SettingsPage._divider),
          row('assets/images/icon/m-d6.png', '投诉建议'),
          Container(height: 1, color: SettingsPage._divider),
          row('assets/images/icon/m-d4.png', '检查更新'),
          Container(height: 1, color: SettingsPage._divider),
          row('assets/images/icon/m-d5.png', '关于我们', note: '最新版本'),
        ],
      ),
    );
  }
}
