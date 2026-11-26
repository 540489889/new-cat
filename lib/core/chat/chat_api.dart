import '../http/api_client.dart';

/// 客服（AI + 人工）相关接口，路径与参考项目 f-cat 一致。
class ChatApi {
  ChatApi._();

  static final ApiClient _api = ApiClient.instance;

  /// 获取（或自动创建）当前用户的 AI 客服会话：`GET /app/chat/session/ai`。
  ///
  /// 返回 `{id, sessionType: 'ai'|'manual', ragId}`。
  static Future<ApiResponse> getAiSession() {
    return _api.get('/app/chat/session/ai');
  }

  /// 分页拉取会话消息：`POST /app/chat/messages`。
  ///
  /// body `{sessionId, page, size}`；返回 List，最新消息在前。
  static Future<ApiResponse> getMessages({
    required int sessionId,
    int page = 1,
    int size = 20,
  }) {
    return _api.post('/app/chat/messages', body: {
      'sessionId': sessionId,
      'page': page,
      'size': size,
    });
  }

  /// 发送消息：`POST /app/chat/sendMsg`。
  ///
  /// [type] 为 `ai` 或 `manual`，决定后端走机器人还是人工坐席。
  static Future<ApiResponse> sendMessage({
    required int sessionId,
    required String content,
    required String type,
  }) {
    return _api.post('/app/chat/sendMsg', body: {
      'sessionId': sessionId,
      'content': content,
      'type': type,
      'messageType': 'text',
    });
  }

  /// 关闭会话：`POST /app/chat/session/close`。
  static Future<ApiResponse> closeSession(int sessionId) {
    return _api.post('/app/chat/session/close', body: {'sessionId': sessionId});
  }
}
