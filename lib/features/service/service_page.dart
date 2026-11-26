import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/chat/chat_api.dart';
import '../../core/chat/chat_models.dart';
import '../../core/http/api_client.dart';
import '../../core/user/user_state.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 客服页（对齐参考项目 f-cat 的 ServicePage）。
///
/// 纯 Flutter IM 会话，不走第三方客服 SDK：
/// - `GET  /app/chat/session/ai` 取（或自动创建）AI 会话；
/// - `POST /app/chat/messages` 分页拉历史（最新在前，reverse 列表）；
/// - `POST /app/chat/sendMsg` 发送，`type: ai|manual` 决定机器人/人工；
/// - 输入含「人工」时弹本地确认卡，确认后切到人工会话。
///
/// 相比参考项目补齐了：未登录/连接失败的明确提示与重试、发送失败 toast、
/// 空会话的快捷提问、上拉加载更早消息的自动触发。
class ServicePage extends StatefulWidget {
  const ServicePage({super.key});

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> {
  // 与「我的」页一致的设计稿色板
  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _brand = Color(0xFF7F6370);
  static const Color _accent = Color(0xFFB48CA3);
  static const Color _tagBg = Color(0xFFF6ECEF);
  static const Color _pinkText = Color(0xFFB08CA0);
  static const Color _divider = Color(0x66F1EAE4);
  static const int _pageSize = 20;

  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  int? _sessionId;
  String _sessionType = 'ai';
  final List<ChatMessage> _messages = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _initializing = true;
  String? _initError;
  bool _sending = false;

  bool get _manual => _sessionType == 'manual';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ 数据

  Future<void> _bootstrap() async {
    setState(() {
      _initializing = true;
      _initError = null;
    });
    if (!AuthService.instance.loggedIn) {
      setState(() {
        _initializing = false;
        _initError = '登录后才能咨询客服';
      });
      return;
    }
    final res = await ChatApi.getAiSession();
    if (!mounted) return;
    if (!res.isSuccess || !res.isMap || res.asMap.isEmpty) {
      setState(() {
        _initializing = false;
        _initError =
            res.message.isEmpty ? '客服连接失败，请稍后重试' : res.message;
      });
      return;
    }
    final session = ChatSession.fromJson(res.asMap);
    if (session.id <= 0) {
      setState(() {
        _initializing = false;
        _initError = '客服会话创建失败，请稍后重试';
      });
      return;
    }
    setState(() {
      _sessionId = session.id;
      _sessionType = session.sessionType;
      _messages.clear();
      _page = 1;
      _hasMore = true;
      _initializing = false;
    });
    await _loadMessages();
  }

  Future<void> _loadMessages({bool loadMore = false}) async {
    final sid = _sessionId;
    if (sid == null) return;
    if (loadMore && (!_hasMore || _loadingMore || _messages.isEmpty)) return;
    if (loadMore) setState(() => _loadingMore = true);

    final page = loadMore ? _page + 1 : 1;
    final res =
        await ChatApi.getMessages(sessionId: sid, page: page, size: _pageSize);
    if (!mounted) return;
    if (loadMore) setState(() => _loadingMore = false);

    if (!res.isSuccess) {
      if (!loadMore) {
        setState(() => _initError =
            res.message.isEmpty ? '消息加载失败，请重试' : res.message);
      }
      return;
    }
    final list = res.asList
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    setState(() {
      if (loadMore) {
        _messages.addAll(list);
      } else {
        _messages
          ..clear()
          ..addAll(list);
        _initError = null;
      }
      _page = page;
      _hasMore = list.length >= _pageSize;
    });
    _afterMessagesChanged();
  }

  /// 消息不足以撑满一屏时继续加载更早的消息（reverse 列表）。
  void _afterMessagesChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (_scrollCtrl.position.extentAfter < 120) {
        _loadMessages(loadMore: true);
      }
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.extentAfter < 120) {
      _loadMessages(loadMore: true);
    }
  }

  Future<void> _send([String? preset]) async {
    final sid = _sessionId;
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty || _sending) return;
    if (sid == null) {
      TToast.showText('客服连接中，请稍候', context: context);
      return;
    }
    _inputCtrl.clear();

    // 含「人工」：不发给 AI，先弹本地确认卡
    if (text.contains('人工') && !_manual) {
      _askTransfer();
      return;
    }

    final isAi = !_manual;
    setState(() {
      _sending = true;
      if (isAi) {
        // reverse 列表 index 0 在最底部：先占位「正在思考」，用户消息放在其上方
        _messages.insert(
          0,
          const ChatMessage(
            content: '',
            senderType: 'agent',
            kind: ChatMessageKind.loading,
          ),
        );
      }
      _messages.insert(
        isAi ? 1 : 0,
        ChatMessage(
          content: text,
          senderType: 'user',
          createTime: DateTime.now(),
        ),
      );
    });
    _toBottom();

    final res = await ChatApi.sendMessage(
      sessionId: sid,
      content: text,
      type: _sessionType,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    final loadingIdx =
        _messages.indexWhere((m) => m.kind == ChatMessageKind.loading);

    if (!res.isSuccess) {
      if (loadingIdx >= 0) {
        setState(() => _messages.removeAt(loadingIdx));
      }
      TToast.showText(
        res.message.isEmpty ? '发送失败，请重试' : res.message,
        context: context,
      );
      return;
    }

    final reply = _extractReply(res);
    setState(() {
      if (loadingIdx >= 0) {
        if (reply != null) {
          _messages[loadingIdx] = reply;
        } else {
          _messages.removeAt(loadingIdx);
        }
      } else if (reply != null) {
        _messages.insert(0, reply);
      }
    });
    _toBottom();
  }

  /// 从 sendMsg 响应里取客服回复（data 可能是对象或数组）。
  ChatMessage? _extractReply(ApiResponse res) {
    if (res.data is List) {
      ChatMessage? reply;
      for (final item in res.data as List) {
        if (item is Map<String, dynamic>) {
          final msg = ChatMessage.fromJson(item);
          if (!msg.isMine && msg.kind == ChatMessageKind.text) reply = msg;
        }
      }
      return reply;
    }
    if (res.isMap && res.asMap.isNotEmpty) {
      final msg = ChatMessage.fromJson(res.asMap);
      if (!msg.isMine && msg.kind == ChatMessageKind.text) return msg;
    }
    return null;
  }

  /// 插入/聚焦「转人工」确认卡。
  void _askTransfer() {
    if (_manual) {
      TToast.showText('当前已在人工客服会话中', context: context);
      return;
    }
    final exists = _messages.any(
        (m) => m.kind == ChatMessageKind.transferConfirm && !m.confirmed);
    if (!exists) {
      setState(() => _messages.insert(
            0,
            const ChatMessage(
              content: '',
              senderType: 'agent',
              kind: ChatMessageKind.transferConfirm,
            ),
          ));
    }
    _toBottom();
  }

  void _confirmTransfer() {
    setState(() {
      _sessionType = 'manual';
      final idx = _messages.indexWhere(
          (m) => m.kind == ChatMessageKind.transferConfirm && !m.confirmed);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(confirmed: true);
      }
      _messages.insert(
        0,
        const ChatMessage(
          content: '已为您转接人工客服，请描述您的问题，稍候片刻～',
          senderType: 'agent',
        ),
      );
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('客服'),
          useDefaultBack: true,
          useSafeArea: true,
          actions: [
            TNavBarItem(
              onTap: _askTransfer,
              padding: const EdgeInsets.only(right: 12),
              customWidget: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _tagBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.headset_mic_outlined,
                        size: 13, color: _pinkText),
                    const SizedBox(width: 4),
                    Text(_manual ? '人工中' : '转人工',
                        style:
                            const TextStyle(fontSize: 12, color: _pinkText)),
                  ],
                ),
              ),
            ),
          ],
        ),
        // 点消息区域收起键盘；输入栏放到手势区域之外，
        // 否则外层的 onTap 会抢走 TextField 的点击，导致输入框无法聚焦
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: _buildBody(userState),
              ),
            ),
            if (!_initializing && _initError == null && _sessionId != null)
              _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(UserState userState) {
    if (_initializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(height: 12),
            Text('正在连接客服…',
                style: TextStyle(fontSize: 13, color: _sub)),
          ],
        ),
      );
    }
    if (_initError != null && _messages.isEmpty) {
      return _buildError(_initError!);
    }
    if (_messages.isEmpty) {
      return _buildWelcome();
    }

    final total = _messages.length + (_loadingMore ? 1 : 0);
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: total,
      itemBuilder: (context, index) {
        // reverse：末尾是视觉上的顶部（加载更早消息的指示）
        if (index >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final msg = _messages[index];
        // 列表倒序：上一条（更早）在 index+1
        final prev = index + 1 < _messages.length ? _messages[index + 1] : null;
        final continuous = prev != null &&
            prev.kind == ChatMessageKind.text &&
            msg.kind == ChatMessageKind.text &&
            prev.senderType == msg.senderType;
        return _MessageItem(
          message: msg,
          continuous: continuous,
          avatarUrl: userState.avatarUrl,
          userName: userState.username,
          onConfirmTransfer: _confirmTransfer,
        );
      },
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _tagBg,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.wifi_off_rounded,
                size: 28, color: _pinkText),
          ),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _sub)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _bootstrap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_brand, _accent]),
                borderRadius: BorderRadius.circular(20),
              ),
              // 同上：用 Center(widthFactor: 1) 而不是 Container.alignment，
              // 避免按钮被撑到整行宽
              child: const Center(
                widthFactor: 1,
                child: Text('重新连接',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    const questions = [
      '怎么绑定我的设备？',
      '设备显示离线怎么办？',
      '我想转人工客服',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_brand, _accent]),
            ),
            alignment: Alignment.center,
            child:
                const Icon(Icons.support_agent, size: 32, color: Colors.white),
          ),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text('你好，我是 AI 客服',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink)),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('设备使用、订单售后都可以问我\n需要人工服务时回复「人工」即可',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _sub, height: 1.6)),
        ),
        const SizedBox(height: 24),
        for (final q in questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _send(q),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(q,
                          style: const TextStyle(
                              fontSize: 13, color: _ink)),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: _sub),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              // 高度由 TextField 自己撑：isCollapsed + 上下各 10 内边距，
              // 单行正好 40 与发送按钮等高。不要给 Container 设 alignment，
              // 否则它会撑满 maxHeight；也不要给 Container 加内边距，
              // 否则输入框只占中间一条、边缘点不到。
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 104),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F1EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 14, height: 1.4, color: _ink),
                  decoration: InputDecoration(
                    hintText: _manual ? '正在与人工客服对话' : '请输入问题，AI 客服为您解答',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: _sub),
                    // TDesign 主题默认给输入框加了下划线，需逐状态关掉
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    // isCollapsed 去掉 InputDecorator 默认最小高度
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : () => _send(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_brand, _accent]),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_upward_rounded,
                        size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条消息：客服/自己气泡、时间、头像；含 loading 与转人工确认卡。
