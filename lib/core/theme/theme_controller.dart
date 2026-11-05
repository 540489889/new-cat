import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 明暗模式控制器。
///
/// 只保存内存态，需要持久化时在这里接入 shared_preferences 即可。
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
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
