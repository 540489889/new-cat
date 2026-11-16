import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 明暗模式控制器。
///
/// 内存态 + 本地持久化：选择立即生效并写入 SharedPreferences，
/// 冷启动时由 [App] 在 initState 里调用 [restore] 恢复上次选择。
class ThemeController extends ChangeNotifier {
  static const String _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// 从本地恢复上次选择的外观模式（未保存或解析失败时保持跟随系统）。
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restored = switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (restored != null && restored != _mode) {
        _mode = restored;
        notifyListeners();
      }
    } catch (_) {
      // 插件不可用（如测试环境）时保持默认
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // 插件不可用时仅保留内存态
    }
  }
}

/// 把 [ThemeController] 注入 Widget 树，业务侧通过 `AppThemeScope.of(context)` 读取。
class AppThemeScope extends InheritedNotifier<ThemeController> {
  const AppThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope 需包裹在 MaterialApp 之上');
    return scope!.notifier!;
  }
}