class _MessageItem extends StatelessWidget {
  const _MessageItem({
    required this.message,
    required this.continuous,
    required this.onConfirmTransfer,
    this.avatarUrl,
    this.userName = '我',
  });

  final ChatMessage message;
  final bool continuous;
  final VoidCallback onConfirmTransfer;
  final String? avatarUrl;
  final String userName;

  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _brand = Color(0xFF7F6370);
  static const Color _accent = Color(0xFFB48CA3);

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    if (message.kind == ChatMessageKind.transferConfirm) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AgentAvatar(),
            const SizedBox(width: 10),
            Flexible(
              child: _bubble(
                isMine: false,
                continuous: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('是否确认转接人工客服？',
                        style:
                            TextStyle(fontSize: 14, color: _ink, height: 1.5)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: message.confirmed ? null : onConfirmTransfer,
                      // 不要用 Container.alignment：它会让按钮撑满整行宽度，
                      // 这里用 Center(widthFactor: 1) 收缩到文字宽度
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: message.confirmed
                              ? null
                              : const LinearGradient(
                                  colors: [_brand, _accent]),
                          color: message.confirmed
                              ? const Color(0xFFF1ECE9)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            message.confirmed ? '已确认' : '确认转人工',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: message.confirmed ? _sub : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (message.kind == ChatMessageKind.loading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AgentAvatar(),
            const SizedBox(width: 10),
            _bubble(
              isMine: false,
              continuous: false,
              child: const _TypingDots(),
            ),
            const Spacer(),
          ],
        ),
      );
    }

