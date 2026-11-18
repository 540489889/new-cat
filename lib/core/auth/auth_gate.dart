import 'package:flutter/material.dart';

import '../../features/login/login_page.dart';
import '../../shared/layouts/main_shell.dart';
import 'auth_service.dart';

/// 微信授权回调（由 main.dart 的原生 MethodChannel / wechat_bridge 响应流写入，
/// 登录页在 initState 里注册具体处理函数）。
void Function(String code)? globalWechatCallback;

/// 冷启动时 APP 被微信授权结果拉起，回调可能早于登录页 initState 到达；
/// 此时 globalWechatCallback 仍为 null，先把 code 暂存，待登录页注册后立即补发，
/// 避免授权成功回到 APP 却"无反应"。
String? _pendingWechatCode;

/// main.dart 收到微信 code 时统一走这里：登录页已就绪则直接处理，否则暂存。
void dispatchWechatCode(String code) {
  if (code.isEmpty) return;
  final cb = globalWechatCallback;
  if (cb != null) {
    cb(code);
  } else {
    _pendingWechatCode = code;
  }
}

/// 登录页 initState 注册回调；若之前有暂存的 code，注册后立即补发。
void registerWechatCallback(void Function(String code) cb) {
  globalWechatCallback = cb;
  final pending = _pendingWechatCode;
  if (pending != null) {
    _pendingWechatCode = null;
    cb(pending);
  }
}

/// 登录页 dispose 或登录成功后调用：清空回调，并丢弃残留的暂存 code。
void unregisterWechatCallback() {
  globalWechatCallback = null;
  _pendingWechatCode = null;
}

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
