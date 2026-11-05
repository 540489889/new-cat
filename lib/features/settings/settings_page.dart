import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

/// 「我的」页：演示主题切换与信息展示。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const List<_ThemeOption> _themeOptions = [
    _ThemeOption(
      mode: ThemeMode.system,
      label: '跟随系统',
      hint: '自动',
      icon: TIcons.brightness,
    ),
    _ThemeOption(
      mode: ThemeMode.light,
      label: '浅色模式',
      hint: 'Light',
      icon: TIcons.sunny,
    ),
    _ThemeOption(
      mode: ThemeMode.dark,
      label: '深色模式',
      hint: 'Dark',
      icon: TIcons.moon,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    final controller = AppThemeScope.of(context);

    return AppPage(
      title: '我的',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeader(),
          SizedBox(height: token.spacer3),
          SectionCard(
            title: '外观',
            subtitle: '切换后立即生效，所有 TDesign 组件同步换肤',
            padding: EdgeInsets.zero,
            child: TCellGroup(
              cells: [
                for (final option in _themeOptions)
                  TCell(
                    prefix: Icon(
                      option.icon,
                      color: controller.mode == option.mode
                          ? token.brandColor
                          : token.textColorSecondary,
                    ),
                    title: Text(option.label),
                    note: Text(option.hint),
                    trailing: controller.mode == option.mode
                        ? Icon(TIcons.check, color: token.brandColor)
                        : null,
                    onTap: () {
                      controller.setMode(option.mode);
                      TToast.showText(
                        '已切换为${option.label}',
                        context: context,
                      );
                    },
                  ),
              ],
            ),
          ),
          SectionCard(
            title: '主题 Token',
            subtitle: '颜色来自 TDesign 设计变量，可整体替换',
            child: Wrap(
              spacing: token.spacer,
              runSpacing: token.spacer,
              children: [
                _TokenChip(label: 'brandColor', color: token.brandColor),
                _TokenChip(
                  label: 'textColorPrimary',
                  color: token.textColorPrimary,
                ),
                _TokenChip(
                  label: 'bgColorPage',
                  color: token.bgColorPage,
                ),
                _TokenChip(
                  label: 'componentBorder',
                  color: token.componentBorder,
                ),
              ],
            ),
          ),
          SectionCard(
            title: '关于',
            padding: EdgeInsets.zero,
            child: TCellGroup(
              cells: [
                TCell(
                  prefix: Icon(TIcons.app, color: token.brandColor),
                  title: const Text('组件速览'),
                  note: const Text('TDesign 示例'),
                  arrow: true,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.components),
                ),
                const TCell(
                  title: Text('应用版本'),
                  note: Text('v1.0.0'),
                ),
                const TCell(
                  title: Text('TDesign Flutter'),
                  note: Text('v1.1.0'),
                ),
                TCell(
                  title: const Text('开源协议'),
                  note: const Text('MIT'),
                  arrow: true,
                  onTap: () => TToast.showText(
                    'TDesign Flutter 遵循 MIT 协议',
                    context: context,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              'Flutter + TDesign 基础工程模板',
              style: TextStyle(
                color: token.textColorPlaceholder,
                fontSize: token.fontBodySmall?.size ?? 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return Row(
      children: [
        const TAvatar(
          size: TAvatarSize.large,
          child: Text(
            'F',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(width: token.spacer2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New F Cat',
                style: TextStyle(
                  color: token.textColorPrimary,
                  fontSize: token.fontTitleLarge?.size ?? 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: token.spacer / 4),
              Text(
                '脚手架已就绪，开始写业务页面吧',
                style: TextStyle(
                  color: token.textColorPlaceholder,
                  fontSize: token.fontBodySmall?.size ?? 12,
                ),
              ),
            ],
          ),
        ),
        const TTag(
          '模板',
          colorPreset: TTagColorPreset.primary,
          variant: TTagVariant.light,
        ),
      ],
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: token.bgColorPage,
        borderRadius: BorderRadius.circular(token.radiusLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: token.componentBorder),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: token.textColorSecondary,
              fontSize: token.fontBodySmall?.size ?? 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption {
  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final ThemeMode mode;
  final String label;
  final String hint;
  final IconData icon;
}
