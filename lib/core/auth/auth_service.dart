import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';

/// 安全将 dynamic 转换为 int（处理 API 返回 String 类型数字的情况）
int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// 安全比较后端返回的 code 字段是否为 200（兼容 String/num 类型）
bool _isSuccess(dynamic code) {
  if (code is int) return code == 200;
  if (code is String) return code == '200';
  if (code is double) return code == 200.0;
  return false;
}

/// 通用请求结果
class AuthResult {
  final bool isSuccess;
  final String message;
  AuthResult._(this.isSuccess, this.message);
  factory AuthResult.ok(String message) => AuthResult._(true, message);
  factory AuthResult.fail(String message) => AuthResult._(false, message);
}

/// 登录结果
class LoginResult {
  final bool isSuccess;
  final String message;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final Map<String, dynamic>? userInfo;

  LoginResult._({
    required this.isSuccess,
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.userInfo,
  });

  factory LoginResult.ok({
    required String accessToken,
    required String refreshToken,
    int expiresIn = 1800,
    Map<String, dynamic>? userInfo,
  }) =>
      LoginResult._(
        isSuccess: true,
        message: '登录成功',
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
        userInfo: userInfo,
      );

  factory LoginResult.fail(String message) =>
      LoginResult._(isSuccess: false, message: message);
}

