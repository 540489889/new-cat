import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shop/shop_theme.dart';

/// 生成 3D 形象过程页（参考 f-cat 的 generating.dart，纯 Flutter 动画模拟）。
class Pet3DGenerationPage extends StatefulWidget {
  final String? petImageUrl;

  const Pet3DGenerationPage({super.key, this.petImageUrl});

  @override
  State<Pet3DGenerationPage> createState() => _Pet3DGenerationPageState();
}

class _Pet3DGenerationPageState extends State<Pet3DGenerationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  int _currentStep = 3;
  final List<bool> _completed = [true, true, true, false, false];

  static const List<Map<String, String>> _steps = [
    {
      'title': '基础资料分析完成',
      'subtitle': '宠物品种，年龄性别等信息已识别',
    },
    {
      'title': '照片质量检测通过',
      'subtitle': '照片清晰，角度全面，符合生成要求',
    },
    {
      'title': '宠物面部，形态特征提取完成',
      'subtitle': '宠物面部，形态特征点识别成功',
    },
    {
      'title': '生成3D模型中...',
      'subtitle': '正在构建宠物3D模型，请稍候',
    },
    {
      'title': '渲染动态形象',
      'subtitle': '即将生成生动可爱的动态形象',
    },
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _simulateProgress();
  }

  Future<void> _simulateProgress() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    setState(() {
      _completed[3] = true;
      _currentStep = 4;
    });
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _completed[4] = true);
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _backToHome() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToHome();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F6F7),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 顶部导航（与「添加宠物」向导一致：圆形返回 + 居中标题）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _backToHome,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 8,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.keyboard_arrow_left,
                            color: Color(0xFF222222), size: 28),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('添加宠物',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222222))),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '正在为宠物生成专属 3D 形象',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '生成过程可能需要1-3分钟，请耐心等待...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) => SizedBox(
                  width: 104,
                  height: 104,
                  child: CustomPaint(
                    painter: _CircularProgressPainter(
                      progress: _progressController.value,
                      color: const Color(0xFF8E6B84),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ClipOval(child: _avatar()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Column(
                    children: List.generate(_steps.length, (index) {
                      final last = index == _steps.length - 1;
                      return _buildStepItem(
                        title: _steps[index]['title']!,
                        subtitle: _steps[index]['subtitle']!,
                        isCompleted: _completed[index],
                        isCurrent: index == _currentStep,
                        isLast: last,
                      );
                    }),
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                '生成结果将自动同步到管家主页',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: GestureDetector(
                  onTap: _backToHome,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE5DFE3)),
                    ),
                    child: Center(
                      child: Text('稍后查看',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8E6B84))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final url = widget.petImageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFFF6ECEF),
      child: Icon(Icons.pets, size: 48, color: ShopColors.pink),
    );
  }

  Widget _buildStepItem({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final active = isCompleted || isCurrent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? const Color(0xFF8E6B84)
                    : isCurrent
                        ? const Color(0xFF8E6B84)
                        : Colors.transparent,
                border: active
                    ? null
                    : Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : isCurrent
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isCompleted
                    ? const Color(0xFF8E6B84).withValues(alpha: 0.35)
                    : const Color(0xFFE0E0E0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? const Color(0xFF222222)
                          : const Color(0xFF999999))),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 13,
                      color: active
                          ? const Color(0xFF666666)
                          : const Color(0xFFCCCCCC))),
              if (!isLast) const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

/// 圆形进度动画绘制器。
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFF6ECEF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
