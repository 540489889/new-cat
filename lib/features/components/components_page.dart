import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

/// 组件速览：常用 TDesign 组件的用法与主题联动效果。
class ComponentsPage extends StatefulWidget {
  const ComponentsPage({super.key});

  @override
  State<ComponentsPage> createState() => _ComponentsPageState();
}

class _ComponentsPageState extends State<ComponentsPage> {
  bool _switchOn = true;

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return AppPage(
      title: '组件',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: '按钮 TButton',
            subtitle: '变体 / 尺寸 / 禁用态',
            child: Wrap(
              spacing: token.spacer,
              runSpacing: token.spacer,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TButton(
                  child: const Text('填充按钮'),
                  onPressed: () {},
                ),
                TButton(
                  colorPreset: TButtonColorPreset.primary,
                  child: const Text('主要按钮'),
                  onPressed: () {},
                ),
                TButton(
                  variant: TButtonVariant.outline,
                  child: const Text('描边按钮'),
                  onPressed: () {},
                ),
                TButton(
                  variant: TButtonVariant.text,
                  child: const Text('文字按钮'),
                  onPressed: () {},
                ),
                TButton(
                  variant: TButtonVariant.ghost,
                  colorPreset: TButtonColorPreset.primary,
                  child: const Text('幽灵按钮'),
                  onPressed: () {},
                ),
                TButton(
                  size: TButtonSize.small,
                  variant: TButtonVariant.outline,
                  child: const Text('小尺寸'),
                  onPressed: () {},
                ),
                const TButton(child: Text('禁用状态')),
              ],
            ),
          ),
          SectionCard(
            title: '标签 TTag',
            subtitle: '不同配色与形态',
            child: const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TTag('默认'),
                TTag('主要', colorPreset: TTagColorPreset.primary),
                TTag(
                  '成功',
                  colorPreset: TTagColorPreset.success,
                  variant: TTagVariant.light,
                ),
                TTag(
                  '警告',
                  colorPreset: TTagColorPreset.warning,
                  variant: TTagVariant.outline,
                ),
                TTag(
                  '危险',
                  colorPreset: TTagColorPreset.danger,
                  variant: TTagVariant.lightOutline,
                ),
              ],
            ),
          ),
          SectionCard(
            title: '表单元素',
            subtitle: 'TSwitch / TAvatar / TBadge',
            child: Row(
              children: [
                TSwitch(
                  value: _switchOn,
                  onChanged: (value) => setState(() => _switchOn = value),
                ),
                SizedBox(width: token.spacer3),
                TAvatar(
                  child: Text(
                    'T',
                    style: TextStyle(fontSize: token.fontBodyMedium?.size),
                  ),
                ),
                SizedBox(width: token.spacer3),
                TBadge(
                  label: '8',
                  child: Icon(
                    TIcons.notification,
                    size: 24,
                    color: token.textColorPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  _switchOn ? '已开启' : '已关闭',
                  style: TextStyle(color: token.textColorSecondary),
                ),
              ],
            ),
          ),
          SectionCard(
            title: '单元格 TCell',
            subtitle: '列表页最常用的信息结构',
            padding: EdgeInsets.zero,
            child: TCellGroup(
              cells: [
                TCell(
                  prefix: Icon(TIcons.user, color: token.brandColor),
                  title: const Text('账号与安全'),
                  subtitle: const Text('手机号、第三方账号'),
                  arrow: true,
                  onTap: () => _toast(context, '点击了「账号与安全」'),
                ),
                TCell(
                  prefix: Icon(TIcons.setting, color: token.brandColor),
                  title: const Text('通用设置'),
                  note: const Text('已开启'),
                  arrow: true,
                  onTap: () => _toast(context, '点击了「通用设置」'),
                ),
                TCell(
                  prefix: Icon(TIcons.heart, color: token.brandColor),
                  title: const Text('关于我们'),
                  note: const Text('v1.0.0'),
                  arrow: true,
                  onTap: () => _toast(context, '点击了「关于我们」'),
                ),
              ],
            ),
          ),
          SectionCard(
            title: '反馈',
            subtitle: 'TToast / TDialog',
            child: Wrap(
              spacing: token.spacer,
              runSpacing: token.spacer,
              children: [
                TButton(
                  variant: TButtonVariant.outline,
                  child: const Text('成功'),
                  onPressed: () => TToast.showSuccess(
                    '操作成功',
                    context: context,
                  ),
                ),
                TButton(
                  variant: TButtonVariant.outline,
                  child: const Text('失败'),
                  onPressed: () => TToast.showFail(
                    '操作失败',
                    context: context,
                  ),
                ),
                TButton(
                  variant: TButtonVariant.outline,
                  child: const Text('弹窗'),
                  onPressed: () => _showDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String text) {
    TToast.showText(text, context: context);
  }

  Future<void> _showDialog(BuildContext context) async {
    await TDialog.show<void>(
      context,
      dialog: TDialog(
        title: const Text('提示'),
        content: const Text('对话框会自动继承当前的明暗主题与品牌色。'),
        actions: [
          TDialogAction(
            child: const Text('知道了'),
            role: TDialogActionRole.primary,
          ),
        ],
      ),
    );
  }
}
