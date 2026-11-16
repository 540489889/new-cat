import '../auth/auth_service.dart';
import '../http/api_client.dart';

/// 会员/个人中心相关接口（路径与字段对齐参考项目 f-cat 的 MemberApiService）。
class MemberApiService {
  MemberApiService._();

  static final ApiClient _api = ApiClient.instance;

  /// 获取会员信息：`GET /app/member/info`
  ///
  /// 成功时把返回的会员 map 写入本地缓存（供个人中心/资料页读取）。
  static Future<ApiResponse> getMemberInfo() async {
    final res = await _api.get('/app/member/info');
    if (res.isSuccess && res.isMap && res.asMap.isNotEmpty) {
      await AuthService.saveUserInfo(res.asMap);
    }
    return res;
  }

  /// 更新会员信息：`POST /app/member/update`
  ///
  /// body 仅携带本次修改的字段：nickname / headimg / birthday(ISO8601)。
  static Future<ApiResponse> updateMemberInfo({
    String? nickname,
    String? headimg,
    DateTime? birthday,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (headimg != null) body['headimg'] = headimg;
    if (birthday != null) body['birthday'] = birthday.toIso8601String();
    if (body.isEmpty) return ApiResponse.fail('没有需要更新的内容');
    final res = await _api.post('/app/member/update', body: body);
    if (res.isSuccess && res.isMap && res.asMap.isNotEmpty) {
      await AuthService.saveUserInfo(res.asMap);
    }
    return res;
  }

  /// 消息通知设置查询：`GET /app/member/notice`
  ///
  /// data 中 petMsg / deviceMsg / sysMsg 为 0/1 开关。
  static Future<ApiResponse> getNoticeSettings() {
    return _api.get('/app/member/notice');
  }

  /// 消息通知设置保存：`POST /app/member/noticeSet`
  ///
  /// 每次切换全量提交三项开关（1=开，0=关）。
  static Future<ApiResponse> updateNoticeSettings({
    required bool petMsg,
    required bool deviceMsg,
    required bool sysMsg,
  }) {
    return _api.post(
      '/app/member/noticeSet',
      body: {
        'clientId': '',
        'petMsg': petMsg ? 1 : 0,
        'deviceMsg': deviceMsg ? 1 : 0,
        'sysMsg': sysMsg ? 1 : 0,
      },
    );
  }
}
