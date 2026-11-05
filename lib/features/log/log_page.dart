import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/section_card.dart';

/// 日志：占位页，可替换为真实的时间轴/日志数据。
class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return AppPage(
      title: '日志',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: '今天',
            padding: EdgeInsets.zero,
            child: TCellGroup(
              cells: [
                TCell(
                  title: const Text('自动喂食完成'),
                  note: const Text('09:30'),
                  subtitle: const Text('进食 32g，速率正常'),
                ),
                TCell(
                  title: const Text('饮水提醒'),
                  note: const Text('12:45'),
                  subtitle: const Text('上午饮水次数偏少，已提醒'),
                ),
              ],
            ),
          ),
          SectionCard(
            title: '昨天',
            padding: EdgeInsets.zero,
            child: TCellGroup(
              cells: [
                TCell(
                  title: const Text('猫砂盆清洁'),
                  note: const Text('20:30'),
                  subtitle: const Text('本次清扫已完成记录'),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              '示例数据，接入接口后替换',
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
