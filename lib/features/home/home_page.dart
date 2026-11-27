import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/pet/pet_state.dart';
import '../../shared/widgets/pet_header_row.dart';
import 'ai_daily_detail_page.dart';

/// 首页：顶部沉浸式宠物视频区（全宽、延伸到状态栏后面），
/// 切换条叠加在视频之上；其余内容待填充。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  /// 视频底色驱动的页面背景色；初始给一个暖灰底色，避免首屏白闪，
  /// 待封面/视频取色后更新为视频真实底色。
  Color? _bgColor = const Color(0xFFEFE9E6);
  final ScrollController _scrollCtrl = ScrollController();

  /// 头图是否已锁定为全屏：使劲下拉越过阈值后置位，松手回弹也不还原。
  bool _heroLocked = false;

  /// 全屏锁定时累计的拖动位移：上滑超过阈值即退出（不依赖滑动速度）。
  double _heroLockDragDy = 0;

  /// 头图展开的过渡动画（0 = 正常头图高度，1 = 铺满整屏）。
  /// 锁定瞬间直接置 1（此刻下拉进度已是 1，无跳变），解锁时平滑收回。
  late final AnimationController _lockCtrl = AnimationController(
    vsync: this,
    duration: _kHeroLockDuration,
  );

  /// 下拉超过该距离（负向 overscroll）：头图铺满整屏并锁定。
  static const double _kHeroLockPull = _HeroParallax.expandDistance;

  /// 锁定后向上滚过该距离：退出全屏，画面收回正常头图高度。
  static const double _kHeroUnlockScroll = 8;

  /// 毛玻璃吸顶条：滚过该距离开始淡入，再滚 [_kGlassBarFadeSpan] 完全显现。
  static const double _kGlassBarShowAt = 130;
  static const double _kGlassBarFadeSpan = 80;

  /// 锁定 / 解锁的过渡时长。
  static const Duration _kHeroLockDuration = Duration(milliseconds: 240);

  /// 头图当前展开进度：0 = 正常头图高度，1 = 铺满整屏。
  /// 头图高度与内容下推距离都由它驱动，两者始终同步。
  double get _heroProgress {
    final offset = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
    return _heroExpandProgress(offset, _lockCtrl.value);
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onHeroScroll);
    // 登录后加载宠物列表与顶部展示视频
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final petState = context.read<PetState>();
      if (!petState.isLoaded) petState.loadPets();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onHeroScroll);
    _scrollCtrl.dispose();
    _lockCtrl.dispose();
    super.dispose();
  }

  /// 根据滚动位置维护头图的全屏锁定状态：
  /// 下拉够狠 → 锁定全屏；锁定后往上滚 → 退出全屏。
  void _onHeroScroll() {
    if (!_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.offset;
    if (!_heroLocked) {
      if (offset <= -_kHeroLockPull) {
        // 此刻下拉进度已到 1，直接同步锁定进度，避免跳变
        _lockCtrl.value = 1;
        setState(() => _heroLocked = true);
      }
    } else if (offset > _kHeroUnlockScroll) {
      _exitHeroFullscreen();
    }
  }

  /// 退出头图全屏：复位锁定标记，并让画面连同内容一起平滑收回原位。
  void _exitHeroFullscreen() {
    if (!_heroLocked) return;
    setState(() => _heroLocked = false);
    _lockCtrl.animateBack(
      0,
      duration: _kHeroLockDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;
    // 日报对应昨日数据（标题条与摘要卡共用同一日期）
    final now = DateTime.now().subtract(const Duration(days: 1));
    final dailyDateText = '${now.month}月${now.day}日 ${now.hour}:00';
    // 头图（视频/封面）高度：含状态栏，约占屏高 42%
    final heroH = topInset + screenH * 0.42;

    return GestureDetector(
      // 头图在内容之上（IgnorePointer），左右滑动切换宠物统一在这里处理
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity;
        if (v == null || v.abs() < 100) return;
        final pet = context.read<PetState>();
        final count = pet.pets.length;
        if (count <= 1) return;
        final idx = v < 0
            ? (pet.selectedIndex + 1) % count
            : (pet.selectedIndex - 1 + count) % count;
        if (idx != pet.selectedIndex) pet.selectPet(idx);
      },
      child: Scaffold(
        // 背景色由视频底部底色驱动，使头图与内容面板无缝衔接
        backgroundColor: _bgColor,
        body: Stack(
          children: [
            // 滚动内容（底层）：首项是头图占位，内容面板紧随其后。
            // 头图每展开一点，整块内容就被挤下去同样的距离（见 _HeroPushDown），
            // 让面板跟着头图底边一起下移，而不是被撑大的头图遮住。
            Positioned.fill(
              child: _HeroPushDown(
                scroll: _scrollCtrl,
                lock: _lockCtrl,
                distance: screenH - heroH,
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // 头图在顶层绘制，这里只撑出它的高度：
                    // 面板顶边与画面底边严格对齐，不留叠压（否则下拉/回弹时
                    // 会被撑大的头图压住一条）。
                    // 首帧 MediaQuery 高度可能为 0，必须 clamp 掉负值
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: heroH.clamp(0.0, double.infinity),
                      ),
                    ),
                    // 内容面板：圆角 + 底色，顶到最上面时盖住头图底部形成层次
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _bgColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        // 内容通栏贴边（与头图一样贯穿左右）：
                        // 顶部不留白，AI 日报标题条直接贴着上方视频；
                        // 底部 bottomInset + 76 避开胶囊 TabBar 与 AI 浮条
                        padding: EdgeInsets.fromLTRB(
                          0,
                          0,
                          0,
                          bottomInset + 76,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: _AiDailyHeader.height,
                              child: _AiDailyHeader(dateText: dailyDateText),
                            ),
                            // 摘要卡整块直角，与标题条拼成一张
                            const _AiDailySummary(),
                            const SizedBox(height: 12),
                            const _AgentDynamicCard(),
                            const SizedBox(height: 12),
                            const _TimelineCard(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 头图（顶层）：随滚动上移被内容推走，下拉时由顶部撑满整屏，
            // 使劲下拉越过阈值后锁定全屏（松手不回弹）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroH,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_scrollCtrl, _lockCtrl]),
                  child: _HeroVideo(
                    // 头图比可视区更大，给视差与下拉放大留出余量
                    height: heroH * _kHeroOverscan,
                    bgColor: _bgColor,
                    onColorExtracted: (c) => setState(() => _bgColor = c),
                  ),
                  builder: (context, child) => _HeroParallax(
                    offset: _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0,
                    progress: _heroProgress,
                    height: heroH,
                    fullHeight: screenH,
                    child: child!,
                  ),
                ),
              ),
            ),
            // 全屏锁定时的交互层：点画面任意处、或上滑都能退出全屏；
            // 内容可滚动处仍由滚动视图接管拖动，不会互相干扰。
            // 同时吃掉点击，避免误触被画面盖住的卡片（那些卡片此时不可见）
            if (_heroLocked)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _exitHeroFullscreen,
                  onVerticalDragStart: (_) => _heroLockDragDy = 0,
                  onVerticalDragUpdate: (details) {
                    _heroLockDragDy += details.delta.dy;
                    if (_heroLockDragDy < -24) _exitHeroFullscreen();
                  },
                ),
              ),
            // 全屏气泡问候：暂时停用（组件保留，取消注释即可恢复）
            // if (_heroLocked)
            //   Positioned.fill(
            //     child: IgnorePointer(
            //       child: _HeroChatBubble(topInset: topInset),
            //     ),
            //   ),
            // 顶部宠物切换条：首屏浮在头图上，向下滚动时淡出退场（交给内容）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scrollCtrl,
                builder: (context, child) {
                  final offset = _scrollCtrl.hasClients
                      ? _scrollCtrl.offset
                      : 0.0;
                  final t = (offset / 140).clamp(0.0, 1.0);
                  return IgnorePointer(
                    ignoring: t >= 1,
                    child: Opacity(opacity: 1 - t, child: child),
                  );
                },
                child: _PetSwitchBar(topInset: topInset),
              ),
            ),
            // 滚动后的毛玻璃吸顶条：接住淡出的顶部切换条，
            // 让内容滚上来时顶部仍有导航，也避免文字直接压到状态栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scrollCtrl,
                child: _GlassTopBar(topInset: topInset),
                builder: (context, child) {
                  final offset = _scrollCtrl.hasClients
                      ? _scrollCtrl.offset
                      : 0.0;
                  // 与切换条的淡出（offset/140）接力，错开一点避免叠影
                  final t = ((offset - _kGlassBarShowAt) / _kGlassBarFadeSpan)
                      .clamp(0.0, 1.0);
                  if (t <= 0) return const SizedBox.shrink();
                  return IgnorePointer(
                    ignoring: t < 1,
                    child: Opacity(opacity: t, child: child),
                  );
                },
              ),
            ),
            // 底部 AI 问答浮条：与健康页/宠物页一致，紧贴胶囊 TabBar 上方
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + 8,
              child: const _AiBar(),
            ),
            // 视频全屏时，内容列表被推到屏幕外：把 AI 日报与最新一条 Agent 动态
            // 压成一张小卡贴在视频上，点一下即退出全屏回看完整内容
            Positioned(
              left: 16,
              right: 16,
              // 问答条（48 高 + 8 底距）上方再留 12
              bottom: bottomInset + 68,
              child: IgnorePointer(
                ignoring: !_heroLocked,
                child: AnimatedOpacity(
                  opacity: _heroLocked ? 1 : 0,
                  duration: _kHeroLockDuration,
                  curve: Curves.easeOut,
                  child: _HeroInsightPanel(
                    dateText: dailyDateText,
                    onTap: _exitHeroFullscreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 头图视差时的放大倍数：比可视区大 25%，为视差位移留出上下余量。
const double _kHeroOverscan = 1.25;

/// 头图画面的「出血」量：画面本体比可见区域稍大一圈，
/// 让画面边缘始终落在屏幕外，避免四边出现缝隙或杂边。
const double _kBleed = 8;

/// 头图展开进度：0 = 正常头图高度，1 = 铺满整屏。
/// 取「下拉距离」与「锁定动画」的较大值，锁定后即使 overscroll 回弹到 0
/// 也保持 1（这就是"固定全屏"）。
double _heroExpandProgress(double offset, double lockT) {
  final pull = (-offset / _HeroParallax.expandDistance).clamp(0.0, 1.0);
  return math.max(pull, lockT);
}

/// 内容整体跟随头图下推：头图展开多少，整块内容就被挤下去多少，
/// 面板因此始终紧贴头图底边，而不会停留在原处被撑大的头图遮住。
class _HeroPushDown extends StatelessWidget {
  const _HeroPushDown({
    required this.scroll,
    required this.lock,
    required this.distance,
    required this.child,
  });

  final ScrollController scroll;

  /// 锁定进度（0..1），解锁收起时用来平滑回位。
  final Animation<double> lock;

  /// 从正常头图高度铺满整屏还需要增加的高度。
  final double distance;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scroll, lock]),
      // child 复用，滚动/展开过程中不会重建整个滚动内容
      child: child,
      builder: (context, child) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        final progress = _heroExpandProgress(offset, lock.value);
        // 下拉时滚动视图自身已经把整块内容下移了 |offset|（overscroll 弹性），
        // 这部分必须扣掉，只补足「让面板紧贴头图底边」所需的剩余位移；
        // 否则两者叠加会让面板与头图之间被拉开一段随下拉变大的空隙。
        // 面板顶边始终跟着画面底边走：下拉时扣掉 overscroll 已经带来的位移
        final push = offset < 0
            ? math.max(0.0, distance * progress + offset)
            : distance * lock.value;
        return Transform.translate(offset: Offset(0, push), child: child);
      },
    );
  }
}

