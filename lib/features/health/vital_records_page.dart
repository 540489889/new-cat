import 'package:flutter/material.dart';

/// 体征记录页（体重记录）：按设计稿还原。
/// 顶部紫渐变（返回 + 标题 + 分类标签）→ 今日体重 → 体重趋势折线图 → 体重记录列表 → 底部「记录体重」按钮。
/// 数据当前为本地 mock，接入后端体征接口后替换即可。
class VitalRecordsPage extends StatefulWidget {
  const VitalRecordsPage({super.key});

  @override
  State<VitalRecordsPage> createState() => _VitalRecordsPageState();
}

class _VitalRecordsPageState extends State<VitalRecordsPage> {
  // 色板
  static const Color _purple = Color(0xFF8B8FC7); // 品牌紫（标签/折线/按钮）
  static const Color _ink = Color(0xFF3D3A4E); // 主文字

  int _tab = 0; // 0 体重 / 1 睡眠 / 2 如厕
  int _range = 0; // 0 近一月 / 1 近一年

  // 折线图 mock 数据（近一月：09/22 ~ 09/28）
  static const List<double> _weights = [
    4.0, 4.05, 4.02, 4.1, 4.15, 4.18, 4.2,
  ];
  static const List<String> _dates = [
    '09/22', '09/23', '09/24', '09/25', '09/26', '09/27', '09/28',
  ];

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // 顶部紫渐变背景（渐到浅紫白后保持不变）
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFBFBCE2), Color(0xFFF4F3FA)],
                  stops: [0.0, 0.38],
                ),
              ),
            ),
          ),
          // 顶部固定（不随内容滚动）：返回 + 居中标题 + 分类标签；下方内容滚动
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: topInset + 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.chevron_left,
                              size: 22, color: _ink),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text('体征记录',
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
                const SizedBox(height: 14),
                // 分类标签：体重 / 睡眠 / 如厕
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => setState(() => _tab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: _tab == i ? _purple : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              const ['体重', '睡眠', '如厕'][i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _tab == i ? Colors.white : _ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 滚动内容
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: bottomInset + 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TodayWeightCard(),
                        const SizedBox(height: 12),
                        _TrendCard(
                          range: _range,
                          onRangeChanged: (v) =>
                              setState(() => _range = v),
                          values: _weights,
                          dates: _dates,
                        ),
                        const SizedBox(height: 12),
                        const _RecordsCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 底部「记录体重」按钮
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 16,
            child: GestureDetector(
              onTap: () {}, // TODO: 弹出记录体重弹窗
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text('记录体重',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 集中色板（供各卡片共用）。
class _VitalPalette {
  static const Color ink = Color(0xFF3D3A4E);
  static const Color sub = Color(0xFF9A99AB);
  static const Color purple = Color(0xFF8B8FC7);
  static const Color goodInk = Color(0xFF4E9B58);
  static const Color goodBg = Color(0xFFE7F2E7);
}

/// 白色圆角卡片容器。
class _VCard extends StatelessWidget {
  final Widget child;
  const _VCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// 今日体重卡：大数字 + 环比 + 竖分隔线 + 健康范围。
class _TodayWeightCard extends StatelessWidget {
  const _TodayWeightCard();

  @override
  Widget build(BuildContext context) {
    const ink = _VitalPalette.ink;
    const sub = _VitalPalette.sub;
    const good = _VitalPalette.goodInk;
    return _VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日体重',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 14),
          Row(
            children: [
              // 左：当前体重 + 环比
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('4.2',
                          style: TextStyle(
                              fontSize: 32,
                              height: 1.0,
                              fontWeight: FontWeight.w800,
                              color: ink)),
                      SizedBox(width: 4),
                      Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text('kg',
                            style:
                                TextStyle(fontSize: 13, color: sub)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Text('较上周同期',
                          style: TextStyle(fontSize: 12, color: sub)),
                      SizedBox(width: 4),
                      Icon(Icons.south, size: 12, color: good),
                      SizedBox(width: 1),
                      Text('0.1kg',
                          style: TextStyle(
                              fontSize: 12,
                              color: good,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              // 竖分隔线
              Container(
                width: 1,
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: const Color(0xFFE8E6F0),
              ),
              // 右：健康范围
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('健康体重范围',
                      style: TextStyle(fontSize: 12, color: sub)),
                  SizedBox(height: 10),
                  Text('3.5kg~5.0kg',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ink)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 体重趋势卡：标题 + 近一月/近一年切换 + 折线图。
class _TrendCard extends StatelessWidget {
  final int range;
  final ValueChanged<int> onRangeChanged;
  final List<double> values;
  final List<String> dates;

  const _TrendCard({
    required this.range,
    required this.onRangeChanged,
    required this.values,
    required this.dates,
  });

  @override
  Widget build(BuildContext context) {
    return _VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('体重趋势',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _VitalPalette.ink)),
              const Spacer(),
              // 近一月 / 近一年 分段控件
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F0F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < 2; i++)
                      GestureDetector(
                        onTap: () => onRangeChanged(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: range == i
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            i == 0 ? '近一月' : '近一年',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: range == i
                                  ? _VitalPalette.ink
                                  : _VitalPalette.sub,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('单位/kg',
              style:
                  TextStyle(fontSize: 11, color: _VitalPalette.sub)),
          const SizedBox(height: 8),
          // 折线图
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 250),
              painter: _WeightChartPainter(
                  values: values, labels: dates),
            ),
          ),
        ],
      ),
    );
  }
}

/// 体重折线图：网格虚线 + 渐变面积 + 折线 + 空心点 + 末点气泡标注。
class _WeightChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  static const double yMin = 2.0, yMax = 7.0;

  _WeightChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    const lineColor = Color(0xFF8B8FC7);
    const gridColor = Color(0xFFE2E0EF);
    const labelColor = Color(0xFF9A99AB);

    const padL = 36.0, padR = 16.0, padT = 30.0, padB = 24.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;
    if (chartW <= 0 || chartH <= 0 || values.isEmpty) return;

    double yOf(double v) =>
        padT + (1 - (v - yMin) / (yMax - yMin)) * chartH;
    double xOf(int i) =>
        padL + chartW * i / (values.length - 1).clamp(1, 1 << 31);

    // 网格虚线 + Y 轴刻度
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (double v = yMin; v <= yMax + 0.001; v += 1.0) {
      final y = yOf(v);
      for (double x = padL; x < size.width - padR; x += 7) {
        canvas.drawLine(
            Offset(x, y),
            Offset((x + 4).clamp(padL, size.width - padR), y),
            gridPaint);
      }
      _text(canvas, v.toStringAsFixed(1),
          Rect.fromLTWH(0, y - 6, padL - 8, 12),
          align: TextAlign.right, color: labelColor);
    }

    // 面积渐变
    final areaPath = Path()..moveTo(xOf(0), yOf(values.first));
    for (int i = 1; i < values.length; i++) {
      areaPath.lineTo(xOf(i), yOf(values[i]));
    }
    areaPath
      ..lineTo(xOf(values.length - 1), padT + chartH)
      ..lineTo(xOf(0), padT + chartH)
      ..close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0x408B8FC7), Color(0x008B8FC7)],
        ).createShader(Rect.fromLTWH(padL, padT, chartW, chartH)),
    );

    // 折线
    final linePath = Path()..moveTo(xOf(0), yOf(values.first));
    for (int i = 1; i < values.length; i++) {
      linePath.lineTo(xOf(i), yOf(values[i]));
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // 数据点：空心白底紫描边；末点实心
    for (int i = 0; i < values.length; i++) {
      final c = Offset(xOf(i), yOf(values[i]));
      final isLast = i == values.length - 1;
      canvas.drawCircle(
          c, isLast ? 4 : 3.5, Paint()..color = isLast ? lineColor : Colors.white);
      if (!isLast) {
        canvas.drawCircle(
          c,
          3.5,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
    }

    // X 轴日期
    for (int i = 0; i < labels.length && i < values.length; i++) {
      final x = xOf(i);
      _text(canvas, labels[i],
          Rect.fromLTWH(x - 24, size.height - 18, 48, 12),
          align: TextAlign.center, color: labelColor);
    }

    // 末点气泡标注「4.2kg」
    final lastX = xOf(values.length - 1);
    final lastY = yOf(values.last);
    final lastText = '${values.last.toStringAsFixed(1)}kg';
    final bubbleRight = (lastX + 28).clamp(60.0, size.width - 6);
    final bubbleLeft = bubbleRight - 58;
    final bubbleTop = lastY - 40;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleLeft, bubbleTop, 58, 26),
      const Radius.circular(8),
    );
    canvas.drawRRect(bubbleRect, Paint()..color = lineColor);
    final tipX = lastX.clamp(bubbleLeft + 14, bubbleRight - 14);
    final tipY = bubbleTop + 26;
    final tip = Path()
      ..moveTo(tipX - 6, tipY)
      ..lineTo(tipX + 6, tipY)
      ..lineTo(tipX, tipY + 6)
      ..close();
    canvas.drawPath(tip, Paint()..color = lineColor);
    _text(canvas, lastText,
        Rect.fromLTWH(bubbleLeft, bubbleTop + 1, 58, 24),
        align: TextAlign.center,
        color: Colors.white,
        fontSize: 12,
        bold: true);
  }

  void _text(Canvas canvas, String s, Rect rect,
      {TextAlign align = TextAlign.left,
      Color color = const Color(0xFF9A99AB),
      double fontSize = 10,
      bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => rect.right - tp.width,
      TextAlign.center => rect.left + (rect.width - tp.width) / 2,
      _ => rect.left,
    };
    tp.paint(canvas, Offset(dx, rect.top + (rect.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter old) =>
      old.values != values || old.labels != labels;
}

/// 体重记录列表卡。
class _RecordsCard extends StatelessWidget {
  const _RecordsCard();

  static const List<({String weight, String time})> _records = [
    (weight: '3.5kg', time: '2026-09-28 10:30'),
    (weight: '3.2kg', time: '2026-09-28 10:30'),
  ];

  @override
  Widget build(BuildContext context) {
    return _VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('体重记录',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _VitalPalette.ink)),
          const SizedBox(height: 6),
          for (int i = 0; i < _records.length; i++) ...[
            if (i > 0) Container(height: 1, color: const Color(0xFFF0EEF5)),
            _recordRow(_records[i]),
          ],
        ],
      ),
    );
  }

  Widget _recordRow(({String weight, String time}) r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 记录来源小图标
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFECEEFA),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.save_alt,
                size: 14, color: _VitalPalette.purple),
          ),
          const SizedBox(width: 10),
          Text(r.weight,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _VitalPalette.ink)),
          const Spacer(),
          Text(r.time,
              style: const TextStyle(
                  fontSize: 12, color: _VitalPalette.sub)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _VitalPalette.goodBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('正常范围',
                style: TextStyle(
                    fontSize: 11, color: _VitalPalette.goodInk)),
          ),
        ],
      ),
    );
  }
}
