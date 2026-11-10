import 'package:flutter/material.dart';

import '../../features/health/health_page.dart';
import '../../features/home/home_page.dart';
import '../../features/pet/pet_page.dart';
import '../../features/settings/settings_page.dart';
import '../widgets/status_bar_style.dart';

/// 主框架：底部毛玻璃悬浮 TabBar + IndexedStack 保持页面状态。
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
  static const List<({String label, String icon})> _tabs = <({String label, String icon})>[
    (label: '管家', icon: 'assets/images/icon/tabbar1.png'),
    (label: '宠物', icon: 'assets/images/icon/tabbar2.png'),
    (label: '健康', icon: 'assets/images/icon/tabbar3.png'),
    (label: '我的', icon: 'assets/images/icon/tabbar4.png'),
  ];

  // 选中/未选中颜色（品牌紫 / 中性灰）
  static const Color _selectedColor = Color(0xFF7F6370);
  static const Color _unselectedColor = Color(0xFF999999);

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        // 让页面内容延伸到悬浮胶囊下方，胶囊左右空隙透出的是页面内容而非纯色背景
        extendBody: true,
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            // 悬浮胶囊：左右 16、离底 12，浮于页面内容之上
            // 仅留底部 12 间隙；左右不内缩 → 磨砂层铺到屏幕边，使左右间隙也磨砂
            // 外层固定 76 高（磨砂带高度），避免 SizedBox.expand 在 bottomNavigationBar
            // 约束下被撑成无限高而遮挡全屏
            // 栏体落到安全区底部、与屏幕底齐平；磨砂带上下内缩留磨砂边
            // 实心胶囊 TabBar：不透明纯白背景 + 阴影遮挡内容，不再做毛玻璃
            // 离底 12 悬浮间距（SafeArea 已处理系统栏，这里只是视觉留白）
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 64, // 栏体实白 + 阴影遮挡，顶部无需内缩
              child: Stack(
                children: [
                  // 左右内缩 20、贴顶（去掉顶部内间距），自身不透明纯白遮挡背后内容
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 0,
                    height: 64,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // 不透明纯白：栏体直接遮挡内容；阴影提供悬浮/分区感
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A3D2E33),
                            blurRadius: 18,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                      children: [
                        for (int i = 0; i < _tabs.length; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _currentIndex = i),
                              // 参考京东金融样式：选中 = 品牌色实心圆底放白色图标 + 品牌色文字；
                              // 未选中 = 原样图标 + 灰字，无底。
                              child: Center(
                                child: i == _currentIndex
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 品牌色实心圆底 + 白色图标（无浅灰背景块）
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _selectedColor,
                                            ),
                                            alignment: Alignment.center,
                                            child: Image.asset(_tabs[i].icon,
                                                width: 18,
                                                height: 18,
                                                color: Colors.white),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _tabs[i].label,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _selectedColor,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 图标区高度与选中的圆底一致，保证选中/未选中文字基线对齐
                                          SizedBox(
                                            height: 34,
                                            child: Center(
                                              child: Image.asset(_tabs[i].icon,
                                                  width: 22, height: 22),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _tabs[i].label,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: _unselectedColor,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