/// 头图视差层：随页面滚动让画面"慢半拍"上移；
/// 下拉时头图钉在顶部，画面底边一路延伸到屏幕底部；
/// 力度够大（越过 [expandDistance]）时由外层锁定，松手也不回弹。
///
/// 宽度说明：画面盒子恒定铺满屏宽，只按需要变高、底边对齐到目标高度，
/// 所以下拉过程中横向始终是满的，不会出现左右留白。
class _HeroParallax extends StatelessWidget {
  const _HeroParallax({
    required this.offset,
    required this.progress,
    required this.height,
    required this.fullHeight,
    required this.child,
  });

  /// 当前滚动偏移（< 0 表示下拉 overscroll）。
  final double offset;

  /// 展开进度（0..1），由外层结合锁定状态给出，与内容下推共用同一份。
  final double progress;

  /// 头图在页面里占的可视高度。
  final double height;

  /// 整屏高度：下拉展开时画面最多铺到这里。
  final double fullHeight;

  /// 实际内容层（高度应为 `height * _kHeroOverscan`）。
  final Widget child;

  /// 视差系数：滚动 1px 画面只上移 (1 - 系数)，
  /// 位移上限（滚动到 height 时）为 0.12 * height，小于 0.125 * height 的余量。
  static const double _factor = 0.12;

