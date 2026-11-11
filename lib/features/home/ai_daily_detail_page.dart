import 'package:flutter/material.dart';

/// AI 日报详情页：按设计稿还原。
/// 顶部品牌色标题栏 → 当日状态 Hero 卡 → 今日指标总览 → AI 研判。
/// 数据当前为本地 mock，后续接入后端日报详情接口后替换即可。
class AiDailyDetailPage extends StatelessWidget {
  const AiDailyDetailPage({super.key});

  // 色板（与首页「AI日报」/「我的」页统一）
  static const Color _bg = Color(0xFFF7F2ED); // 页面暖米底
  static const Color _ink = Color(0xFF3D2E33); // 主文字
  static const Color _sub = Color(0xFF9A8F93); // 次要文字
  static const Color _heroStart = Color(0xFF7F6370); // 品牌紫渐变起
  static const Color _heroEnd = Color(0xFF9E6F84); // 品牌紫渐变止

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // 顶部标题栏（返回 + 居中标题；右侧等宽占位保证标题真正居中、不压箭头）
          Container(
            padding: EdgeInsets.only(top: topInset + 8, bottom: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      size: 26, color: _ink),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Center(
                    child: const Text('AI日报详情',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  left: 12, right: 12, bottom: bottomInset + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _HeroCard(),
                  SizedBox(height: 12),
                  _MetricsCard(),
                  SizedBox(height: 12),
                  _JudgementCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当日状态 Hero 卡（品牌紫渐变背景）。
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    const textOnDark = Color(0xB3FFFFFF); // 白色 70%
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AiDailyDetailPage._heroStart, AiDailyDetailPage._heroEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期 + 状态药丸
          Row(
            children: [
              const Text('2026年11月9日 星期一',
                  style: TextStyle(fontSize: 12, color: textOnDark)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('状态稳定',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF74876A))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('超级神虎，今天状态稳定。',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.4)),
          const SizedBox(height: 6),
          const Text(
              '饮水量较昨天有所增加，完成，排便正常。整体健康状况良好。',
              style: TextStyle(
                  fontSize: 13, color: textOnDark, height: 1.5)),
        ],
      ),
    );
  }
}

/// 单格指标。
class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color tileBg;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  final Widget? trailing;

  const _MetricTile({
    required this.icon,
    required this.tileBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AiDailyDetailPage._ink)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AiDailyDetailPage._ink)),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(unit,
                    style: const TextStyle(
                        fontSize: 12, color: AiDailyDetailPage._sub)),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}

/// 今日指标总览。
class _MetricsCard extends StatelessWidget {
  const _MetricsCard();

  @override
  Widget build(BuildContext context) {
    const upColor = Color(0xFF4E9B58);
    const normalBg = Color(0xFFFFFFFF);
    const normalInk = Color(0xFF7C8B7E);

    final tiles = [
      _MetricTile(
        icon: Icons.water_drop,
        tileBg: const Color(0xFFE1EEF6),
        iconColor: const Color(0xFF4E9FCB),
        label: '喝水',
        value: '180',
        unit: 'ml',
        trailing: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_upward, size: 11, color: upColor),
            SizedBox(width: 1),
            Text('8%',
                style: TextStyle(
                    fontSize: 12, color: upColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      _MetricTile(
        icon: Icons.restaurant,
        tileBg: const Color(0xFFFAE8D9),
        iconColor: const Color(0xFFE1914F),
        label: '进食',
        value: '60',
        unit: 'g',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: normalBg, borderRadius: BorderRadius.circular(999)),
          child: const Text('正常',
              style: TextStyle(fontSize: 10, color: normalInk)),
        ),
      ),
      _MetricTile(
        icon: Icons.directions_run,
        tileBg: const Color(0xFFE1EFE0),
        iconColor: const Color(0xFF64A465),
        label: '活动',
        value: '42',
        unit: 'min',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: normalBg, borderRadius: BorderRadius.circular(999)),
          child: const Text('正常',
              style: TextStyle(fontSize: 10, color: normalInk)),
        ),
      ),
      _MetricTile(
        icon: Icons.wc,
        tileBg: const Color(0xFFD9ECE7),
        iconColor: const Color(0xFF4BA394),
        label: '如厕',
        value: '2',
        unit: '次',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: normalBg, borderRadius: BorderRadius.circular(999)),
          child: const Text('正常',
              style: TextStyle(fontSize: 10, color: normalInk)),
        ),
      ),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日指标总览',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AiDailyDetailPage._ink)),
          const SizedBox(height: 12),
          for (int r = 0; r < 2; r++) ...[
            Row(
              children: [
                Expanded(child: tiles[r * 2]),
                const SizedBox(width: 10),
                Expanded(child: tiles[r * 2 + 1]),
              ],
            ),
            if (r == 0) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// 单段 AI 研判。
class _JudgeBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _JudgeBlock({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Text(body,
            style: const TextStyle(
                fontSize: 13,
                color: AiDailyDetailPage._sub,
                height: 1.6)),
      ],
    );
  }
}

/// AI 研判。
class _JudgementCard extends StatelessWidget {
  const _JudgementCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('AI研判',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AiDailyDetailPage._ink)),
          SizedBox(height: 16),
          _JudgeBlock(
            icon: Icons.auto_awesome,
            color: Color(0xFF9E6F84),
            title: '综合判断',
            body: '小白今日整体状态良好，四项核心指标均在正常范围内。'
                '饮水较昨日增长 8%，与气温升高和活动量增加呈正相关，'
                '属于健康的生理调节。',
          ),
          SizedBox(height: 16),
          _JudgeBlock(
            icon: Icons.water_drop,
            color: Color(0xFF4E9FCB),
            title: '饮水分析',
            body: '日均 175ml，较上周均值（162ml）增长 8.0%。'
                '饮水高峰集中在早晨进食后与傍晚活动后，与进食和活动节奏高度吻合，'
                '属于健康饮水模式。',
          ),
          SizedBox(height: 16),
          _JudgeBlock(
            icon: Icons.restaurant,
            color: Color(0xFFE1914F),
            title: '进食分析',
            body: '三餐均在预定时间窗口内完成。进食速度约 5.5g/min'
                '（正常范围 4-8g/min），未见呕吐、拒食或挑食迹象。'
                '进食后 30 分钟内饮水行为自然触发。',
          ),
          SizedBox(height: 16),
          _JudgeBlock(
            icon: Icons.pets,
            color: Color(0xFF64A465),
            title: '行为分析',
            body: '活动高峰集中在早晨 6-8 点与傍晚 18-20 点，'
                '与英短品种晨昏活动习性一致。活动强度中等，'
                '未见异常躁动或过度嗜睡。',
          ),
        ],
      ),
    );
  }
}

/// 白色圆角卡片容器（与「我的」页一致的 16 圆角 + 14 内边距）。
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
