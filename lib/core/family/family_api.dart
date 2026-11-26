import '../http/api_client.dart';

/// 家庭相关接口（路径与字段对齐参考项目 f-cat 的 HomeApiService）。
///
/// | 方法 | 路径 | 说明 |
/// | --- | --- | --- |
/// | POST | `/app/home/info` | 当前用户所在家庭详情（无家庭时 data 为空） |
/// | GET | `/app/home/member/list?homeId=` | 家庭成员列表 |
/// | POST | `/app/home/member/invite` | 按手机号邀请成员 |
/// | POST | `/app/home/update` | 修改家庭名称 / 头像 |
/// | POST | `/app/home/create` | 创建家庭 |
class FamilyApi {
  FamilyApi._();

  static final ApiClient _api = ApiClient.instance;

  /// 当前用户所在家庭：`POST /app/home/info`（无请求体）。
  ///
  /// 成功时 data 为 Map：`id / name / avatar / inviteCode / ownerId / maxMembers`；
  /// 未加入家庭时接口返回失败或空 data，调用方按「无家庭」处理。
  static Future<ApiResponse> getHomeInfo() {
    return _api.post('/app/home/info');
  }

  /// 家庭成员列表：`GET /app/home/member/list?homeId={homeId}`。
  static Future<ApiResponse> getMemberList(int homeId) {
    return _api.get('/app/home/member/list',
        queryParams: {'homeId': homeId});
  }

  /// 邀请成员：`POST /app/home/member/invite`，body `{homeId, mobile}`。
  static Future<ApiResponse> inviteMember({
    required int homeId,
    required String mobile,
  }) {
    return _api.post('/app/home/member/invite', body: {
      'homeId': homeId,
      'mobile': mobile,
    });
  }

  /// 修改家庭名称 / 头像：`POST /app/home/update`。
  static Future<ApiResponse> updateHome({
    required int homeId,
    required String name,
    String? avatar,
  }) {
    return _api.post('/app/home/update', body: {
      'homeId': homeId,
      'name': name,
      if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
    });
  }

  /// 创建家庭：`POST /app/home/create`，body `{name, avatar?}`。
  static Future<ApiResponse> createHome({
    required String name,
    String? avatar,
  }) {
    return _api.post('/app/home/create', body: {
      'name': name,
      if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
    });
  }
}
