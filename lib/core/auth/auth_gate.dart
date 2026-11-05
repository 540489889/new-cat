import 'package:flutter/material.dart';

import '../../features/login/login_page.dart';
import '../../shared/layouts/main_shell.dart';
import 'auth_service.dart';

/// 登录门：未登录时展示登录页，登录成功后进入主框架。
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        return AuthService.instance.loggedIn ? const MainShell() : const LoginPage();
      },
    );
  }
}
