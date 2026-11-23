import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/http/api_client.dart';
import '../../shared/widgets/image_picker_dialog.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 投诉建议（对齐参考项目 f-cat 的 `pages/member/feedback.dart`）：
/// 反馈内容（最多 500 字）+ 最多 4 张图片 + 联系方式，
/// 图片先传 `/app/user/file/upload`（scene=feedback）拿到 URL，
/// 再与其他字段一起提交 `/app/complaint/create`。
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  // 与「我的」页一致的设计稿色板
  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _brand = Color(0xFF7F6370);
  static const Color _brandDeep = Color(0xFF6E5665);
  static const Color _red = Color(0xFFE05A5A);

  /// 最多上传图片数（与参考项目一致）
  static const int _maxImages = 4;

  static const Color _cardShadow = Color(0x0D3D2E33);

  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final FocusNode _contentFocus = FocusNode();

  /// 已选图片：xfile 用于取文件名，bytes 用于预览（不依赖 dart:io，兼容 Web）
  final List<({XFile file, Uint8List bytes})> _images = [];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 内容变化时刷新字数与提交按钮可用态
    _contentCtrl.addListener(_onContentChanged);
    // 输入框聚焦时给卡片描边高亮
    _contentFocus.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _contentCtrl.removeListener(_onContentChanged);
    _contentFocus.removeListener(_onContentChanged);
    _contentCtrl.dispose();
    _contactCtrl.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  /// 有内容（用于按钮配色；提交中也保持高亮，避免闪灰）
  bool get _hasContent => _contentCtrl.text.trim().isNotEmpty;

  bool get _canSubmit => _hasContent && !_submitting;

  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) return;
    final source = await showImagePickerDialog(context);
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _images.add((file: picked, bytes: bytes)));
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      TToast.showText('请输入反馈内容', context: context);
      return;
    }

    setState(() => _submitting = true);
    try {
      // 先逐张上传图片，任一失败即中止（避免附件静默丢失）
      final urls = <String>[];
      for (final img in _images) {
        final res = await ApiClient.instance.uploadFile(
          '/app/user/file/upload',
          bytes: img.bytes,
          filename: img.file.name,
          extraFields: {'scene': 'feedback'},
        );
        if (!mounted) return;
        if (!res.isSuccess) {
          TToast.showText(
            res.message.isEmpty ? '图片上传失败' : '图片上传失败：${res.message}',
            context: context,
          );
          return;
        }
        final url = res.data is String
            ? res.data as String
            : (res.asMap['url']?.toString() ?? '');
        if (url.isEmpty) {
          TToast.showText('图片上传返回为空', context: context);
          return;
        }
        urls.add(url);
      }

      final res = await ApiClient.instance.post(
        '/app/complaint/create',
        body: {
          'content': content,
          'imgs': urls.join(','),
          'contact': _contactCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      if (!res.isSuccess) {
        TToast.showText(
          res.message.isEmpty ? '提交失败' : res.message,
          context: context,
        );
        return;
      }
      TToast.showSuccess('提交成功', context: context);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) TToast.showText('提交失败：$e', context: context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('投诉建议'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: ListView(
          // 滚动时收起键盘
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _contentCard(),
            const SizedBox(height: 14),
            _contactCard(),
            const SizedBox(height: 14),
            _footerHint(),
          ],
        ),
        bottomNavigationBar: _submitBar(bottomInset),
      ),
    );
  }

  Widget _contentCard() {
    final len = _contentCtrl.text.length;
    final focused = _contentFocus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: focused
              ? _brand.withValues(alpha: 0.32)
              : Colors.transparent,
        ),
        boxShadow: const [
          BoxShadow(color: _cardShadow, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '反馈内容',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$len/500',
                  style: TextStyle(
                    fontSize: 11,
                    color: len > 450 ? _red : _sub,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentCtrl,
            focusNode: _contentFocus,
            minLines: 5,
            maxLines: 8,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(fontSize: 15, height: 1.6, color: _ink),
            decoration: const InputDecoration(
              hintText: '请描述您遇到的问题或建议…\n越具体，我们越能帮上忙',
              hintStyle: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFFB9AFB2),
              ),
              // 全部显式关闭，避免主题默认下划线在卡片里出现一条杂线
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '问题截图',
                style: TextStyle(
                  fontSize: 12,
                  color: _ink.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              Text(
                '选填 · 最多 $_maxImages 张',
                style: const TextStyle(fontSize: 11, color: _sub),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < _images.length; i++)
                _thumb(_images[i].bytes, i),
              if (_images.length < _maxImages) _addButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: _cardShadow, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_iphone_rounded,
                size: 17, color: _brand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _contactCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: const InputDecoration(
                hintText: '手机号（选填），便于我们回访',
                hintStyle: TextStyle(fontSize: 14, color: _sub),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 13, color: _sub.withValues(alpha: 0.8)),
        const SizedBox(width: 5),
        Text(
          '联系方式仅用于回访沟通，不会对外公开',
          style: TextStyle(
            fontSize: 11,
            color: _sub.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  /// 底部提交栏：有内容时品牌色渐变（禁用态用暖灰而非脏粉）
  Widget _submitBar(double bottomInset) {
    final active = _hasContent;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, bottomInset > 0 ? bottomInset * 0.3 : 12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _canSubmit ? _submit : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF90727F), _brandDeep],
                    )
                  : null,
              color: active ? null : const Color(0xFFE9E1DA),
              borderRadius: BorderRadius.circular(26),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _brand.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      '提交反馈',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: active
                            ? Colors.white
                            : const Color(0xFFAFA3A0),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// 已选图片缩略图 + 右上角删除
  Widget _thumb(Uint8List bytes, int index) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 「添加图片」虚线占位块
  Widget _addButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: CustomPaint(
        painter: const _DashedBorderPainter(
          color: Color(0xFFDACDC5),
          radius: 12,
        ),
        child: SizedBox(
          width: 76,
          height: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, size: 18, color: _brand),
              ),
              const SizedBox(height: 4),
              const Text('添加', style: TextStyle(fontSize: 11, color: _sub)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 圆角虚线边框（Flutter 无内置虚线，按 path metrics 分段绘制）
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color
      ..isAntiAlias = true;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
