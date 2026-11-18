import 'package:flutter_test/flutter_test.dart';
import 'package:new_f_cat/app.dart';
import 'package:new_f_cat/core/auth/auth_service.dart';
import 'package:new_f_cat/core/theme/app_theme.dart';
import 'package:new_f_cat/shared/layouts/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

void main() {
  setUp(() async {
    // 为 shared_preferences 提供内存桩，避免测试环境缺少原生实现抛 MissingPlugin
    SharedPreferences.setMockInitialValues({});
    // AuthService 是单例，跨测试重置登录态；
    // logout 内部有异步清理，必须 await，否则下个用例可能仍处于登录态
    await AuthService.instance.logout();
  });

  test('浅色 / 深色主题 Token 可构建', () {
    expect(AppTheme.light.extension<TThemeData>(), isNotNull);
    expect(AppTheme.dark.extension<TThemeData>(), isNotNull);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  /// 直接走 AuthService 落地登录态（等价于一键登录 token 换登录态成功后的
  /// apply 步骤），避免真机 AliAuth 插件 / 网络请求干扰 UI 测试。
  Future<void> loginForTest() async {
    await AuthService.instance.applyMobileAuthLogin(LoginResult.ok(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      expiresIn: 1800,
    ));
  }

  testWidgets('未登录先进入登录页，登录后进入首页', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    // 未登录：展示验证码登录页 + 底部第三方图标，无主框架。
    // 一键登录图标依赖真机 SIM 检测，测试环境无原生插件故不显示，这里只断言常驻的微信入口。
    expect(find.text('验证码登录'), findsOneWidget);
    expect(find.text('微信登录'), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);

    await loginForTest();
    await tester.pumpAndSettle();

    // 登录成功：进入主框架
    expect(find.byType(MainShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部 Tab 可以切换', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    await loginForTest();
    await tester.pumpAndSettle();

    // 健康 tab
    await tester.tap(find.text('健康'));
    await tester.pumpAndSettle();
    expect(find.text('本周整体稳定，状态良好～'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 我的 tab（用户中心页）
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('我的设备'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
