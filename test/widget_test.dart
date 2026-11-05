import 'package:flutter_test/flutter_test.dart';
import 'package:new_f_cat/app.dart';
import 'package:new_f_cat/core/auth/auth_service.dart';
import 'package:new_f_cat/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

void main() {
  setUp(() {
    // 为 shared_preferences 提供内存桩，避免测试环境缺少原生实现抛 MissingPlugin
    SharedPreferences.setMockInitialValues({});
    // AuthService 是单例，跨测试重置登录态
    AuthService.instance.logout();
  });

  test('浅色 / 深色主题 Token 可构建', () {
    expect(AppTheme.light.extension<TThemeData>(), isNotNull);
    expect(AppTheme.dark.extension<TThemeData>(), isNotNull);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  Future<void> loginThroughOneClick(WidgetTester tester) async {
    await tester.pumpWidget(const App());
    // 能力探测页有转圈动画，pumpAndSettle 可推进至探测完成（mock 600ms）
    await tester.pumpAndSettle();

    // 勾选协议后一键登录
    await tester.tap(find.byKey(const ValueKey('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.text('本机号码一键登录'));
    // mock 登录延时是纯 Timer，无帧调度，需显式推进时钟
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  }

  testWidgets('未登录先进入一键登录页，登录后进入首页', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    // 未登录：展示一键登录页（支持一键登录的机型默认态）
    expect(find.text('本机号码一键登录'), findsOneWidget);
    expect(find.byType(TTabBar), findsNothing);

    await loginThroughOneClick(tester);

    // 登录成功：进入主框架
    expect(find.byType(TTabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部 Tab 可以切换', (WidgetTester tester) async {
    await loginThroughOneClick(tester);

    final tabBar = find.byType(TTabBar);

    await tester.tap(
      find.descendant(of: tabBar, matching: find.text('日志')),
    );
    await tester.pumpAndSettle();
    expect(find.text('自动喂食完成'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(of: tabBar, matching: find.text('我的')),
    );
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
