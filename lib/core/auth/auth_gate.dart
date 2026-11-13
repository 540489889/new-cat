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
            return AuthService.instance.loggedIn
                ? const MainShell()
                : const LoginPage();
          },
        );
      },
    );
  }
}
