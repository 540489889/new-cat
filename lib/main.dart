import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import 'app.dart';
import 'core/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 必须 await：确保首帧渲染前登录态已从本地恢复，避免闪登录页
  await AuthService.restore();
  // media_kit 需要在使用 Player 前初始化；测试或不支持的平台静默忽略
  try {
    MediaKit.ensureInitialized();
  } catch (_) {
    // ignore
  }
  // 内容延伸到系统栏后面，状态栏保持透明，由 StatusBarStyle 控制图标颜色
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const App());
}
