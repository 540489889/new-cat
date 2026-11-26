import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import 'family_api.dart';
import 'family_models.dart';

/// 家庭全局状态（对齐参考项目 f-cat「我的家庭」的数据来源）。
///
/// - [load]：`POST /app/home/info` 取家庭详情，再 `GET /app/home/member/list` 取成员；
/// - 非成功 / 空 data 一律视为「还没有家庭」，与参考项目口径一致；
/// - 邀请 / 创建 / 改名成功后自动重新加载，保证「我的」页与家庭页同步；
/// - 监听 [AuthService]，登出时清空缓存。
class FamilyState extends ChangeNotifier {
  FamilyState() {
    AuthService.instance.addListener(_onAuthChanged);
  }

  bool _loading = false;
  bool _loaded = false;

  /// 上次已知的登录态：用于识别「未登录 → 登录」的切换并重新加载。
  bool _wasLoggedIn = AuthService.instance.loggedIn;
  FamilyInfo? _home;
  List<FamilyMember> _members = const [];
  String _error = '';

  bool get loading => _loading;

  /// 是否已完成第一次加载（供页面区分「加载中」与「无家庭」）。
  bool get loaded => _loaded;
  FamilyInfo? get home => _home;
  List<FamilyMember> get members => _members;
  bool get hasFamily => _home != null;
  int get memberCount => _members.length;

  /// 仅用于提示的加载异常（无家庭不算异常）。
  String get error => _error;

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final loggedIn = AuthService.instance.loggedIn;
    // 仅登录信息刷新（如资料更新）时不重置家庭数据
    if (loggedIn == _wasLoggedIn) return;
    _wasLoggedIn = loggedIn;
    if (!loggedIn) {
      _home = null;
      _members = const [];
      _loading = false;
      _loaded = false;
      _error = '';
    } else {
      // 刚登录：作废旧的「未加载」标记，让页面重建时自动拉取
      _loaded = false;
    }
    notifyListeners();
  }

  /// 加载家庭信息。[force] 为 true 时忽略缓存重新请求。
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    _loading = true;
    _error = '';
    notifyListeners();

    if (AuthService.instance.loggedIn) {
      try {
        final infoRes = await FamilyApi.getHomeInfo();
        if (infoRes.isSuccess && infoRes.isMap && infoRes.asMap.isNotEmpty) {
          final home = FamilyInfo.fromJson(infoRes.asMap);
          _home = home;
          final memberRes = await FamilyApi.getMemberList(home.id);
          _members = memberRes.isSuccess
              ? memberRes.asList
                  .whereType<Map<String, dynamic>>()
                  .map(FamilyMember.fromJson)
                  .toList()
              : const <FamilyMember>[];
        } else {
          _home = null;
          _members = const [];
        }
      } catch (e) {
        debugPrint('[FamilyState] load error: $e');
        _error = '家庭信息加载失败，请下拉重试';
      }
    }

    _loading = false;
    _loaded = true;
    notifyListeners();
  }

  /// 邀请成员，成功返回 null，失败返回后端提示。
  Future<String?> invite(String mobile) async {
    final home = _home;
    if (home == null) return '还未加入家庭';
    final res = await FamilyApi.inviteMember(homeId: home.id, mobile: mobile);
    if (!res.isSuccess) {
      return res.message.isEmpty ? '邀请失败，请稍后重试' : res.message;
    }
    await load(force: true);
    return null;
  }

  /// 创建家庭，成功返回 null，失败返回后端提示。
  Future<String?> createFamily(String name) async {
    final res = await FamilyApi.createHome(name: name);
    if (!res.isSuccess) {
      return res.message.isEmpty ? '创建失败，请稍后重试' : res.message;
    }
    await load(force: true);
    return null;
  }

  /// 修改家庭名称 / 头像，成功返回 null，失败返回后端提示。
  Future<String?> updateFamily({required String name, String? avatar}) async {
    final home = _home;
    if (home == null) return '还未加入家庭';
    final res = await FamilyApi.updateHome(
      homeId: home.id,
      name: name,
      avatar: avatar ?? home.avatar,
    );
    if (!res.isSuccess) {
      return res.message.isEmpty ? '保存失败，请稍后重试' : res.message;
    }
    // 本地先同步，避免等接口回包前 UI 仍显示旧名称
    _home = home.copyWith(name: name, avatar: avatar ?? home.avatar);
    notifyListeners();
    await load(force: true);
    return null;
  }
}