  /// 下拉多少像素后画面铺满整屏（"使劲下拉"的力度，也是锁定阈值）。
  static const double expandDistance = 170;

  @override
  Widget build(BuildContext context) {
    // 首帧 MediaQuery 可能还没就绪（高度为 0），此时不绘制，避免除零
    if (height <= 0 || fullHeight <= 0) return const SizedBox.shrink();
    final screenW = MediaQuery.sizeOf(context).width;

    // 头图盒子随正常滚动 1:1 上移（下拉时钉在顶部不动）
    final boxDy = offset > 0 ? -offset : 0.0;
    final expanded = progress > 0;

    final contentH = height * _kHeroOverscan;
    // 画面底边要落到的位置：从头图底边一路推到屏幕底部
    final visibleH = height + (fullHeight - height) * progress;
    // 画面盒子始终「铺满整宽」，只按需要变高：
    // 高度取 overscan 与展开高度中的较大值，底边对齐 visibleH，
    // 因此宽度恒为屏宽（不会出现左右留白），也不需要缩放视频层。
    // 出血只加在顶部与左右（底部要与内容面板严丝合缝地相接），
    // 让画面边缘落在屏幕外，避免贴边处露出背景色缝隙。
    final boxH = math.max(contentH, visibleH) + _kBleed * 2;
    // 展开时把底边对齐到 visibleH（顶部靠 overscan 余量兜住）；
    // 正常滚动时画面比页面慢半拍，形成视差
    final dy = expanded ? visibleH - height : offset * _factor;

    return Transform.translate(
      offset: Offset(0, boxDy),
      child: ClipRect(
        // 展开时放开裁剪区（否则向屏幕底部撑开的画面会被裁掉），
        // 其余时候裁到盒子内，避免画面盖住下方内容
        clipper: _HeroClip(stretch: expanded),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: SizedBox(
                height: boxH,
                width: screenW + _kBleed * 2,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 头图裁剪器：下拉时放开边界（画面撑满整屏），
/// 其余时候裁到盒子内，避免画面溢出盖住下方内容。
class _HeroClip extends CustomClipper<Rect> {
  const _HeroClip({required this.stretch});

  final bool stretch;

  @override
  Rect getClip(Size size) => stretch
      ? Rect.fromLTRB(0, -size.height * 2, size.width, size.height * 5)
      : Rect.fromLTRB(0, 0, size.width, size.height);

  @override
  bool shouldReclip(covariant _HeroClip oldClipper) =>
      oldClipper.stretch != stretch;
}

/// 顶部视频区：全宽通栏、从屏幕最顶端（含状态栏）铺下来，无圆角。
/// 视频地址来自后端「宠物展示信息」接口（/app/pet/show 的 mediaUrl）。
/// 未查询到视频或视频未就绪时显示封面图（接口 imgUrl，无则本地
/// group-1.png 兜底），视频就绪后封面淡出、media_kit 静音循环播放。
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

  /// 切换宠物序号：用于丢弃上一个宠物遗留的异步回调（open / 取色）。
  int _openSeq = 0;
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
      // 只接受「当前已打开的视频 == 当前选中宠物视频」的首帧，
      // 避免切换宠物过程中旧视频的宽高事件提前把旧画面淡入。
      final url = _petState?.mediaUrl;
      final matches = _openedUrl != null && _openedUrl == url;
      if (w != null && w > 0 && mounted && !_ready && matches) {
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
    final seq = _openSeq;
    try {
      // 略等一帧，确保画面已渲染
      await Future.delayed(const Duration(milliseconds: 200));
      // 期间已切换宠物：丢弃旧宠物的取色结果
      if (!mounted || seq != _openSeq) return;
      final bytes = await _player!.screenshot();
      if (bytes == null || !mounted || seq != _openSeq) return;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null || !mounted) return;
      final color = _averageBottom(
        data.buffer.asUint32List(),
        image.width,
        image.height,
      );
      if (color != null) widget.onColorExtracted?.call(color);
    } catch (e) {
      debugPrint('[HeroVideo] extractColor error: $e');
    }
  }

  /// 从封面网络图取底部平均色，作为视频就绪前的页面底色（避免首屏白闪）。
  Future<void> _extractColorFromImage(String url, int seq) async {
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
      if (!mounted || seq != _openSeq) return;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null || !mounted || seq != _openSeq) return;
      final color = _averageBottom(
        data.buffer.asUint32List(),
        img.width,
        img.height,
      );
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
    final seq = ++_openSeq;
    // 先用封面图取底色：首屏 / 视频未就绪时即已有底色，避免白闪
    if (cover != null && cover.isNotEmpty) _extractColorFromImage(cover, seq);
    debugPrint('[HeroVideo] onPetChanged mediaUrl=$url');
    // 当前宠物无视频：停掉播放、回退封面
    if (url == null || url.isEmpty) {
      _openedUrl = null;
      _player!.pause();
      // 必须退回封面，否则切换后顶部仍停着上一个宠物的画面
      if (_ready) setState(() => _ready = false);
      return;
    }
    if (_openedUrl != url) {
      _openedUrl = url;
      // 切换瞬间先回退封面，等新视频首帧就绪再淡入，避免新旧画面串台
      if (_ready) setState(() => _ready = false);
      // 不重置比例：盒子高度始终沿用视频高度，图片态也保持同一高度，避免跳动。
      _player!
          .open(Media(url))
          .then((_) {
            // 已被后续切换覆盖：丢弃本次 open 结果
            if (seq != _openSeq || !mounted) return;
            debugPrint('[HeroVideo] open ok, play');
            _updateAspect();
            _extractColor();
            _player!.play();
          })
          .catchError((e) {
            // 播放失败：退回封面图
            debugPrint('[HeroVideo] open error: $e');
            if (seq == _openSeq && mounted) setState(() => _ready = false);
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
                          'assets/images/group-1.png',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        'assets/images/group-1.png',
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
  final double topInset;
  const _PetSwitchBar({required this.topInset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topInset + 8,
        left: 16,
        right: 16,
        bottom: 10,
      ),
      // 宠物名（可点切换）与右侧消息铃铛，与吸顶条共用同一个组件；
      // 这里压在视频上，用两颗玻璃胶囊和统一色系保证可读
      child: const PetHeaderRow(
        pill: true,
        titleColor: Color(0xFF2E2A2C),
        arrowColor: Color(0xFF2E2A2C),
        titleFontSize: 14,
        titleFontWeight: FontWeight.w600,
        bellSize: 20,
        bellColor: Color(0xFF2E2A2C),
      ),
    );
  }
}

/// 滚动后的毛玻璃吸顶条：模糊背后的内容，顶部始终保留宠物切换与消息入口，
/// 同时把状态栏区域盖住，避免内容文字直接压到时间/电量上。
class _GlassTopBar extends StatelessWidget {
  const _GlassTopBar({required this.topInset});

  final double topInset;

  /// 内容行高度（不含状态栏）：等于未滚动时的 8 + 36 + 8，
  /// 让毛玻璃条接管时文字与图标不发生纵向跳动。
  static const double contentHeight = 52;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        // 比底部 TabBar 更重一点的模糊：作为导航层，需要把内容先化开
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: topInset + contentHeight,
          padding: EdgeInsets.only(top: topInset, left: 16, right: 16),
          decoration: BoxDecoration(
            // 与 TabBar 同一套玻璃，只是略实一点拉开层级
            color: Colors.white.withValues(alpha: 0.62),
            border: Border(
              // 底部用一道细白高光收边，替掉原来的硬黑分割线
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.55),
                width: 0.8,
              ),
            ),
          ),
          // 与透明切换条完全同款内容：字色、字号、箭头、铃铛都不变，
          // 滚动时胶囊底消融成这条毛玻璃，内容本身不跳
          child: const PetHeaderRow(
            titleColor: Color(0xFF2E2A2C),
            arrowColor: Color(0xFF2E2A2C),
            titleFontSize: 14,
            titleFontWeight: FontWeight.w600,
            bellSize: 20,
            bellColor: Color(0xFF2E2A2C),
          ),
        ),
      ),
    );
  }
}

