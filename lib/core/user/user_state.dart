import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import 'member_api.dart';

/// 当前登录用户的全局状态（对齐参考项目 f-cat 的 UserState）。
///
/// - 用户信息来自登录响应 memberInfo / `GET /app/member/info`，缓存于本地；
/// - 监听 [AuthService]：登录后自动从缓存恢复，登出后自动清空；
/// - 资料页修改昵称/头像/生日后，通过 [updateUserInfo] 立即刷新全站展示。
class UserState extends ChangeNotifier {
  UserState() {
    AuthService.instance.addListener(_onAuthChanged);
  }

  Map<String, dynamic>? _userInfo;
  String _username = '';
  bool _initialized = false;

  Map<String, dynamic>? get userInfo => _userInfo;

  /// 展示用昵称：nickName / nickname / mobile 兜底，全空时显示「用户」
  String get username => _username.isEmpty ? '用户' : _username;

  /// 是否已完成首次恢复（供页面在加载中展示占位）
  bool get initialized => _initialized;

  /// 头像地址（仅接受 http(s) 网络图，其余走本地默认图）
  String? get avatarUrl {
    final v = (_userInfo?['headimg'] ?? _userInfo?['avatar'])?.toString();
    return (v != null && v.startsWith('http')) ? v : null;
  }

  /// 手机号脱敏：138****8888；无手机号时返回空串
  String get maskedMobile {
    final mobile = (_userInfo?['mobile'] ?? '').toString();
    if (mobile.length >= 11) {
      return '${mobile.substring(0, 3)} **** ${mobile.substring(7)}';
    }
    return mobile;
  }

  DateTime? get birthday {
    final raw = _userInfo?['birthday'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  /// 启动时从本地缓存恢复用户信息（main 中 await AuthService.restore 后调用）。
  Future<void> checkLoginStatus() async {
    final info = await AuthService.getUserInfo();
    if (info != null && info.isNotEmpty) {
      _applyInfo(info);
    }
    _initialized = true;
    notifyListeners();
  }

  /// 从服务端刷新会员信息（个人中心进入时可调用）。
  Future<bool> refreshFromServer() async {
    if (!AuthService.instance.loggedIn) return false;
    final res = await MemberApiService.getMemberInfo();
    if (res.isSuccess && res.isMap && res.asMap.isNotEmpty) {
      _applyInfo(res.asMap);
      notifyListeners();
      return true;
    }
    return false;
  }

  void setUsername(String value) {
    if (value.isEmpty || _username == value) return;
    _username = value;
    notifyListeners();
  }

  /// 本地合并更新用户信息（资料修改成功后调用，立即刷新全站展示）。
  void updateUserInfo(Map<String, dynamic> patch) {
    _applyInfo(patch);
    notifyListeners();
  }

  void clear() {
    if (_userInfo == null && _username.isEmpty) return;
    _userInfo = null;
    _username = '';
    notifyListeners();
  }

  void _applyInfo(Map<String, dynamic> info) {
    _userInfo = <String, dynamic>{...?_userInfo, ...info};
    final name =
        (info['nickName'] ?? info['nickname'] ?? info['mobile'] ?? '').toString();
    if (name.isNotEmpty) {
      _username = name;
    }
  }

  /// 登录态变化：登录后恢复缓存，登出后清空
  void _onAuthChanged() {
    if (AuthService.instance.loggedIn) {
      checkLoginStatus();
    } else {
      clear();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }
}
