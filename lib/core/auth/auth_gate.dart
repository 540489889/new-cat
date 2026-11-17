import 'package:flutter/material.dart';

import '../../features/login/login_page.dart';
import '../../shared/layouts/main_shell.dart';
import 'auth_service.dart';

/// 登录门：等待本地登录态恢复完成后，再决定展示登录页还是主框架。
///
/// 参考 f-cat 的 AuthGate：恢复是异步的，首帧必须先展示等待态，
/// 否则会在恢复完成前把登录页渲染出来且不再重建。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _restore = AuthService.restore();

  /// 上一次构建时的登录态，用于检测登出瞬间。
  bool? _wasLoggedIn;

  /// 避免一帧内多次 notify 导致重复清空导航栈。
  bool _resetPending = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // 恢复期间的静态启动占位：避免闪登录页/黑屏；
          // 刻意不用转圈动画，否则 pumpAndSettle 等不到稳定帧。
          return const Scaffold(
            backgroundColor: Colors.white,
            body: SizedBox.expand(),
          );
        }
        return AnimatedBuilder(
          animation: AuthService.instance,
          builder: (context, _) {
            final loggedIn = AuthService.instance.loggedIn;
            // 从「已登录」变成「未登录」时，必须把 push 出来的二级页面
            // （设置/资料页等）从导航栈里清掉。仅切换根 widget 不会清空
            // Navigator 栈，否则登录页被旧页面盖住，表现为「退出后没反应」。
            if (_wasLoggedIn == true && !loggedIn && !_resetPending) {
              _resetPending = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _resetPending = false;
                // 只 pop 掉上面的二级页面，保留当前根路由：
                // 若用 pushNamedAndRemoveUntil(root) 重建 AuthGate，会重新
                // restore 登录态；而 logout 清本地缓存是异步的，慢设备上可能
                // 读到尚未清掉的 token 又跳回主页面。
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            }
            _wasLoggedIn = loggedIn;
            return loggedIn ? const MainShell() : const LoginPage();
          },
        );
      },
    );
  }
}