    final time = _formatTime(message.createTime);
    final bubble = Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _bubble(
          isMine: isMine,
          continuous: continuous,
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isMine ? Colors.white : _ink,
            ),
          ),
        ),
        if (time.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(time,
                style: const TextStyle(fontSize: 10, color: _sub)),
          ),
      ],
    );

    // 气泡最大占屏宽 72%，靠 Row 的对齐控制左右，避免被 Spacer 挤成半宽
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;
    return Padding(
      padding: EdgeInsets.only(top: continuous ? 4 : 10, bottom: 2),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            const _AgentAvatar(),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: bubble,
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 10),
            _MyAvatar(url: avatarUrl, name: userName),
          ],
        ],
      ),
    );
  }

  Widget _bubble({
    required bool isMine,
    required bool continuous,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? null : Colors.white,
        gradient:
            isMine ? const LinearGradient(colors: [_brand, _accent]) : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(!isMine && !continuous ? 4 : 16),
          bottomRight: Radius.circular(isMine && !continuous ? 4 : 16),
        ),
        boxShadow: isMine
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF8E6B84).withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final dt = time.toLocal();
    final now = DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final sameDay = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    return sameDay ? '$hh:$mm' : '${dt.month}/${dt.day} $hh:$mm';
  }
}

/// 客服头像：品牌渐变圆 + 客服图标。
class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7F6370), Color(0xFFB48CA3)],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.support_agent, size: 19, color: Colors.white),
    );
  }
}

/// 自己的头像：网络头像优先，否则品牌色圆 + 昵称首字。
class _MyAvatar extends StatelessWidget {
  const _MyAvatar({this.url, this.name = '我'});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final u = url;
    final first = name.runes.isEmpty
        ? '我'
        : String.fromCharCode(name.runes.first);
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF1E7EA),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: (u != null && u.startsWith('http'))
          ? Image.network(
              u,
              width: 34,
              height: 34,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initial(first),
            )
          : _initial(first),
    );
  }

  Widget _initial(String first) {
    return Text(first,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7F6370)));
  }
}

/// 「正在思考」三点跳动。
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i * 0.2) % 1.0;
            final scale = 0.7 + 0.3 * (1 - (phase - 0.5).abs() * 2);
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
              child: Transform.translate(
                offset: Offset(0, -2 * scale + 1),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFB08CA0).withValues(alpha: scale),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
