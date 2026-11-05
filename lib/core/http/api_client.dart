import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../auth/auth_service.dart';

/// 统一 API 请求客户端（带 Token 自动附加与 401 自动刷新）。
///
/// 用法：
/// ```dart
/// final res = await ApiClient.instance.get('/app/pet/list');
/// if (res.isSuccess) {
///   final list = res.asList;
/// }
/// ```
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();

  Map<String, String> get _jsonHeaders =>
      {'Content-Type': 'application/json; charset=utf-8'};

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(
        queryParameters:
            queryParams.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    return uri;
  }

  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? queryParams}) async {
    return _request('GET', _buildUri(path, queryParams), null);
  }

  Future<ApiResponse> post(String path, {Map<String, dynamic>? body}) async {
    return _request('POST', _buildUri(path), body);
  }

  Future<ApiResponse> _request(
    String method,
    Uri uri,
    Map<String, dynamic>? body,
  ) async {
    try {
      final headers = <String, String>{..._jsonHeaders};
      final token = await AuthService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final bodyStr = body != null ? jsonEncode(body) : null;
      final response = await _send(method, uri, headers, bodyStr);
      final parsed = _parseResponse(response);

      // 令牌失效：HTTP 401，或后端在 200 体内返回业务码 401/403（令牌过期）。
      // 两种情况都走「刷新后重试一次」，刷新失败再强制回登录页。
      final isTokenInvalid = response.statusCode == 401 ||
          parsed.code == 401 ||
          parsed.code == 403;
      if (isTokenInvalid) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          final newToken = await AuthService.getAccessToken();
          if (newToken != null && newToken.isNotEmpty) {
            headers['Authorization'] = 'Bearer $newToken';
          }
          final retry = await _send(method, uri, headers, bodyStr);
          return _parseResponse(retry);
        }
        // 刷新失败：会话已彻底失效，强制回登录页
        _onSessionExpired();
        return ApiResponse.unauthorized(parsed.message);
      }
      return parsed;
    } catch (e) {
      return ApiResponse.fail('网络异常：$e');
    }
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    final request = http.Request(method, uri)
      ..headers.addAll(headers);
    if (body != null) request.body = body;
    final streamed = await _client.send(request);
    return http.Response.fromStream(streamed);
  }

  /// 并发刷新去重：同一时刻只跑一次刷新，其余 401 复用其结果，
  /// 避免多个请求各自刷新导致 refresh token 被轮换而互相失败、误踢登录。
  Future<bool>? _refreshFuture;

  /// 刷新 Token，成功回写本地；返回是否刷新成功。
  /// 并发的 401 会复用同一次刷新（防止多请求各自刷新轮换 refresh token 而互相失败）。
  Future<bool> _tryRefresh() async {
    _refreshFuture ??= _doRefresh();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _doRefresh() async {
    final refresh = await AuthService.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    final result = await AuthService.refreshToken(refresh);
    if (result.isSuccess && (result.accessToken?.isNotEmpty ?? false)) {
      await AuthService.saveToken(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken ?? '',
        expiresIn: result.expiresIn ?? 1800,
      );
      return true;
    }
    return false;
  }

  /// 会话失效（401 且刷新失败）：仅在仍登录态时触发一次回登录页，
  /// 避免并发请求重复触发。
  void _onSessionExpired() {
    if (AuthService.instance.loggedIn) {
      unawaited(AuthService.instance.logout());
    }
  }

  ApiResponse _parseResponse(http.Response response) {
    if (response.statusCode != 200) {
      return ApiResponse.fail('请求失败(${response.statusCode})');
    }
    final bodyStr = response.body;
    if (bodyStr.isEmpty) return ApiResponse.fail('服务器返回空响应');
    try {
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final code = body['code'];
      final msg = body['msg'] as String? ?? '';
      if (code is int && code == 200 || code is String && code == '200') {
        return ApiResponse.ok(body['data'], msg);
      }
      final bizCode = code is int
          ? code
          : (code is String ? int.tryParse(code) : null);
      return ApiResponse.fail(msg, bizCode);
    } on FormatException {
      return ApiResponse.fail('响应格式异常');
    }
  }
}

/// 统一 API 响应。
class ApiResponse {
  final bool isSuccess;
  final String message;
  final dynamic data;

  /// 是否为「登录失效」（401 且刷新失败），用于触发回登录页。
  final bool isUnauthorized;

  /// 后端业务码（如 401/403 表示令牌失效），用于识别令牌过期。
  final int? code;

  ApiResponse._({
    required this.isSuccess,
    required this.message,
    this.data,
    this.isUnauthorized = false,
    this.code,
  });

  factory ApiResponse.ok(dynamic data, [String? msg]) =>
      ApiResponse._(isSuccess: true, message: msg ?? '成功', data: data);

  factory ApiResponse.fail([String? msg, int? code]) =>
      ApiResponse._(isSuccess: false, message: msg ?? '请求失败', code: code);

  factory ApiResponse.unauthorized([String? msg]) => ApiResponse._(
        isSuccess: false,
        message: msg ?? '登录已过期，请重新登录',
        isUnauthorized: true,
      );

  bool get isMap => data is Map<String, dynamic>;

  Map<String, dynamic> get asMap =>
      (data is Map<String, dynamic>) ? data as Map<String, dynamic> : {};

  List<dynamic> get asList =>
      (data is List<dynamic>) ? data as List<dynamic> : [];
}
