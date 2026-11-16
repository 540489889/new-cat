import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import 'core/pet/pet_state.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/user/user_state.dart';

/// 应用根节点：挂载主题与路由。
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    // 恢复上次选择的外观模式（设置页可切换并持久化）
    _themeController.restore();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: _themeController,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<PetState>(create: (_) => PetState()),
          // 用户信息全局状态：登录后自动从本地缓存恢复，供个人中心/资料页展示
          ChangeNotifierProvider<UserState>(
            create: (_) => UserState()..checkLoginStatus(),
          ),
        ],
        child: AnimatedBuilder(
          animation: _themeController,
          builder: (context, _) {
            return MaterialApp(
              title: 'New F Cat',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: _themeController.mode,
              initialRoute: AppRoutes.root,
              onGenerateRoute: AppRouter.onGenerateRoute,
            );
          },
        ),
      ),
    );
  }
}
