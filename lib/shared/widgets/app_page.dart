import 'package:tdesign_flutter/tdesign_flutter.dart';

import 'status_bar_style.dart';

/// 页面脚手架：统一导航栏、页面背景与滚动行为。
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.body,
    this.title = '',
    this.actions,
    this.showBack = false,
    this.padded = true,
    this.showNavBar = true,
    this.floatingWidget,
    this.bottomNavigationBar,
  });

  final String title;
  final Widget body;
  final List<TNavBarItem>? actions;

  /// 是否展示默认返回按钮（二级页面）。
  final bool showBack;

  /// 是否给内容加页面内边距与滚动。
  final bool padded;

  /// 是否展示顶部导航栏（首页这类沉浸式页面可关闭）。
  final bool showNavBar;

  /// 悬浮在滚动内容之上的组件（如首页底部输入栏）。
  final Widget? floatingWidget;

  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;

    Widget content = padded
        ? SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              token.spacer2,
              token.spacer,
              token.spacer2,
              floatingWidget != null ? 120 : token.spacer3,
            ),
            child: body,
          )
        : body;

    if (floatingWidget != null) {
      content = Stack(
        children: [
          content,
          Positioned(
            left: token.spacer2,
            right: token.spacer2,
            bottom: token.spacer2,
            child: floatingWidget!,
          ),
        ],
      );
    }

    if (!showNavBar) {
      content = SafeArea(child: content);
    }

    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: token.bgColorPage,
        appBar: showNavBar
            ? TNavBar(
                title: Text(title),
                useDefaultBack: showBack,
                useSafeArea: true,
                actions: actions,
              )
            : null,
        body: content,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
