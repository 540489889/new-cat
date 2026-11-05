import 'package:flutter/services.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 状态栏样式：透明背景 + 跟随当前明暗主题的图标颜色。
///
/// 工程里没有使用 Material AppBar（它默认会注入 SystemUiOverlayStyle），
/// 必须自己声明，否则状态栏会落到 Activity 主题的默认样式上，
/// 在部分机型上表现为一层灰色蒙层。
class StatusBarStyle extends StatelessWidget {
  const StatusBarStyle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final darkIcons = brightness != Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: darkIcons ? Brightness.dark : Brightness.light,
        // iOS 上与 Android 的取值方向相反
        statusBarBrightness: darkIcons ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}
