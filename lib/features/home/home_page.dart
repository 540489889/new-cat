import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/pet/pet_state.dart';
import '../../shared/widgets/pet_picker.dart';

/// 首页：顶部沉浸式宠物视频区（全宽、延伸到状态栏后面），
/// 切换条叠加在视频之上；其余内容待填充。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 视频底色驱动的页面背景色；初始给一个暖灰底色，避免首屏白闪，
  /// 待封面/视频取色后更新为视频真实底色。
  Color? _bgColor = const Color(0xFFEFE9E6);
  final ScrollController _scrollCtrl = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    // 登录后加载宠物列表与顶部展示视频
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final petState = context.read<PetState>();
      if (!petState.isLoaded) petState.loadPets();
    });
  }

  void _onScroll() {
    if (!mounted) return;
    final o = _scrollCtrl.offset;
    if ((o - _scrollOffset).abs() > 1) setState(() => _scrollOffset = o);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final screenH = MediaQuery.of(context).size.height;
    // 视频固定占顶部约 30%、浮层占底部约 70%，整页正好一屏、无空隙；
    // 与视频自身比例无关，浮层高度稳定、内容始终可见
    final videoBandH = screenH * 0.38;
    // 浮层向上压在视频上的重叠量：让首屏 AI日报 卡直接盖住视频底部，
    // 形成「内容压在视频上面」的观感
    const overlap = 36.0;

    return Scaffold(
      // 背景色由视频底部底色驱动，使视频无缝融入页面
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // 视频固定在顶部一段（约 30% 屏高），不随下方浮层滚动
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: videoBandH,
            child: _HeroVideo(
              height: videoBandH,
              bgColor: _bgColor,
              onColorExtracted: (c) => setState(() => _bgColor = c),
            ),
          ),
          // 浮层：像 fixed 浮层一样贴在屏幕底部（约 70%），并向上压在视频上面；
          // 起点上移到「视频下沿上方 overlap」处，使首屏 AI日报 卡直接盖在视频上，
          // 形成「内容压在视频上面」的层次；内部内容可滚动（页面可滚动的就是这一块）
          Positioned(
            top: videoBandH - overlap,
            left: 0,
            right: 0,
            bottom: 0,
            // 顶部渐隐（弹幕式）：卡片通栏（无左右边距），淡出块整屏宽；
            // 卡片间用 SizedBox 占位保持间距。默认不渐隐、内容清晰；
            // 上滑时顶部一段由透明平滑渐隐，内容滑到视频边缘时柔和融入（透出视频）
            child: ShaderMask(
              shaderCallback: (rect) {
                // 弹幕式边缘淡出：渐隐随滚动出现，默认（未滚动）不渐隐、内容清晰；
                // 上滑时顶部一段由透明柔和渐隐，让内容滑到视频边缘时平滑融入（透出视频）
                final fadePx = _scrollOffset.clamp(0.0, 72.0);
                final fade = (fadePx / rect.height).clamp(0.0, 1.0);
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: fade <= 0
                      ? [Colors.white, Colors.white]
                      : [Colors.transparent, Colors.white],
                  stops: fade <= 0
                      ? const [0.0, 1.0]
                      : [0.0, fade],
                ).createShader(rect);
              },
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                // 顶部仅留少量呼吸间距，让首张卡片压在视频上的感觉更明显；
                // 底部留白避开悬浮胶囊
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _AiDailyCard(),
                    SizedBox(height: 12),
                    _AgentDynamicCard(),
                    SizedBox(height: 12),
                    _TimelineCard(),
                  ],
                ),
              ),
            ),
          ),
          // 固定切换条：叠在视频之上，不随滚动移动
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PetSwitchBar(
              scrollOffset: _scrollOffset,
              topInset: topInset,
              bgColor: _bgColor ?? const Color(0xFFEFE9E6),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部视频区：全宽通栏、从屏幕最顶端（含状态栏）铺下来，无圆角。
/// 视频地址来自后端「宠物展示信息」接口（/app/pet/show 的 mediaUrl）。
/// 未查询到视频或视频未就绪时显示封面图（接口 imgUrl，无则本地
/// hero_cat.jpg 兜底），视频就绪后封面淡出、media_kit 静音循环播放。
/// 标题叠加在视频之上，点击宠物名 / 切换图标弹出宠物选择面板。
class _HeroVideo extends StatefulWidget {
  /// 当前页面背景色（由视频底色驱动），用于视频底部渐变融入。
  final Color? bgColor;

  /// 从视频帧提取到的底色回调，供外层设置页面背景。
  final void Function(Color)? onColorExtracted;

  /// 固定的视频展示高度（覆盖按宽高比算出的真实高度）。
  /// 用于「视频头 + 底部浮层」布局：视频只占顶部一段，不随视频真实比例变化。
  final double? height;

  const _HeroVideo({this.bgColor, this.onColorExtracted, this.height});

  @override
  State<_HeroVideo> createState() => _HeroVideoState();
}

class _HeroVideoState extends State<_HeroVideo> with WidgetsBindingObserver {
  Player? _player;
  VideoController? _controller;
  bool _ready = false;
  String? _openedUrl;
  PetState? _petState;
  // 视频真实宽高比：用于按满宽计算高度，使整段视频完整展示（不裁切）。
  // 未取到时回落 16:9。
  double? _videoAspect;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    // 监听 App 前后台切换：后台暂停、回到前台自动恢复播放
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _petState = context.read<PetState>();
      _petState!.addListener(_onPetChanged);
      _onPetChanged();
    });
  }

  Future<void> _initPlayer() async {
    try {
      _player = Player();
      _controller = VideoController(_player!);
    } catch (e) {
      debugPrint('[HeroVideo] initPlayer failed: $e');
      // 无法创建播放器：保持封面兜底
      return;
    }
    debugPrint('[HeroVideo] player+controller ready');
    _player!.setVolume(0);
    // 单条循环：播放完成后回到开头继续播放
    _player!.stream.completed.listen((_) {
      _player!.seek(Duration.zero);
      _player!.play();
    });
    // 首帧渲染后淡入视频层，并按视频真实宽高比调整高度
    _player!.stream.width.listen((w) {
      debugPrint('[HeroVideo] width=$w');
      _updateAspect();
      if (w != null && w > 0 && mounted && !_ready) {
        setState(() => _ready = true);
        debugPrint('[HeroVideo] ready=true');
        _extractColor();
      }
    });
    _player!.stream.height.listen((_) => _updateAspect());
  }

  /// 根据播放器当前真实宽高计算视频比例，驱动 Hero 高度按满宽自适应，
  /// 让整段视频完整展示、不被裁切。
  void _updateAspect() {
    final w = _player?.state.width;
    final h = _player?.state.height;
    if (w != null && w > 0 && h != null && h > 0 && mounted) {
      final aspect = w / h;
      if (_videoAspect != aspect) setState(() => _videoAspect = aspect);
    }
  }

  /// 从像素采样「底部 10% 区域」平均色（贴近视频与页面相接的边缘），
  /// 作为页面底色，使视频更自然地融入页面。
  Color? _averageBottom(Uint32List pixels, int w, int h) {
    int r = 0, g = 0, b = 0, count = 0;
    final yStart = (h * 0.9).toInt();
    final xStart = (w * 0.15).toInt();
    final xEnd = (w * 0.85).toInt();
    for (int y = yStart; y < h; y++) {
      for (int x = xStart; x < xEnd; x++) {
        final p = pixels[y * w + x];
        // rawRgba 小端：低字节 R、次 G、次 B
        r += p & 0xFF;
        g += (p >> 8) & 0xFF;
        b += (p >> 16) & 0xFF;
        count++;
      }
    }
    if (count == 0) return null;
    return Color.fromARGB(
      255,
      (r / count).round().clamp(0, 255),
      (g / count).round().clamp(0, 255),
      (b / count).round().clamp(0, 255),
    );
  }

  /// 抓取当前视频帧，取底部区域平均色作为「视频底色」回调给外层。
  Future<void> _extractColor() async {
    if (_player == null || !mounted) return;
    try {
      // 略等一帧，确保画面已渲染
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final bytes = await _player!.screenshot();
      if (bytes == null || !mounted) return;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null || !mounted) return;
      final color = _averageBottom(data.buffer.asUint32List(), image.width, image.height);
      if (color != null) widget.onColorExtracted?.call(color);
    } catch (e) {
      debugPrint('[HeroVideo] extractColor error: $e');
    }
  }

  /// 从封面网络图取底部平均色，作为视频就绪前的页面底色（避免首屏白闪）。
  Future<void> _extractColorFromImage(String url) async {
    try {
      final provider = NetworkImage(url);
      final completer = Completer<ui.Image>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (e, _) {
          if (!completer.isCompleted) completer.completeError(e);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      final img = await completer.future;
      if (!mounted) return;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null || !mounted) return;
      final color = _averageBottom(data.buffer.asUint32List(), img.width, img.height);
      if (color != null) widget.onColorExtracted?.call(color);
    } catch (e) {
      debugPrint('[HeroVideo] extractColorFromImage error: $e');
    }
  }

  /// 宠物展示信息到位后（拿到 mediaUrl）再打开播放器。
  void _onPetChanged() {
    if (!mounted || _player == null || _petState == null) return;
    final url = _petState!.mediaUrl;
    final cover = _petState!.coverUrl;
    // 先用封面图取底色：首屏 / 视频未就绪时即已有底色，避免白闪
    if (cover != null && cover.isNotEmpty) _extractColorFromImage(cover);
    debugPrint('[HeroVideo] onPetChanged mediaUrl=$url');
    // 当前宠物无视频：停掉播放、回退封面
    if (url == null || url.isEmpty) {
      if (_openedUrl != null) {
        _openedUrl = null;
        _player!.pause();
        if (mounted) setState(() => _ready = false);
      }
      return;
    }
    if (_openedUrl != url) {
      _openedUrl = url;
      // 不重置比例：盒子高度始终沿用视频高度，图片态也保持同一高度，避免跳动。
      _player!
          .open(Media(url))
          .then((_) {
        debugPrint('[HeroVideo] open ok, play');
        _updateAspect();
        _extractColor();
        _player!.play();
      }).catchError((e) {
      // 播放失败：退回封面图
      debugPrint('[HeroVideo] open error: $e');
      if (mounted) setState(() => _ready = false);
      });
      }
      }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _petState?.removeListener(_onPetChanged);
    _player?.dispose();
    super.dispose();
  }

  /// App 前后台切换：media_kit 在后台会暂停播放，回到前台需手动恢复。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_ready && _player != null && _openedUrl != null) {
        debugPrint('[HeroVideo] resumed -> play');
        _player!.play();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // 后台 / 被回收时主动暂停，避免后台空耗资源
      _player?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetState>();
    final controller = _controller;
    final showVideo = _ready && controller != null;
    // 视频从屏幕最顶端铺起（覆盖状态栏），状态栏高度用于给标题留位
    final topInset = MediaQuery.of(context).padding.top;
    // 视频满宽铺开，高度按视频真实宽高比计算，使整段视频完整展示（不裁切）；
    // 未取到视频比例时回落 16:9，避免封面态出现 0 高度。
    final screenW = MediaQuery.of(context).size.width;
    final aspect = _videoAspect ?? 16 / 9;
    // 若外层给定固定高度（如「视频头 + 底部浮层」布局），则按该高度展示（cover 裁切）；
    // 否则按真实宽高比完整展示。
    final heroHeight = widget.height ?? (topInset + screenW / aspect);

    return GestureDetector(
      // 左右滑动切换宠物：左滑→下一个，右滑→上一个（循环）
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity;
        if (v == null) return;
        final count = pet.pets.length;
        if (count <= 1) return;
        if (v.abs() < 100) return;
        var idx = pet.selectedIndex;
        if (v < 0) {
          idx = (idx + 1) % count;
        } else {
          idx = (idx - 1 + count) % count;
        }
        if (idx != pet.selectedIndex) pet.selectPet(idx);
      },
      child: SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: ClipRRect(
          child: Stack(
            fit: StackFit.expand,
          children: [
            // 封面：优先接口返回的 imgUrl（网络图），否则本地兜底图
            AnimatedOpacity(
              opacity: showVideo ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: pet.coverUrl != null && pet.coverUrl!.isNotEmpty
                  ? Image.network(
                      pet.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Image.asset(
                        'assets/images/hero_cat.jpg',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      'assets/images/hero_cat.jpg',
                      fit: BoxFit.cover,
                    ),
            ),
            // 视频就绪后直接播放（淡入覆盖在封面之上，封面随即淡出）
            if (controller != null)
              AnimatedOpacity(
                opacity: showVideo ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: AbsorbPointer(
                  child: Video(
                    controller: controller,
                    fit: BoxFit.cover,
                    controls: null,
                    wakelock: false,
                  ),
                ),
              ),
            // 顶部渐变遮罩：自上而下的白色薄雾，衬托黑色标题文字
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
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

}

/// 顶部固定切换条：始终悬浮在页面顶部，不随滚动移动，滚动后仍可点按切换宠物。
/// 顶部（视频区）背景透明、不遮挡视频；向下滚动后背景渐显为页面底色，
/// 形成分隔，避免压住下方卡片文字。
class _PetSwitchBar extends StatelessWidget {
  final double scrollOffset;
  final double topInset;
  final Color bgColor;
  const _PetSwitchBar({
    required this.scrollOffset,
    required this.topInset,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    final pet = context.watch<PetState>();
    final name = pet.selectedPet?.nickname.isNotEmpty == true
        ? pet.selectedPet!.nickname
        : '超级喵克，哎喵';
    // 滚动约 80px 内将背景从透明渐变到页面底色，避免突兀
    final t = (scrollOffset / 80).clamp(0, 1);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topInset + 8,
        left: 16,
        right: 16,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        border: t > 0
            ? Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06 * t),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 仅这一行可点按弹窗，避免整块拦截下方内容的手势
          GestureDetector(
            onTap: () => showPetPicker(context, pet),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: token.fontTitleLarge?.size ?? 18,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Image(
                  image: AssetImage('assets/images/icon/swich-1.png'),
                  width: 13,
                  height: 13,
                  color: Color(0xFF7F6370),
                ),
              ],
            ),
          ),
          SizedBox(height: token.spacer / 2),
          Text(
            '铲屎官，早上好呀~',
            style: TextStyle(
              color: Colors.black87,
              fontSize: token.fontBodyMedium?.size ?? 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 日报板块：展示昨日宠物设备数据摘要（饮水/进食/如厕）与健康标签。
/// 数据当前为本地 mock，后续接入后端日报接口后替换即可。
class _AiDailyCard extends StatelessWidget {
  const _AiDailyCard();

  static const Color _theme = Color(0xFF7F6370);
  static const Color _titleColor = Color(0xFF3D2E33);
  static const Color _subColor = Color(0xFF9A8F93);
  static const Color _chipBg = Color(0xFFF5F1EF);

  @override
  Widget build(BuildContext context) {
    // 日期取昨日（日报对应的是昨天数据）
    final now = DateTime.now().subtract(const Duration(days: 1));
    final dateText = '${now.month}月${now.day}日 ${now.hour}:00';
    const title = '昨日饮水180ml，进食62g，如厕3次。';
    const subtitle = '基于昨日设备数据生成';
    const tags = ['饮食正常', '活动充足', '健康稳定'];

    return Container(
      // 底部 margin 4：叠加 Transform 上移的 20px，与下个板块视觉间距约 24
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：左→右主题色渐变栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF7F6370), Color(0xFF9E6F84)],
              ),
            ),
            child: Row(
              children: [
                const Text('AI日报',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const Spacer(),
                Text(dateText,
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 内容：爪印图标 + 摘要文案
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3ECEA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.pets, color: _theme, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _titleColor,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(subtitle,
                              style: TextStyle(fontSize: 12, color: _subColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 底部：健康标签 + 详情入口
                Row(
                  children: [
                    for (int i = 0; i < tags.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _chipBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tags[i],
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF7F6370))),
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // TODO: 跳转日报详情页
                      child: const Row(
                        children: [
                          Text('详情',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF7F6370))),
                          Icon(Icons.chevron_right,
                              size: 16, color: Color(0xFF7F6370)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 角标：(文字, 文字色, 背景色)。
typedef _AgentBadge = ({String label, Color fg, Color bg});

/// 单条 Agent 动态数据。
typedef _AgentData = ({
  IconData icon,
  String title,
  String time,
  List<_AgentBadge> badges,
  String body,
  String suggestion,
  String? footnote,
  String? primary,
});

/// Agent 动态板块：展示智能体推送的消息流（健康守护/饮水提醒/行为观察/饮食管理）。
/// 数据当前为本地 mock，后续接入后端 Agent 推送接口后替换即可。
class _AgentDynamicCard extends StatelessWidget {
  const _AgentDynamicCard();

  static const Color _titleColor = Color(0xFF3D2E33);

  @override
  Widget build(BuildContext context) {
    const List<_AgentData> blocks = [
      (
        icon: Icons.favorite,
        title: '健康守护',
        time: '10 分钟前',
        badges: [
          (label: '异常', fg: Color(0xFFD98A2B), bg: Color(0xFFFAEDD8)),
        ],
        body: '检测到连续两次疑似呕吐。',
        suggestion: '结合进食中断和活动下降，建议暂停下一次自动出粮，并继续观察2小时。',
        footnote: '猫砂盆影像与喂食器数据交叉发现 · 需要你的确认',
        primary: '确认开始',
      ),
      (
        icon: Icons.water_drop,
        title: '饮水提醒',
        time: '32 分钟前',
        badges: [(label: '提醒', fg: Color(0xFF7F6370), bg: Color(0xFFF3ECEA))],
        body: '下午饮水量偏少。',
        suggestion: '已切换活水模式并推送提醒，建议观察一次饮水情况。',
        footnote: null,
        primary: null,
      ),
      (
        icon: Icons.visibility,
        title: '行为观察',
        time: '1 小时前',
        badges: [(label: '正常', fg: Color(0xFF4C9A6B), bg: Color(0xFFE6F3EB))],
        body: '今天的运动量与平时一致。',
        suggestion: '活动曲线平稳，无异常行为检出，暂不需要干预。',
        footnote: null,
        primary: null,
      ),
      (
        icon: Icons.restaurant,
        title: '饮食管理',
        time: '2 小时前',
        badges: [(label: '待确认', fg: Color(0xFFE05A5A), bg: Color(0xFFFBE5E5))],
        body: '零食投喂已达上限。',
        suggestion: '今天零食热量占比接近建议上限，明天的零食额度已自动下调。',
        footnote: null,
        primary: null,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 板块标题（在白色卡片内）
          const Text('Agent 动态',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _titleColor)),
          const SizedBox(height: 10),
          // 消息块：浅色圆角小卡，块间留缝
          Column(
            children: [
              for (int i = 0; i < blocks.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _AgentBlock(data: blocks[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 单条 Agent 动态：浅色圆角卡，图标 + 标题 + 时间 + 彩色角标，
/// 加粗正文 + 白色内嵌建议卡 + 灰色脚注，底部大号操作按钮。
class _AgentBlock extends StatelessWidget {
  final _AgentData data;

  const _AgentBlock({required this.data});

  static const Color _ink = Color(0xFF262023);
  static const Color _iconBg = Color(0xFF6D4A57);
  static const Color _blockBg = Color(0xFFF4F0F1);
  static const Color _muted = Color(0xFFA8A2A4);
  static const Color _suggestionText = Color(0xFF9A8790);
  static const Color _primary = Color(0xFF9D6C80);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blockBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：图标 + 标题 + 时间 + 右侧角标
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(data.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                    ),
                    const SizedBox(width: 8),
                    Text(data.time,
                        softWrap: false,
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              for (final b in data.badges) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: b.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(b.label,
                      style: TextStyle(fontSize: 11, color: b.fg)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // 正文（字号与 AI 日报标题一致：15 / w600）
          Text(data.body,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  height: 1.4)),
          const SizedBox(height: 10),
          // 白色内嵌建议卡
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(data.suggestion,
                style: const TextStyle(
                    fontSize: 14, color: _suggestionText, height: 1.6)),
          ),
          if (data.footnote != null) ...[
            const SizedBox(height: 10),
            Text(data.footnote!,
                style: const TextStyle(fontSize: 12, color: _muted)),
          ],
          const SizedBox(height: 12),
          // 操作按钮：主按钮实心胶囊 + 问问AI 描边胶囊
          Row(
            children: [
              if (data.primary != null) ...[
                Expanded(child: _buildPrimaryButton()),
                const SizedBox(width: 10),
              ],
              Expanded(child: _buildSecondaryButton()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // TODO: 执行对应计划/确认操作
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(data.primary!,
            style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // TODO: 唤起 AI 对话
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E0E2)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF3A3A3A)),
            SizedBox(width: 6),
            Text('问问AI',
                style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF3A3A3A),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// 时间轴动态板块：按时间顺序展示设备/智能体的行为记录（带时间、圆点连线、缩略图）。
/// 数据当前为本地 mock，后续接入后端时间轴接口后替换即可。
class _TimelineCard extends StatelessWidget {
  const _TimelineCard();

  static const Color _titleColor = Color(0xFF3D2E33);

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        time: '09:30',
        title: '自动驱虫',
        desc: '咕噜肉今日自动驱虫已完成，状态正常。',
        image: null,
      ),
      (
        time: '08:15',
        title: '喂食记录',
        desc: '早间投喂主食 12g、零食 2g，符合今日计划。',
        image: null,
      ),
      (
        time: '12:30',
        title: '定时喝水',
        desc: '检测到一次饮水，饮水量达标。',
        image: null,
      ),
      (
        time: '20:10',
        title: '猫砂盆行为监测',
        desc: '如厕行为平稳，未触发异常预警。',
        image: null,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 板块标题（在白色卡片内）
          const Text('时间轴动态',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _titleColor)),
          const SizedBox(height: 6),
          Column(
            children: [
              for (int i = 0; i < items.length; i++)
                _TimelineItem(
                  data: items[i],
                  last: i == items.length - 1,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单条时间轴节点：时间 + 圆点竖线 + 内容（可选缩略图）。
class _TimelineItem extends StatelessWidget {
  final ({
    String time,
    String title,
    String desc,
    String? image,
  }) data;
  final bool last;

  const _TimelineItem({required this.data, required this.last});

  static const Color _theme = Color(0xFF7F6370);
  static const Color _titleColor = Color(0xFF3D2E33);
  static const Color _subColor = Color(0xFF9A8F93);
  static const Color _line = Color(0xFFEDE6E3);

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间列（右对齐，与圆点顶部对齐）
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(data.time,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: _subColor)),
            ),
          ),
          const SizedBox(width: 10),
          // 圆点 + 竖线
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _theme,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: _line),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 8 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _titleColor)),
                  const SizedBox(height: 3),
                  Text(data.desc,
                      style: const TextStyle(
                          fontSize: 12,
                          color: _subColor,
                          height: 1.5)),
                  if (data.image != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        data.image!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
