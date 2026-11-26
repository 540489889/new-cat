/// 客服会话与消息模型（接口对齐参考项目 f-cat 的 `/app/chat/**`）。
///
/// - `GET /app/chat/session/ai`：取（或自动创建）当前 AI 会话；
/// - `POST /app/chat/messages`：分页拉取历史消息（返回按时间倒序，最新在前）；
/// - `POST /app/chat/sendMsg`：发送消息，AI/人工由 `type` 区分；
/// - `POST /app/chat/session/close`：关闭会话。
class ChatSession {
  const ChatSession({
    required this.id,
    required this.sessionType,
    this.ragId,
  });

  final int id;

  /// `ai`（机器人）/ `manual`（人工）。
  final String sessionType;
  final String? ragId;

  bool get isManual => sessionType == 'manual';

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: _toInt(json['id'] ?? json['sessionId']) ?? 0,
      sessionType: (json['sessionType'] ?? 'ai').toString(),
      ragId: json['ragId']?.toString(),
    );
  }
}

/// 消息类型：普通文本 / 「正在思考」占位 / 转人工确认卡（后两者为本地合成）。
enum ChatMessageKind { text, loading, transferConfirm }

class ChatMessage {
  const ChatMessage({
    required this.content,
    required this.senderType,
    this.kind = ChatMessageKind.text,
    this.createTime,
    this.confirmed = false,
  });

  final String content;

  /// `agent`（客服）/ `user` | `member`（自己）。
  final String senderType;
  final ChatMessageKind kind;
  final DateTime? createTime;

  /// 转人工确认卡是否已确认（仅本地状态）。
  final bool confirmed;

  bool get isMine => senderType == 'user' || senderType == 'member';

  ChatMessage copyWith({
    String? content,
    String? senderType,
    ChatMessageKind? kind,
    DateTime? createTime,
    bool? confirmed,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      senderType: senderType ?? this.senderType,
      kind: kind ?? this.kind,
      createTime: createTime ?? this.createTime,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final type = (json['messageType'] ?? 'text').toString();
    return ChatMessage(
      content: (json['content'] ?? '').toString(),
      senderType: (json['senderType'] ?? 'agent').toString(),
      kind: type == 'loading'
          ? ChatMessageKind.loading
          : type == 'transfer_confirm'
              ? ChatMessageKind.transferConfirm
              : ChatMessageKind.text,
      createTime: _toTime(json['createTime']),
    );
  }
}

DateTime? _toTime(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    // 兼容秒 / 毫秒时间戳
    final ms = v > 100000000000 ? v.toInt() : v.toInt() * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
