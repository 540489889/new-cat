import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

/// 二级页面示例：演示路由参数、返回按钮与页面骨架复用。
class DemoDetailPage extends StatelessWidget {
  const DemoDetailPage({super.key, this.entry});

  /// 由上一页通过 `Navigator.pushNamed(..., arguments: ...)` 传入。
  final String? entry;

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return AppPage(
      title: '页面示例',
      showBack: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: '路由参数',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry ?? '未接收到参数',
                  style: TextStyle(
                    color: token.textColorPrimary,
                    fontSize: token.fontBodyLarge?.size ?? 16,
                  ),
                ),
                SizedBox(height: token.spacer),
                Text(
                  '参数通过 Navigator.pushNamed 的 arguments 传入，'
                  '在 AppRouter.onGenerateRoute 中解析。',
                  style: TextStyle(
                    color: token.textColorSecondary,
                    fontSize: token.fontBodyMedium?.size ?? 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: '如何使用这个页面骨架',
            child: TCellGroup(
              cells: [
                TCell(
                  title: const Text('1. 新建页面'),
                  subtitle: const Text('在 features 下创建 xxx_page.dart'),
                ),
                TCell(
                  title: const Text('2. 用 AppPage 包裹'),
                  subtitle: const Text('统一导航栏、背景色与内边距'),
                ),
                TCell(
                  title: const Text('3. 登记路由'),
                  subtitle: const Text('在 AppRoutes / AppRouter 中补充映射'),
                ),
              ],
            ),
          ),
          TButton(
            variant: TButtonVariant.outline,
            child: const Text('返回上一页'),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
