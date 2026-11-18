import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:wechat_bridge/wechat_bridge.dart';

import 'app.dart';
import 'core/auth/auth_gate.dart';
import 'core/auth/auth_service.dart';

/// 微信开放平台 AppID（对齐参考项目 f-cat）。
const String _wechatAppId = 'wxcf5ef326f4119c89';

/// iOS Universal Link（微信开放平台里登记的一致）。
const String _wechatUniversalLink = 'https://app.jolipaw.pet/jolipaw/';

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

  // 微信 SDK：Web 不支持，移动端注册并接授权回调
  if (!kIsWeb) {
    _setupWechat();
  }

  runApp(const App());
}

void _setupWechat() {
  WechatBridgePlatform.instance.registerApp(
    appId: _wechatAppId,
    universalLink: _wechatUniversalLink,
  );

  // Android 的 WXEntryActivity 通过 MethodChannel 把授权 code 抛回 Flutter
  const MethodChannel('com.flttercat/wechat').setMethodCallHandler((call) async {
    if (call.method == 'onWechatAuthCode') {
      final code = call.arguments as String?;
      if (code != null && code.isNotEmpty) {
        dispatchWechatCode(code);
      }
    }
    return null;
  });

  // iOS/Android 通用：插件自身收到的授权响应
  WechatBridgePlatform.instance.respStream().listen((resp) {
    if (resp is WechatAuthResp && resp.isSuccessful && resp.code != null) {
      dispatchWechatCode(resp.code!);
    }
  });
}