/// 不规则气泡形状：四角半径各不相同，底部再挑一个小尾巴，
/// 用来替代千篇一律的圆角矩形。
class _BubbleShape {
  const _BubbleShape._();

  /// 尾巴凸出的高度。
  static const double tail = 8;

  static Path build(Size size, {required bool onLeft}) {
    final w = size.width;
    final bodyH = size.height - tail;
    // 四角半径不等，避免机械感
    const rtl = 22.0;
    const rtr = 15.0;
    const rbr = 19.0;
    const rbl = 13.0;
    // 尾巴靠气泡内侧，朝向画面中央的宠物
    final tailX = onLeft ? w * 0.74 : w * 0.26;

    return Path()
      ..moveTo(rtl, 0)
      ..lineTo(w - rtr, 0)
      ..quadraticBezierTo(w, 0, w, rtr)
      ..lineTo(w, bodyH - rbr)
      ..quadraticBezierTo(w, bodyH, w - rbr, bodyH)
      // 尾巴：先向内侧挑出一个尖，再收回来
      ..lineTo(tailX + 9, bodyH)
      ..quadraticBezierTo(tailX + 3, bodyH + tail - 1, tailX - 2, bodyH + tail)
      ..quadraticBezierTo(tailX - 6, bodyH + tail - 2, tailX - 8, bodyH)
      ..lineTo(rbl, bodyH)
      ..quadraticBezierTo(0, bodyH, 0, bodyH - rbl)
      ..lineTo(0, rtl)
      ..quadraticBezierTo(0, 0, rtl, 0)
      ..close();
  }
}

