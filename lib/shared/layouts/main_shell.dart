import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../features/home/home_page.dart';
import '../../features/log/log_page.dart';
import '../../features/pet/pet_page.dart';
import '../../features/settings/settings_page.dart';
import '../widgets/status_bar_style.dart';

/// 主框架：底部 TDesign TabBar + IndexedStack 保持页面状态。
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
    LogPage(),
    SettingsPage(),
  ];

  // 使用项目自定义图标（assets/images/icon/tabbar1~4.png）；
  // Image.asset 非 const 构造，故列表改为 final
  static final List<TTabBarItemConfig> _tabs = <TTabBarItemConfig>[
    TTabBarItemConfig(
      tabText: '管家',
      unselectedIcon:
          Image.asset('assets/images/icon/tabbar1.png', width: 22, height: 22),
      selectedIcon:
          Image.asset('assets/images/icon/tabbar1.png', width: 22, height: 22),
    ),
    TTabBarItemConfig(
      tabText: '宠物',
      unselectedIcon:
          Image.asset('assets/images/icon/tabbar2.png', width: 22, height: 22),
      selectedIcon:
          Image.asset('assets/images/icon/tabbar2.png', width: 22, height: 22),
    ),
    TTabBarItemConfig(
      tabText: '健康',
      unselectedIcon:
          Image.asset('assets/images/icon/tabbar3.png', width: 22, height: 22),
      selectedIcon:
          Image.asset('assets/images/icon/tabbar3.png', width: 22, height: 22),
    ),
    TTabBarItemConfig(
      tabText: '我的',
      unselectedIcon:
          Image.asset('assets/images/icon/tabbar4.png', width: 22, height: 22),
      selectedIcon:
          Image.asset('assets/images/icon/tabbar4.png', width: 22, height: 22),
    ),
  ];

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
            // 让胶囊整体离底部留间距，呈现悬浮感
            padding: const EdgeInsets.only(bottom: 12),
            child: TTabBar(
              type: TTabBarType.iconText,
              // 悬浮胶囊样式：圆角胶囊 + 外边距 + 阴影，浮于内容之上
              style: TTabBarStyle.capsule,
              // 关闭内置安全区底色条，避免胶囊外再套一层整宽背景
              useSafeArea: false,
              value: _currentIndex,
              navigationTabs: _tabs,
              onChanged: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ),
      ),
    );
  }
}