/// 登录态与登录接口。
///
/// - 验证码登录、发送短信对接后端 /auth/app/login/**；
/// - 一键登录（本机号码）当前无运营商 SDK，沿用 mock，接入 AliAuth 后替换；
/// - 登录态通过 ChangeNotifier 暴露给 [AuthGate]，并持久化到本地。
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static Map<String, String> get _jsonHeaders =>
      {'Content-Type': 'application/json; charset=utf-8'};

  bool _loggedIn = false;

  /// 是否已登录。
  bool get loggedIn => _loggedIn;

  /// 一键登录页展示的脱敏手机号，真实场景由运营商 SDK 返回。
  String get maskedPhone => '182****3210';

  /// 应用启动时恢复本地登录态。
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        instance._loggedIn = true;
      }
    } catch (_) {
      // 插件不可用（如测试环境）时忽略
    }
  }

  /// 读取本地存储的 Access Token（供 ApiClient 自动附带）。
  static Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {
      return null;
    }
  }

  /// 读取本地存储的 Refresh Token。
  static Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } catch (_) {
      return null;
    }
  }

  /// 读取本地 Access Token 过期时间戳（毫秒），未存储返回 null。
  static Future<int?> getAccessTokenExpiresAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('${_tokenKey}_expires_at');
    } catch (_) {
      return null;
    }
  }

  /// Access Token 是否临近过期（默认剩余不足 5 分钟）或本地无过期信息。
  ///
  /// 用于**主动续期**：在令牌彻底失效前提前刷新，避免「令牌已过期 → 401 →
  /// 又拿已过期令牌去刷新」的死锁（服务端 /auth/app/token/refresh 要求刷新时
  /// Authorization 头的 Access Token 仍有效）。
  static Future<bool> isAccessTokenNearExpiry({
    Duration threshold = const Duration(seconds: 60),
  }) async {
    final exp = await getAccessTokenExpiresAt();
    if (exp == null) return true; // 无信息：保守起见也尝试刷新
    final remaining = exp - DateTime.now().millisecondsSinceEpoch;
    return remaining <= threshold.inMilliseconds;
  }

  /// 持久化 Token（供 ApiClient 401 刷新后回写）。
  static Future<void> saveToken({
    required String accessToken,
    required String refreshToken,
    int expiresIn = 1800,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
      await prefs.setInt(
        '${_tokenKey}_expires_at',
        DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
      );
    } catch (_) {
      // 插件不可用时忽略
    }
  }

  /// 刷新 Access Token。
  ///
  /// 后端 /auth/app/token/refresh 的 Authorization 头要求携带 **Access Token**
  /// （若误带 Refresh Token 会返回「令牌类型错误，请使用Access Token」），
  /// 故此处用本地存储的 access_token 作为请求凭证；refresh_token 一并兜底
  /// 放入请求体（接口文档标注无参数，带上不影响，且服务端若需校验刷新令牌也能用上）。
  static Future<LoginResult> refreshToken(String? refreshToken) async {
    final accessToken = await getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('[AuthService] refreshToken 跳过：Access Token 为空');
      return LoginResult.fail('Access Token 为空');
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/app/token/refresh');
    // 脱敏打印 access token，确认「有没有发出去」，又不泄露完整令牌
    final mask = accessToken.length > 8
        ? '${accessToken.substring(0, 4)}…${accessToken.substring(accessToken.length - 4)}'
        : '***';
    debugPrint(
      '[AuthService] refreshToken 请求 url=$uri Authorization=Bearer $mask',
    );
    http.Response? response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: refreshToken != null && refreshToken.isNotEmpty
                ? jsonEncode({'refreshToken': refreshToken})
                : null,
          )
          .timeout(const Duration(seconds: ApiConfig.connectTimeout));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      // 接口文档显示该接口响应 schema 为 {warn, success, error, msg, ...}，
      // 与登录接口的 {code:200} 包装不同，故兼容两种成功判定：
      // code==200 或 success==true，任一命中即视为刷新成功。
      final successOk = response.statusCode == 200 &&
          (_isSuccess(body['code']) || body['success'] == true);
      if (successOk) {
        // 新令牌可能在 data 里（常规包装），也可能直接在响应顶层
        final dynamic payload = body['data'] ?? body;
        final tokenMap = payload is Map<String, dynamic>
            ? payload
            : const <String, dynamic>{};
        final at =
            (tokenMap['access_token'] ?? tokenMap['accessToken']) as String? ?? '';
        final rt =
            (tokenMap['refresh_token'] ?? tokenMap['refreshToken']) as String? ?? '';
        if (at.isNotEmpty) {
          final expiresIn =
              _toInt(tokenMap['expires_in'] ?? tokenMap['expiresIn']) ?? 1800;
          debugPrint(
            '[AuthService] refreshToken 成功 status=${response.statusCode} '
            'at.len=${at.length} rt.len=${rt.length} expiresIn=$expiresIn',
          );
          return LoginResult.ok(
            accessToken: at,
            refreshToken: rt,
            expiresIn: expiresIn,
          );
        }
        // data/顶层都没有 access_token：视为刷新失败，打印诊断
        debugPrint(
          '[AuthService] refreshToken 字段缺失 url=$uri status=${response.statusCode} '
          'body=${response.body}',
        );
      }
      debugPrint(
        '[AuthService] refreshToken 失败 url=$uri status=${response.statusCode} '
        'body=${response.body}',
      );
      return LoginResult.fail(body['msg']?.toString() ?? '刷新失败');
    } catch (e) {
      // 非 JSON 返回（如 404 HTML、代理错误）会在这里被 jsonDecode 抛异常，
      // 必须把状态码与原始 body 打出来，否则无法判断路径/服务是否正常
      debugPrint(
        '[AuthService] refreshToken 异常 url=$uri '
        'status=${response?.statusCode} body=${response?.body} error=$e',
      );
      return LoginResult.fail('网络异常：$e');
    }
  }

  /// 探测当前手机是否支持本机号码一键登录。
  Future<bool> isOneClickSupported() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// 发送短信验证码。
  static Future<AuthResult> sendSmsCode(String mobile) async {
    try {
      final base = Uri.parse(ApiConfig.baseUrl);
      final uri = base.replace(
        path: '/auth/app/login/smscode',
        queryParameters: {'mobile': mobile},
      );
      final response = await http
          .post(uri, headers: _jsonHeaders)
          .timeout(const Duration(seconds: ApiConfig.connectTimeout));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && _isSuccess(body['code'])) {
        return AuthResult.ok(body['msg'] ?? '验证码已发送');
      }
      return AuthResult.fail(body['msg'] ?? '发送验证码失败');
    } catch (e) {
      return AuthResult.fail('网络异常：$e');
    }
  }

  /// 手机验证码登录。
  Future<LoginResult> loginByMobileCode(String mobile, String code) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/app/login/mobileCode');
      final response = await http
          .post(
            uri,
            headers: _jsonHeaders,
            body: jsonEncode({'mobile': mobile, 'code': code}),
          )
          .timeout(const Duration(seconds: ApiConfig.connectTimeout));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && _isSuccess(body['code'])) {
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null) {
          final result = LoginResult.ok(
            accessToken: data['access_token'] as String? ?? '',
            refreshToken: data['refresh_token'] as String? ?? '',
            expiresIn: _toInt(data['expires_in']) ?? 1800,
            userInfo: data['memberInfo'] as Map<String, dynamic>?,
          );
          await _persistToken(
            result.accessToken!,
            result.refreshToken!,
            expiresIn: result.expiresIn ?? 1800,
          );
          _loggedIn = true;
          notifyListeners();
          return result;
        }
      }
      return LoginResult.fail(body['msg'] ?? '登录失败');
    } catch (e) {
      return LoginResult.fail('网络异常：$e');
    }
  }

  /// 本机号码一键登录（当前为 mock，接入 AliAuth 后替换为真实 token 校验）。
  Future<void> loginWithOneClick() async {
    _loggedIn = true;
    notifyListeners();
  }

  /// 退出登录（清除本地登录态）。
  Future<void> logout() async {
    // 先同步置为未登录并通知：让 AuthGate 立即跳转登录页、
    // 并让进行中的请求（及 PetState 等轮询）立刻短路，避免对已失效会话反复打网络。
    _loggedIn = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
    } catch (_) {
      // 插件不可用（如测试环境）时忽略本地清理
    }
  }

  static Future<void> _persistToken(
    String accessToken,
    String refreshToken, {
    int expiresIn = 1800,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
      await prefs.setInt(
        '${_tokenKey}_expires_at',
        DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
      );
    } catch (_) {
      // 插件不可用时忽略本地持久化
    }
  }
}
