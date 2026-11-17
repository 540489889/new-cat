import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 精彩瞬间：渐变头部 + 类型筛选 + 今日/更多瞬间三列网格 + 底部上传按钮。
/// 数据为本地 mock，接接口后替换 [_today] / [_more] 即可。
class HighlightsPage extends StatefulWidget {
  const HighlightsPage({super.key});

  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _brand = Color(0xFF8E6B84);
  static const Color _chipInk = Color(0xFF8A6A7E);

  static const List<_Moment> _today = [
    _Moment('assets/images/cat_eating.jpg', '超级神虎进食中', '喝水', true),
    _Moment('assets/images/group-1.png', '超级神虎发呆中', '发呆', false),
    _Moment('assets/images/cat_playing.jpg', '超级神虎卖萌中', '发呆', true),
  ];
  static const List<_Moment> _more = [
    _Moment('assets/images/cat_eating.jpg', '超级神虎进食中', '喝水', true),
    _Moment('assets/images/group-1.png', '超级神虎发呆中', '发呆', false),
    _Moment('assets/images/cat_cleaning.jpg', '超级神虎卖萌中', '发呆', false),
  ];

  @override
  State<HighlightsPage> createState() => _HighlightsPageState();
}

class _Moment {
  final String image;
  final String title;
  final String tag;
  final bool video;
  const _Moment(this.image, this.title, this.tag, this.video);
}

class _HighlightsPageState extends State<HighlightsPage> {
  int _type = 0; // 0 全部 / 1 视频 / 2 照片
  int _time = 0; // 0 近七天 / 1 近一月 / 2 全部

  List<_Moment> _visible(List<_Moment> src) =>
      _type == 0 ? src : src.where((m) => m.video == (_type == 1)).toList();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: HighlightsPage._bg,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top + 140,
              child: _header(top),
            ),
            Positioned(
              top: top + 118,
              left: 0,
              right: 0,
              bottom: 0,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 92),
                child: Column(
                  children: [
                    _section('今日', _visible(HighlightsPage._today)),
                    const SizedBox(height: 12),
                    _section(
                      '更多瞬间',
                      _visible(HighlightsPage._more),
                      withTime: true,
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(color: Color(0xFFE6DEE1), height: 1),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '暂无更多数据',
                          style: TextStyle(
                            fontSize: 11,
                            color: HighlightsPage._sub,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Divider(color: Color(0xFFE6DEE1), height: 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom + 16,
              child: _uploadButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(double top) {
    return Container(
      padding: EdgeInsets.only(top: top + 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8E6B84),
            Color(0xFFB48CA3),
            Color(0xFFE5D2DC),
            Color(0x00E5D2DC),
          ],
          stops: [0, 0.42, 0.72, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // 必须撑满宽度：父级 Column 是 start 对齐，否则本行只有标题文字宽，
            // 居中的标题会和 Positioned(left:16) 的返回按钮重叠
            width: double.infinity,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: HighlightsPage._ink,
                      ),
                    ),
                  ),
                ),
                const Text(
                  '精彩瞬间',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Positioned(
                  right: 18,
                  child: Icon(Icons.more_horiz, size: 22, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                _typeChip('全部', 0),
                const SizedBox(width: 8),
                _typeChip('视频', 1),
                const SizedBox(width: 8),
                _typeChip('照片', 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label, int value) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? HighlightsPage._brand : const Color(0xFFF5EBEE),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : HighlightsPage._chipInk,
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<_Moment> items, {bool withTime = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F3D2E33),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HighlightsPage._ink,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${items.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: HighlightsPage._sub,
                ),
              ),
              const Spacer(),
              if (withTime) _timeTabs(),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '暂无内容',
                  style: TextStyle(fontSize: 12, color: HighlightsPage._sub),
                ),
              ),
            )
          else
            Row(
              children: [
                for (final item in items) Expanded(child: _tile(item)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _timeTabs() {
    const labels = ['近七天', '近一月', '全部'];
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => setState(() => _time = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _time == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _time == i
                      ? const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: _time == i
                        ? HighlightsPage._ink
                        : HighlightsPage._sub,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(_Moment item) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    item.image,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  if (item.video)
                    Container(
                      width: 34,
                      height: 34,
                      // 必须有 alignment：否则 Container 的固定宽高会把 child
                      // 强制拉到 34×34，图片尺寸设置失效、三角铺满并盖住圆形遮罩
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x5C000000),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/icon/vector-ico.png',
                        width: 12,
                        height: 12,
                        fit: BoxFit.contain,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: HighlightsPage._ink),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1E9ED),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.tag,
              style: const TextStyle(
                fontSize: 10,
                color: HighlightsPage._chipInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: HighlightsPage._brand,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('上传精彩瞬间功能开发中'))),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '上传精彩瞬间',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
