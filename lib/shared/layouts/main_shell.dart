import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../features/health/health_page.dart';
import '../../features/home/home_page.dart';
import '../../features/pet/pet_page.dart';
import '../../features/settings/settings_page.dart';
import '../widgets/status_bar_style.dart';

/// 主框架：底部 iOS App Store 风格毛玻璃悬浮 TabBar + IndexedStack 保持页面状态。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    PetPage(),
    HealthPage(),
    SettingsPage(),
  ];

  // 底部 Tab 数据：沿用项目自定义图标（assets/images/icon/tabbar1~4.png）
  static const List<({String label, String icon})> _tabs =
      <({String label, String icon})>[
        (label: '管家', icon: 'assets/images/icon/tabbar1.png'),
        (label: '宠物', icon: 'assets/images/icon/tabbar2.png'),
        (label: '健康', icon: 'assets/images/icon/tabbar3.png'),
        (label: '我的', icon: 'assets/images/icon/tabbar4.png'),
      ];

  // 选中 / 未选中颜色：选中用品牌玫瑰的高亮版（对应 App Store 的选中蓝），
  // 未选中用深灰，保证在通透的玻璃上依然清晰
  static const Color _selectedColor = Color(0xFFB2708A);
  static const Color _unselectedColor = Color(0xFF3C3C43);

  /// 胶囊高度：圆角取其一半，得到完全圆润的两端。
  static const double _barHeight = 54;

  /// 选中块相对外框的内缩量（四周留出玻璃厚度）。
  static const double _tabInset = 4;

  /// 选中块圆角 = 外框圆角 − 内缩量，与外框同心，
  /// 两端弧线跟 TabBar 内侧轮廓平行，不再是一块自己独立的椭圆。
  static const double _tabRadius = _barHeight / 2 - _tabInset;

  @override
  Widget build(BuildContext context) {
    // 底部悬浮胶囊间距：iPhone 安全区（Home Indicator 约 34px）全部留出会显得
    // 间距过大，这里只保留少量间隙让胶囊贴近屏幕底部；无安全区的设备保留 12px。
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomGap = bottomInset > 0
        ? (bottomInset - 24).clamp(6.0, 20.0)
        : 12.0;

    final radius = BorderRadius.circular(_barHeight / 2);

    return StatusBarStyle(
      child: Scaffold(
        // 让页面内容延伸到悬浮胶囊下方，毛玻璃才能透出背后滚动的内容
        extendBody: true,
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: Padding(
          // iOS 风格：胶囊左右留边、贴底部悬浮
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomGap,
          ),
          child: DecoratedBox(
            // 阴影放在裁剪层之外，避免被 ClipRRect 切掉
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [
                // 通透的玻璃配轻阴影，避免又变成一块实心白板
                BoxShadow(
                  color: Color(0x0F3D2E33),
                  blurRadius: 26,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                // 强模糊 + 轻微提饱和：背后内容化成柔和的色块，而不是还能认出字
                filter: ImageFilter.compose(
                  outer: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                  inner: const ColorFilter.matrix(<double>[
                    1.15, 0, 0, 0, 0, //
                    0, 1.15, 0, 0, 0, //
                    0, 0, 1.15, 0, 0, //
                    0, 0, 0, 1, 0, //
                  ]),
                ),
                child: Container(
                  height: _barHeight,
                  decoration: BoxDecoration(
                    // 低不透明度白：玻璃要透，内容才能透出来
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: radius,
                    // 一道细亮边，勾出玻璃的边界
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      for (int i = 0; i < _tabs.length; i++) _buildTabItem(i),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 单个 Tab：图标在上、文字在下；选中项除了换色，还垫一层淡淡的黑色透明
  /// 圆角块（浅色玻璃上更沉一点，边界更清楚），未选中完全透明。
  Widget _buildTabItem(int index) {
    final active = index == _currentIndex;
    final color = active ? _selectedColor : _unselectedColor;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Padding(
          padding: const EdgeInsets.all(_tabInset),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              // 淡黑渐变：上略深、下略浅，像玻璃上压出的一块凹槽
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: active ? 0.09 : 0.0),
                  Colors.black.withValues(alpha: active ? 0.06 : 0.0),
                ],
              ),
              borderRadius: BorderRadius.circular(_tabRadius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  _tabs[index].icon,
                  width: 22,
                  height: 22,
                  // 单色图标按选中状态整体着色
                  color: color,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(height: 2),
                Text(
                  _tabs[index].label,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
