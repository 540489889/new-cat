import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../shared/widgets/app_page.dart';

/// 猫圈：占位页，可替换为社区/动态信息流。
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return AppPage(
      title: '猫圈',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TIcons.usergroup, size: 48, color: token.textColorPlaceholder),
            SizedBox(height: token.spacer2),
            Text(
              '猫圈建设中，敬请期待',
              style: TextStyle(color: token.textColorSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
