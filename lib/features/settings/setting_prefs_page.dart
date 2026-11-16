import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 设置页（参考 f-cat 资料页的设置能力）：
/// - 外观模式：浅色 / 深色 / 跟随系统（写入 ThemeController，已持久化）；
/// - 退出登录：弹窗确认后调用 AuthService.logout，
///   AuthGate 监听登录态自动切回登录页，无需手动跳转。
class SettingPrefsPage extends StatelessWidget {
  const SettingPrefsPage({super.key});

  // 与「我的」页一致的设计稿色板
  static const Color _bg = Color(0xFFF7F2ED); // 页面暖米底
  static const Color _ink = Color(0xFF3D2E33); // 主文字
  static const Color _sub = Color(0xFFA89EA2); // 次要文字
  static const Color _brand = Color(0xFF7F6370); // 品牌紫
  static const Color _red = Color(0xFFE05A5A); // 退出登录红
  static const Color _divider = Color(0x66F1EAE4); // 细分隔线

  @override
  Widget build(BuildContext context) {
    // AppThemeScope 是 InheritedNotifier：mode 变化时本页自动重建刷新勾选态
    final theme = AppThemeScope.of(context);
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('设置'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            const _SectionLabel('外观'),
            _Card(
              child: Column(
                children: [
                  _OptionRow(
                    label: '跟随系统',
                    selected: theme.mode == ThemeMode.system,
                    onTap: () => theme.setMode(ThemeMode.system),
                  ),
                  Container(height: 1, color: _divider),
                  _OptionRow(
                    label: '浅色模式',
                    selected: theme.mode == ThemeMode.light,
                    onTap: () => theme.setMode(ThemeMode.light),
                  ),
                  Container(height: 1, color: _divider),
                  _OptionRow(
                    label: '深色模式',
                    selected: theme.mode == ThemeMode.dark,
                    onTap: () => theme.setMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 退出登录：白卡红字行（参考 f-cat user_profile 的退出登录样式）
            _Card(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _confirmLogout(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: _red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('退出登录',
                            style: TextStyle(fontSize: 15, color: _red)),
                      ),
                      Icon(Icons.chevron_right,
                          size: 16, color: SettingPrefsPage._sub),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 退出登录确认弹窗：复用通用确认弹窗（白底圆角 + 双胶囊按钮）。
  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: '退出登录',
      content: '确定要退出当前账号吗？',
      confirmText: '退出登录',
    );
    if (ok) {
      // 登出会同步 notifyListeners，AuthGate 随之切回登录页；
      // 本页面随 MainShell 一起被替换，故这里不做任何 Navigator 跳转。
      await AuthService.instance.logout();
    }
  }
}

/// 分组标题
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              color: SettingPrefsPage._sub,
              fontWeight: FontWeight.w600)),
    );
  }
}

/// 白色圆角卡片
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// 单选行：label + 当前选中项右侧打勾（品牌紫）
class _OptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: SettingPrefsPage._ink)),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 20, color: SettingPrefsPage._brand),
          ],
        ),
      ),
    );
  }
}