class _BubbleClipper extends CustomClipper<Path> {
  const _BubbleClipper({required this.onLeft});

  final bool onLeft;

  @override
  Path getClip(Size size) => _BubbleShape.build(size, onLeft: onLeft);

  @override
  bool shouldReclip(covariant _BubbleClipper oldClipper) =>
      oldClipper.onLeft != onLeft;
}

/// 给气泡描一道细白边：被裁剪后只留内侧一半，正好勾出玻璃边缘。
class _BubbleStrokePainter extends CustomPainter {
  const _BubbleStrokePainter({required this.onLeft});

  final bool onLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.65);
    canvas.drawPath(_BubbleShape.build(size, onLeft: onLeft), paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleStrokePainter oldDelegate) =>
      oldDelegate.onLeft != onLeft;
}

/// 视频全屏时的宠物气泡问候：隔几秒随机冒一句，弹出带轻微回弹，
/// 停留约 3.4s 后淡出；只做展示，不拦截点击。
class _HeroChatBubble extends StatefulWidget {
  const _HeroChatBubble({required this.topInset});

  final double topInset;

  @override
  State<_HeroChatBubble> createState() => _HeroChatBubbleState();
}

class _HeroChatBubbleState extends State<_HeroChatBubble>
    with SingleTickerProviderStateMixin {
  /// 宠物口吻的短句池，后续可换成 AI 生成的问候。
  static const List<String> _lines = <String>[
    '今天状态不错呀～',
    '铲屎官，摸摸头嘛',
    '刚喝完水，我很乖哦',
    '陪我玩一会儿？',
    '窗台上有只鸟，我盯了好久',
    '困了就先睡，我守着你',
    '今天的零食还没发呢',
    '你出门的时候，我一直在门口等',
    '记得喝水呀～',
  ];

  final math.Random _random = math.Random();

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 300),
  );

  Timer? _gapTimer;
  Timer? _holdTimer;
  String _text = '';
  bool _onLeft = true;
  double _jitter = 0;

  @override
  void initState() {
    super.initState();
    _scheduleNext(first: true);
  }

  @override
  void dispose() {
    _gapTimer?.cancel();
    _holdTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// 每隔 4.5~8.5s 冒一句，首次进全屏 0.9s 后就来。
  void _scheduleNext({bool first = false}) {
    _gapTimer?.cancel();
    final waitMs = first ? 900 : 4500 + _random.nextInt(4000);
    _gapTimer = Timer(Duration(milliseconds: waitMs), _speak);
  }

  void _speak() {
    if (!mounted) return;
    setState(() {
      _text = _lines[_random.nextInt(_lines.length)];
      // 左右交替出现，纵向再随机错开一点，避免每次都同一块位置
      _onLeft = _random.nextBool();
      _jitter = _random.nextInt(72).toDouble();
    });
    _ctrl.forward(from: 0);
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      _ctrl.reverse().whenComplete(() {
        if (mounted) _scheduleNext();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 避开顶部宠物条与画面中央的宠物脸，落在画面上部
      padding: EdgeInsets.only(
        top: widget.topInset + 92 + _jitter,
        left: 20,
        right: 20,
      ),
      child: Align(
        alignment: Alignment(_onLeft ? -1.0 : 1.0, -1.0),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value.clamp(0.0, 1.0);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 10),
                child: Transform.scale(
                  // easeOutBack 让气泡冒出来时带一点弹性
                  scale: 0.88 + 0.12 * Curves.easeOutBack.transform(t),
                  alignment: _onLeft
                      ? Alignment.bottomLeft
                      : Alignment.bottomRight,
                  child: _bubble(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bubble() {
    return ClipPath(
      // 不规则气泡：四角半径不等，底部那颗小尾巴指向宠物
      clipper: _BubbleClipper(onLeft: _onLeft),
      child: BackdropFilter(
        // 与问答条/信息块同一套磨砂，视频画面能透上来
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: CustomPaint(
          foregroundPainter: _BubbleStrokePainter(onLeft: _onLeft),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 232),
            padding: const EdgeInsets.fromLTRB(
              14,
              11,
              14,
              11 + _BubbleShape.tail,
            ),
            decoration: BoxDecoration(
              // 上亮下柔的磨砂白，边缘自然过渡到透明玻璃
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.74),
                  Colors.white.withValues(alpha: 0.52),
                ],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pets, size: 13, color: Color(0xFFB2708A)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _text,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.32,
                      color: Color(0xFF3D2E33),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 视频全屏时贴在画面底部的小信息块：把 AI 日报摘要与最新一条 Agent 动态
/// 压成一张玻璃卡，避免全屏时完全看不到当天数据；点整块退出全屏看完整内容。
/// 文案与 [_AiDailySummary] / [_AgentDynamicCard] 里的 mock 保持一致。
class _HeroInsightPanel extends StatelessWidget {
  const _HeroInsightPanel({required this.dateText, required this.onTap});

  final String dateText;
  final VoidCallback onTap;

  static const Color _title = Color(0xFF3D2E33);
  static const Color _body = Color(0xFF5C4A50);
  static const Color _sub = Color(0xFF9A8F93);
  static const Color _warn = Color(0xFFD98A2B);
  static const Color _brand = Color(0xFF7F6370);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          // 与底部问答条同一套玻璃，让视频画面透上来
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI 日报：标题 + 日期 + 展开入口
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: _brand),
                    const SizedBox(width: 6),
                    const Text(
                      'AI 日报',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _title,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateText,
                      style: const TextStyle(fontSize: 11, color: _sub),
                    ),
                    const Spacer(),
                    const Text(
                      '展开',
                      style: TextStyle(fontSize: 11, color: _brand),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: _brand,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '昨日饮水180ml，进食62g，如厕3次。',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, height: 1.25, color: _body),
                ),
                const SizedBox(height: 9),
                Container(
                  height: 0.8,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 9),
                // 最新一条 Agent 动态
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _warn,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '健康守护',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _title,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '10 分钟前',
                      style: TextStyle(fontSize: 10.5, color: _sub),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '检测到连续两次疑似呕吐',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11.5, color: _body),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部 AI 问答浮条：与底部 TabBar 共用同一套玻璃材质（模糊 + 淡白 + 细白边），
/// 避免全屏视频时白卡片与玻璃导航之间出现断层；
/// 麦克风/发送图标复用项目资源图（voice-ico.png / send-ico.png）。
class _AiBar extends StatelessWidget {
  const _AiBar();

  static const Color _brand = Color(0xFF7F6370);

  /// 占位文字：比原来的浅灰深两档，保证压在玻璃上、背后画面偏暗时依然读得清。
  static const Color _placeholder = Color(0xFF6B5E63);

  /// 高度 48，圆角取一半，两端与 TabBar 同款胶囊。
  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_height / 2);
    return DecoratedBox(
      // 阴影放在裁剪层之外，避免被 ClipRRect 切掉
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F3D2E33),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          // 与 TabBar 同样的模糊；底色略实一点，保证输入框里的字始终清楚
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: _height,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: _brand),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '有什么问题都可以问我~',
                    // 玻璃底会随背后的视频变暗，占位文字要比 _sub 更深才稳
                    style: TextStyle(fontSize: 13, color: _placeholder),
                  ),
                ),
                Image.asset(
                  'assets/images/icon/voice-ico.png',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _brand,
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/icon/send-ico.png',
                    width: 18,
                    height: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AI日报渐变标题条（随内容一起滚动，不再吸顶）。
class _AiDailyHeader extends StatelessWidget {
  const _AiDailyHeader({required this.dateText});

  /// 标题条固定高度（padding 12*2 + 文字约 18）
  static const double height = 42;

  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      // 无圆角：标题背景保持直角
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF7F6370), Color(0xFF9E6F84)],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'AI日报',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Text(
            dateText,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// AI 日报摘要区：展示昨日宠物设备数据摘要（饮水/进食/如厕）与健康标签。
/// 标题条已拆为独立吸顶组件 [_AiDailyHeader]，这里只保留白色摘要卡。
class _AiDailySummary extends StatelessWidget {
  const _AiDailySummary();

  static const Color _theme = Color(0xFF7F6370);
  static const Color _titleColor = Color(0xFF3D2E33);
  static const Color _subColor = Color(0xFF9A8F93);
  static const Color _chipBg = Color(0xFFF5F1EF);

  @override
  Widget build(BuildContext context) {
    const title = '昨日饮水180ml，进食62g，如厕3次。';
    const subtitle = '基于昨日设备数据生成';
    const tags = ['饮食正常', '活动充足', '健康稳定'];

    return Container(
      // 顶部直角与标题条拼成一张，底部保留圆角收口
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        // 顶部留白：标题条已改为直角背景，内容需与标题拉开距离
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _titleColor,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: _subColor),
                      ),
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
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _chipBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tags[i],
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7F6370),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiDailyDetailPage(),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        '详情',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7F6370),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFF7F6370),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 角标：(文字, 文字色, 背景色)。
typedef _AgentBadge = ({String label, Color fg, Color bg});

/// 单条 Agent 动态数据。
typedef _AgentData = ({
  IconData icon,
  String? iconAsset,
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
        iconAsset: 'assets/images/icon/agent-ico-1.png',
        title: '健康守护',
        time: '10 分钟前',
        badges: [(label: '异常', fg: Color(0xFFD98A2B), bg: Color(0xFFFAEDD8))],
        body: '检测到连续两次疑似呕吐。',
        suggestion: '结合进食中断和活动下降，建议暂停下一次自动出粮，并继续观察2小时。',
        footnote: '猫砂盆影像与喂食器数据交叉发现 · 需要你的确认',
        primary: '确认开始',
      ),
      (
        icon: Icons.water_drop,
        iconAsset: null,
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
        iconAsset: null,
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
        iconAsset: null,
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
          const Text(
            'Agent 动态',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
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
              data.iconAsset != null
                  ? Image.asset(
                      data.iconAsset!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    )
                  : Container(
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
                      child: Text(
                        data.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data.time,
                      softWrap: false,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              for (final b in data.badges) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: b.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    b.label,
                    style: TextStyle(fontSize: 11, color: b.fg),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // 正文（字号与 AI 日报标题一致：15 / w600）
          Text(
            data.body,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          // 白色内嵌建议卡
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              data.suggestion,
              style: const TextStyle(
                fontSize: 13,
                color: _suggestionText,
                height: 1.6,
              ),
            ),
          ),
          if (data.footnote != null) ...[
            const SizedBox(height: 10),
            Text(
              data.footnote!,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
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
        child: Text(
          data.primary!,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/icon/agent-ico-2.png',
              width: 16,
              height: 16,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 6),
            Text(
              '问问AI',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF3A3A3A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 时间线动态数据。
class _TimelineData {
  final String time;
  final String source; // 来源说明（时间行右侧灰字）
  final String icon; // 标题行小图标资源
  final String title;
  final String desc;
  final List<({String image, bool video})> media; // 缩略图（video=true 显示播放按钮/角标）
  const _TimelineData({
    required this.time,
    required this.source,
    required this.icon,
    required this.title,
    required this.desc,
    this.media = const [],
  });
}

/// 时间线动态板块：按时间顺序展示设备/智能体的行为记录
/// （环形圆点 + 虚线时间轴；时间行/图标标题行/描述/照片与视频缩略图）。
/// 数据当前为本地 mock，后续接入后端时间轴接口后替换即可。
class _TimelineCard extends StatelessWidget {
  const _TimelineCard();

  static const Color _titleColor = Color(0xFF3D2E33);

  @override
  Widget build(BuildContext context) {
    const items = [
      _TimelineData(
        time: '08:30',
        source: '来自喂食器 A',
        icon: 'assets/images/icon/f-ico-1.png',
        title: '自动出粮',
        desc: '喂食器A仓自动出粮2份',
      ),
      _TimelineData(
        time: '08:35',
        source: '来自 喂食器摄像头·实时捕捉',
        icon: 'assets/images/icon/f-ico-1.png',
        title: '超级神虎 进食',
        desc: '进食持续3分钟，进食量20g',
        media: [
          (image: 'assets/images/group-1.png', video: false),
          (image: 'assets/images/group-1.png', video: true),
        ],
      ),
      _TimelineData(
        time: '12:10',
        source: '来自 饮水机摄像头·实时捕捉',
        icon: 'assets/images/icon/f-ico-1.png',
        title: '超级神虎 饮水',
        desc: '饮水机记录饮水约50ml',
        media: [(image: 'assets/images/group-1.png', video: true)],
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
          const Text(
            '时间线动态',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (int i = 0; i < items.length; i++)
                _TimelineItem(data: items[i], last: i == items.length - 1),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单条时间线节点：环形圆点 + 虚线 + 内容（时间行/标题行/描述/缩略图）。
class _TimelineItem extends StatelessWidget {
  final _TimelineData data;
  final bool last;

  const _TimelineItem({required this.data, required this.last});

  static const Color _theme = Color(0xFF7F6370);
  static const Color _titleColor = Color(0xFF3D2E33);
  static const Color _subColor = Color(0xFF9A8F93);
  static const Color _line = Color(0xFFE3D9D4);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TimelineAxisPainter(
        dotColor: _theme,
        lineColor: _line,
        drawLine: !last,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间轴占位：9 圆点 + 12 间距（圆点与虚线由 painter 画在背景上）
          const SizedBox(width: 21),
          // 内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 8 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间行：时钟图标 + 时间 + 来源
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/icon/time-ico.png',
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        data.time,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _subColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 标题行：小图标 + 标题
                  Row(
                    children: [
                      Image.asset(data.icon, width: 18, height: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _titleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _subColor,
                      height: 1.5,
                    ),
                  ),
                  if (data.media.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _MediaRow(media: data.media),
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

/// 缩略图行：每张约半宽展示，含「照片/视频」角标；视频带居中播放按钮。
class _MediaRow extends StatelessWidget {
  final List<({String image, bool video})> media;
  const _MediaRow({required this.media});

  static const Color _mask = Color(0x59000000); // 半透明黑蒙层

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 单张也按半宽展示（与设计稿一致），两张则并排铺满
        final w = (constraints.maxWidth - 8) / 2;
        return Row(
          children: [
            for (int i = 0; i < media.length && i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _thumb(media[i], w),
            ],
          ],
        );
      },
    );
  }

  Widget _thumb(({String image, bool video}) m, double w) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(m.image, width: w, height: 92, fit: BoxFit.cover),
        ),
        if (m.video)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _mask,
                ),
                child: Image.asset(
                  'assets/images/icon/vector-ico.png',
                  width: 10,
                  height: 10,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _mask,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              m.video ? '视频' : '照片',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// 时间轴画笔：在条目背景上绘制环形圆点与垂直虚线
/// （包在条目最外层、尺寸由内容决定，不依赖 IntrinsicHeight/Expanded，避免布局崩溃）。
class _TimelineAxisPainter extends CustomPainter {
  final Color dotColor;
  final Color lineColor;
  final bool drawLine;
  _TimelineAxisPainter({
    required this.dotColor,
    required this.lineColor,
    required this.drawLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const dotR = 4.5;
    final cx = dotR;
    final dotCy = 5 + dotR; // 顶部留 5px 再画圆点
    // 垂直虚线：从圆点下方一直画到条目底部（连向下一条的圆点）
    if (drawLine) {
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      const dash = 3.0, gap = 3.5;
      final startY = dotCy + dotR + 2;
      for (double y = startY; y < size.height; y += dash + gap) {
        canvas.drawLine(
          Offset(cx, y),
          Offset(cx, (y + dash).clamp(0.0, size.height)),
          paint,
        );
      }
    }
    // 环形圆点：白底 + 主题色描边环
    canvas.drawCircle(Offset(cx, dotCy), dotR, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(cx, dotCy),
      dotR - 0.75,
      Paint()
        ..color = dotColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineAxisPainter old) =>
      old.dotColor != dotColor ||
      old.lineColor != lineColor ||
      old.drawLine != drawLine;
}
