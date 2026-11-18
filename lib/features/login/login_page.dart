import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:ali_auth/ali_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wechat_bridge/wechat_bridge.dart';

import '../../config/api_config.dart';
import '../../core/auth/auth_gate.dart'
    show registerWechatCallback, unregisterWechatCallback;
import '../../core/auth/auth_service.dart';
import '../../core/router/app_router.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 登录页：进页面自动拉起本机号码一键登录（阿里云 AliAuth），
/// 失败 / 用户取消 / 点「更多登录方式」则回落到验证码登录页。
/// 微信、苹果登录作为底部第三方入口常驻。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _agreed = false;
  bool _submitting = false;

  /// 正在请求的第三方登录图标资源路径。只让被点的那个图标转圈，
  /// 其余图标保持静止（但一并禁用点击，避免重复拉起授权）。
  /// 验证码登录按钮仍用 _submitting，两者互不影响。
  String? _submittingSocial;
  static const _wechatAsset = 'assets/images/icon/login-1.png';
  static const _appleAsset = 'assets/images/icon/login-2.png';
  static const _oneClickAsset = 'assets/images/icon/login-3.png';

  /// 已处理的微信授权 code：MethodChannel 与 respStream 可能同时回调，
  /// 同一个 code 只处理一次（微信 code 一次性，重复用必失败）。
  String? _handledWechatCode;

  /// 一键登录是否已完成（拿到 token 后走后端成功），避免超时回落抢跑。
  bool _mobileAuthDone = false;

  /// 当前设备是否支持一键登录（SIM 卡为三大运营商 + 有网络 + 插件可用）。
  /// 默认 false：检测完成前不显示一键登录入口、不自动拉起。
  bool _oneClickSupported = false;

  /// AliAuth 无响应兜底：超时后自动回落到验证码登录。
  Timer? _aliAuthTimeout;

  // SK 凭证：与 f-cat 共用（同包名 pet.jolipaw.app + 同签名）。
  static const String _androidSk =
      'hlYZMVTt+HRwZo7YYBmiY3Mmddtmhaim6zC9uUmd7eAdSAuvtB7l7aSPySwDgDWmGmRdBueHGT6gvrJ41Ed1gM8ZZ3Tz9P5vq7LxbWQdgAqhDUQPuPq5lXDJiUI5ya0Vpa9GH/t5mwi1UwPByAhLJgSngcvqIM0Ppwbb4glSBuDLGabsqx36554sOxc6smvbQPHK+CLMR45d68h4HAZfwD2SSQRMrk6sZIVAZTIXexv6u3ribn1VVIlmjtxFT4VgsqdFrxGytwPhoWU8Dt4WpI4JWqXFgTM0qSWdcWcpJ8o=';
  static const String _iosSk =
      'UVPdnrl0/TshSU81f/ttUi9NPe2juqKl6820ufMR/3F96IVmhX7U5onkMxO5Lp5z29CFfDZkMvRVXzyRjj+TGsfEs56+LVAAFOFrUQ4nLqcn2cmntgSR4WvNMVf/JbxeZLuwEck3uI6A7foHfUqtndlpdRZTMJA/DgTMhue+TeEtzMwdqCpk54w9tP7ysUfm4Wo+s/g48UBAj29G3KltyF+AjC5x11spdtPsoJQwr9rEs/F8AVAKI1pTms22qibv';

  // 验证码登录表单
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _countdownTimer;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    // 微信授权回调入口（main.dart 的 MethodChannel / respStream 写入）。
    // 用 register 而非直接赋值：冷启动时 code 可能早于本页注册到达，会被暂存并在此补发。
    registerWechatCallback((code) {
      // MethodChannel 与 respStream 可能先后送到同一个 code，去重避免重复请求
      // （微信 code 一次性，第二次使用会失败并弹错误提示）。
      if (code == _handledWechatCode) return;
      _handledWechatCode = code;
      _handleWechatAuth(code);
    });

    // 一键登录：先检测设备是否支持（SIM 运营商 + 网络 + 插件可用），
    // 支持才注册监听、显示入口并自动拉起；否则静默只用验证码登录。
    _detectOneClickSupport();
  }

  /// 检测当前设备是否支持一键登录：
  /// 1) 必须是移动端且插件可用；
  /// 2) getCurrentCarrierName 返回中国移动/联通/电信之一（即有可用 SIM）；
  /// 3) checkCellularDataEnable 报告有网络。
  /// 任一环节异常（如插件未注册 MissingPluginException）都视为不支持。
  Future<void> _detectOneClickSupport() async {
    if (kIsWeb) return;
    try {
      final carrier = await AliAuth.getCurrentCarrierName();
      final network = await AliAuth.checkCellularDataEnable;
      final hasCarrier = const ['中国移动', '中国联通', '中国电信']
          .contains(carrier.trim());
      // 网络检测仅作参考：Android 返回 Map{code:0|1}，iOS 格式可能不同；
      // 一键登录在有可用 SIM（三大运营商）时即使 WiFi 也能用，故 SIM 为准，
      // 网络字段只在明确拿到 code 且为 0（无网络）时才否决。
      final networkCode = network is Map ? network['code'] : null;
      final noNetwork = networkCode == 0 || networkCode == '0';
      final supported = hasCarrier && !noNetwork;
      debugPrint('一键登录能力检测: carrier=$carrier, network=$network, supported=$supported');
      if (!mounted) return;
      setState(() => _oneClickSupported = supported);
      if (supported) {
        _setupAliAuthListener();
        _scheduleAutoOneClick();
      }
    } catch (e) {
      // 插件不可用/检测失败：不支持一键登录，保持验证码登录
      debugPrint('一键登录能力检测失败，隐藏入口: $e');
    }
  }

  @override
  void dispose() {
    unregisterWechatCallback();
    _aliAuthTimeout?.cancel();
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  // ---------------- 一键登录（阿里云 AliAuth） ----------------

  /// 注册一键登录事件回调：
  /// 600000=拿到运营商 token；700001/600015 等=点更多/取消→回落；
  /// 600011/600013/600014/600024 等=失败→回落。
  void _setupAliAuthListener() {
    if (kIsWeb) return;
    try {
      AliAuth.loginListen(
        onEvent: (event) {
          if (!mounted || _mobileAuthDone) return;
          final code = event['code']?.toString();
          debugPrint('AliAuth event: $event');
          if (code == '600000' && event['data'] != null) {
            final raw = event['data'];
            final token = raw is String
                ? raw
                : (raw is Map ? raw['token'] as String? : null);
            if (token != null && token.isNotEmpty) {
              _aliAuthTimeout?.cancel();
              _handleMobileAuth(token);
            }
            return;
          }
          if (code == '700001' ||
              code == '700002' ||
              code == '700005' ||
              code == '600008' ||
              code == '600015') {
            _fallbackToCodeLogin();
            return;
          }
          if (code == '600011' ||
              code == '600013' ||
              code == '600014' ||
              code == '600024') {
            _fallbackToCodeLogin();
          }
        },
        onError: (error) {
          debugPrint('AliAuth listen error: $error');
        },
      );
    } catch (e) {
      // flutter test / 桌面端无原生插件时忽略，不影响验证码登录
      debugPrint('AliAuth.loginListen 不可用: $e');
    }
  }

  /// 进页面延迟自动拉起一键登录授权页。
  void _scheduleAutoOneClick() {
    if (kIsWeb) return;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_mobileAuthDone) _handleAliAuth(auto: true);
    });
  }

  /// 启动 AliAuth 超时保护：8 秒无结果自动回落验证码登录。
  void _startAliAuthTimeout() {
    _aliAuthTimeout?.cancel();
    _aliAuthTimeout = Timer(const Duration(seconds: 8), () {
      if (mounted && !_mobileAuthDone) {
        debugPrint('AliAuth 超时，自动切换到验证码登录');
        _fallbackToCodeLogin();
      }
    });
  }

  /// 回落到验证码登录页：关闭授权页 + 清转圈。
  void _fallbackToCodeLogin() {
    _aliAuthTimeout?.cancel();
    if (mounted) setState(() => _submittingSocial = null);
    // quitPage 返回 Future，异常是异步抛出的，必须 unawaited().catchError
    // 吞掉，否则无原生插件时 MissingPluginException 会变成未捕获异常崩溃。
    AliAuth.quitPage().catchError((Object e) {
      debugPrint('AliAuth.quitPage 不可用（忽略）: $e');
    });
  }

  /// 构造一键登录授权页 UI 参数（对齐 f-cat buildLoginModel）。
  AliAuthModel _buildLoginModel() {
    final screenHeight =
        (ui.PlatformDispatcher.instance.views.first.physicalSize.height /
                ui.PlatformDispatcher.instance.views.first.devicePixelRatio)
            .floor();
    final int dialogHeight = (screenHeight * 0.6).floor();
    final int unit = dialogHeight ~/ 8;
    final thirdMap = {
      'width': -1,
      'height': -1,
      'top': unit * 4 + 40,
      'space': 20,
      'size': 15,
      'color': '#616161',
      'itemWidth': 40,
      'itemHeight': 40,
    };
    return AliAuthModel(
      _androidSk,
      _iosSk,
      isDebug: false,
      autoQuitPage: true,
      pageType: PageType.dialogBottom,
      statusBarColor: '#00000000',
      bottomNavColor: '#FFFFFF',
      lightColor: true,
      isStatusBarHidden: false,
      statusBarUIFlag: UIFAG.systemUiFalgLayoutFullscreen,
      navHidden: true,
      logoOffsetY: unit ~/ 2,
      logoImgPath: 'assets/images/logo.png',
      logoHidden: false,
      logoWidth: 70,
      logoHeight: 70,
      logoScaleType: ScaleType.fitXy,
      numberColor: '#333333',
      numberSize: 18,
      numFieldOffsetY: unit * 2,
      numberFieldOffsetX: 0,
      numberLayoutGravity: Gravity.centerHorizntal,
      logBtnText: '本机号码一键登录',
      logBtnTextSize: 16,
      logBtnTextColor: '#FFFFFF',
      logBtnHeight: 96,
      logBtnOffsetY: unit * 3,
      logBtnOffsetX: 0,
      logBtnMarginLeftAndRight: 20,
      logBtnLayoutGravity: Gravity.centerHorizntal,
      logBtnToastHidden: false,
      logBtnBackgroundPath: 'assets/images/btn-bg.png',
      switchAccText: '验证码登录',
      switchOffsetY: (unit * 4.8).round(),
      switchOffsetY_B: -1,
      switchAccTextColor: '#666666',
      switchAccTextSize: 16,
      protocolOneName: '《用户协议》',
      protocolOneURL: ApiConfig.userAgreementUrl,
      protocolTwoName: '《隐私政策》',
      protocolTwoURL: ApiConfig.privacyUrl,
      protocolCustomColor: '#FF7A47',
      protocolColor: '#999999',
      protocolLayoutGravity: Gravity.centerHorizntal,
      protocolGravity: Gravity.centerHorizntal,
      privacyTextSize: 12,
      privacyMargin: 28,
      privacyBefore: '我已阅读并同意',
      privacyEnd: '',
      vendorPrivacyPrefix: '《',
      vendorPrivacySuffix: '》',
      checkBoxWidth: 15,
      checkBoxHeight: 15,
      checkboxHidden: false,
      privacyState: false,
      dialogHeight: dialogHeight,
      dialogBottom: true,
      dialogCornerRadiusArray: [10, 10, 0, 0],
      dialogAlpha: 0.4,
      pageBackgroundRadius: 10,
      customThirdView: CustomThirdView.fromJson(thirdMap),
      pageBackgroundPath: '',
    );
  }

  /// 拉起一键登录授权页。auto=true 为进页面自动拉起（SDK 内自带协议勾选）。
  Future<void> _handleAliAuth({bool auto = false}) async {
    if (!auto) {
      _ensureAgreed(() => _launchAliAuth());
    } else {
      _launchAliAuth();
    }
  }

  Future<void> _launchAliAuth() async {
    if (!mounted) return;
    setState(() => _submittingSocial = _oneClickAsset);
    _startAliAuthTimeout();
    try {
      await AliAuth.initSdk(_buildLoginModel());
      await AliAuth.login();
    } catch (e) {
      debugPrint('一键登录拉起失败: $e');
      _fallbackToCodeLogin();
    }
  }

  /// 拿到运营商 token → 后端换登录态。
  Future<void> _handleMobileAuth(String token) async {
    if (!mounted) return;
    setState(() => _submittingSocial = _oneClickAsset);
    try {
      final res = await AuthService.instance.loginByMobileAuth(token);
      if (!mounted) return;
      if (res.isSuccess) {
        _mobileAuthDone = true;
        _aliAuthTimeout?.cancel();
        await AuthService.instance.applyMobileAuthLogin(res);
        // AuthGate 监听 AuthService，登录态一变自动切首页
      } else {
        TToast.showText(res.message, context: context);
        _fallbackToCodeLogin();
      }
    } catch (e) {
      if (mounted) TToast.showText('一键登录异常：$e', context: context);
      _fallbackToCodeLogin();
    }
  }

  // ---------------- 验证码登录 ----------------

  bool get _phoneValid =>
      RegExp(r'^1\d{10}$').hasMatch(_phoneController.text.trim());
  bool get _codeValid =>
      RegExp(r'^\d{4,6}$').hasMatch(_codeController.text.trim());

  void _ensureAgreed(VoidCallback submit) {
    if (_agreed) {
      submit();
      return;
    }
    _showProtocolDialog(onAgree: submit);
  }

  Future<void> _submitCode() async {
    if (_submitting) return;
    if (!_phoneValid || !_codeValid) {
      TToast.showText('请输入正确的手机号和验证码', context: context);
      return;
    }
    _ensureAgreed(() async {
      setState(() => _submitting = true);
      final res = await AuthService.instance.loginByMobileCode(
        _phoneController.text.trim(),
        _codeController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!res.isSuccess) {
        TToast.showText(res.message, context: context);
      }
    });
  }

  Future<void> _sendCode() async {
    if (!_phoneValid) {
      TToast.showText('请输入正确的手机号', context: context);
      return;
    }
    if (_countdown > 0) return;
    setState(() => _submitting = true);
    final res = await AuthService.sendSmsCode(_phoneController.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.isSuccess) {
      TToast.showText(res.message, context: context);
      setState(() => _countdown = 60);
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _countdown--);
        if (_countdown <= 0) timer.cancel();
      });
    } else {
      TToast.showText(res.message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/logo-bg.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
            SafeArea(
              child: Stack(
                children: [
                  // 验证码登录为主页面（一键登录授权页由 SDK 覆盖其上）
                  _buildCodeBody(token),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSocialLogins(),
                        const SizedBox(height: 24),
                        _buildAgreement(token),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBody(TThemeData token) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          Text(
            '验证码登录',
            style: TextStyle(
              color: const Color(0xFF4A3F44),
              fontSize: token.fontTitleExtraLarge?.size ?? 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 48),
          _PillTextField(
            prefix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+86',
                  style: TextStyle(
                    color: const Color(0xFF4A3F44),
                    fontSize: token.fontBodyLarge?.size ?? 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFFE3D5DC),
                ),
              ],
            ),
            hint: '手机号',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _PillTextField(
            hint: '验证码',
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onChanged: (_) => setState(() {}),
            suffix: GestureDetector(
              onTap: _countdown > 0 ? null : () => _sendCode(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 1,
                    height: 16,
                    margin: const EdgeInsets.only(right: 10),
                    color: const Color(0xFFE3D5DC),
                  ),
                  Text(
                    _countdown > 0 ? '${_countdown}s 后重发' : '发送验证码',
                    style: TextStyle(
                      color: _countdown > 0
                          ? const Color(0xFFC4B3BB)
                          : const Color(0xFF4A3F44),
                      fontSize: token.fontBodySmall?.size ?? 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _PrimaryButton(
            label: _submitting ? '登录中...' : '验证并登录',
            onPressed: _submitting ? null : _submitCode,
          ),
        ],
      ),
    );
  }

  // ---------------- 第三方登录 ----------------

  Future<void> _handleWechatLogin() async {
    _ensureAgreed(() async {
      try {
        final platform = WechatBridgePlatform.instance;
        final installed = await platform.isInstalled();
        if (!mounted) return;
        if (!installed) {
          TToast.showText('请先安装微信', context: context);
          return;
        }
        await platform.auth(scope: const [WechatScope.kSNSApiUserInfo]);
      } catch (e) {
        if (mounted) TToast.showText('微信登录异常：$e', context: context);
      }
    });
  }

  Future<void> _handleWechatAuth(String code) async {
    if (!mounted) return;
    setState(() => _submittingSocial = _wechatAsset);
    try {
      final res = await AuthService.instance.loginByWechat(code);
      if (!mounted) return;
      if (res.isSuccess) {
        await AuthService.instance.applyWechatLogin(LoginResult.ok(
          accessToken: res.accessToken!,
          refreshToken: res.refreshToken!,
          expiresIn: res.expiresIn ?? 1800,
          userInfo: res.userInfo,
        ));
        unregisterWechatCallback();
        return;
      }
      if (res.needsBind && res.cacheKey != null) {
        final bound = await Navigator.of(context).pushNamed<bool>(
          AppRoutes.bindMobile,
          arguments: res.cacheKey,
        );
        if (mounted && bound == true) unregisterWechatCallback();
        return;
      }
      TToast.showText(
          res.message.isEmpty ? '微信登录失败' : res.message,
          context: context);
    } finally {
      if (mounted) setState(() => _submittingSocial = null);
    }
  }

  Future<void> _handleAppleLogin() async {
    _ensureAgreed(() async {
      if (!mounted) return;
      setState(() => _submittingSocial = _appleAsset);
      try {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final token = credential.identityToken;
        final code = credential.authorizationCode;
        final user = credential.userIdentifier;
        if (token == null ||
            token.isEmpty ||
            user == null ||
            user.isEmpty) {
          TToast.showText('苹果授权信息不完整，请重试', context: context);
          return;
        }
        final res = await AuthService.instance.loginByApple(
          identityToken: token,
          authorizationCode: code,
          userIdentifier: user,
          email: credential.email,
          givenName: credential.givenName,
          familyName: credential.familyName,
        );
        if (!mounted) return;
        if (res.isSuccess) {
          await AuthService.instance.applyWechatLogin(res);
        } else {
          TToast.showText(res.message, context: context);
        }
      } catch (e) {
        if (mounted) TToast.showText('苹果登录异常：$e', context: context);
      } finally {
        if (mounted) setState(() => _submittingSocial = null);
      }
    });
  }

  Widget _buildSocialLogins() {
    final items = <({String asset, String label, VoidCallback onTap})>[];

    // 仅在检测到设备支持时显示一键登录入口
    if (_oneClickSupported) {
      items.add((
        asset: _oneClickAsset,
        label: '一键登录',
        onTap: () => _handleAliAuth(),
      ));
    }

    items.add((
      asset: _wechatAsset,
      label: '微信登录',
      onTap: _handleWechatLogin,
    ));

    if (!kIsWeb && Platform.isIOS) {
      items.add((
        asset: _appleAsset,
        label: '苹果登录',
        onTap: _handleAppleLogin,
      ));
    }

    const itemWidth = 68.0;
    const spacing = 8.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final item in items)
          Builder(builder: (context) {
            final busy = _submittingSocial == item.asset;
            return SizedBox(
              width: itemWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _submittingSocial != null ? null : item.onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          item.asset,
                          width: 44,
                          height: 44,
                          opacity: AlwaysStoppedAnimation(busy ? 0.35 : 1.0),
                        ),
                        if (busy)
                          const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8C7F85),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ].expand((widget) => [widget, const SizedBox(width: spacing)]).toList()
        ..removeLast(),
    );
  }

  // ---------------- 协议 ----------------

  static const List<({String name, String? url})> _agreementLinks = [
    (name: '《中国移动认证服务条款》', url: null),
    (name: '《用户协议》', url: ApiConfig.userAgreementUrl),
    (name: '《隐私政策》', url: ApiConfig.privacyUrl),
  ];

  final List<TapGestureRecognizer> _recognizers = [];

  TapGestureRecognizer _linkRecognizer(String name, String? url) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (url != null) {
          _openUrl(url);
        } else {
          TToast.showText('查看「$name」（占位）', context: context);
        }
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await canLaunchUrl(uri)) {
        TToast.showText('无法打开链接', context: context);
        return;
      }
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) {
        TToast.showText('无法打开链接', context: context);
      }
    } catch (e) {
      TToast.showText('无法打开链接', context: context);
    }
  }

  void _showProtocolDialog({VoidCallback? onAgree}) {
    final brand = context.tTheme.brandColor;
    TDialog.show<void>(
      context,
      dialog: TDialog(
        content: RichText(
          textAlign: TextAlign.left,
          text: TextSpan(
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.5),
            children: [
              const TextSpan(text: '为了更好地保障您的合法权益，请你阅读'),
              TextSpan(
                text: '《隐私政策》',
                style: TextStyle(color: brand),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl(ApiConfig.privacyUrl),
              ),
              const TextSpan(text: '、'),
              TextSpan(
                text: '《用户协议》',
                style: TextStyle(color: brand),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl(ApiConfig.userAgreementUrl),
              ),
              const TextSpan(text: '，点击同意后将继续登录'),
            ],
          ),
        ),
        actions: [
          const TDialogAction(child: Text('不同意')),
          TDialogAction(
            child: const Text('同意并继续'),
            role: TDialogActionRole.primary,
            onPressed: () {
              setState(() => _agreed = true);
              onAgree?.call();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAgreement(TThemeData token) {
    const linkStyle = TextStyle(
      color: Color(0xFF4A3F44),
      fontWeight: FontWeight.w500,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const ValueKey('agreement-checkbox'),
          onTap: () => setState(() => _agreed = !_agreed),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _agreed ? token.brandColor : const Color(0xFF8C7F85),
                width: 1.5,
              ),
              color: _agreed ? token.brandColor : Colors.transparent,
            ),
            child: _agreed
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                color: const Color(0xFF8C7F85),
                fontSize: token.fontBodySmall?.size ?? 12,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: '我已阅读并同意'),
                for (final link in _agreementLinks)
                  TextSpan(
                    text: link.name,
                    style: linkStyle,
                    recognizer: _linkRecognizer(link.name, link.url),
                  ),
                const TextSpan(text: '并使用本机号码登录。'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- 通用小组件 ----------------

/// 品牌色主按钮（胶囊形）。
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    final disabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: token.brandColor,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 白色胶囊输入框，支持前缀/后缀。
class _PillTextField extends StatelessWidget {
  const _PillTextField({
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.maxLength,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLength;
  final ValueChanged<String> onChanged;
  final Widget? prefix;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          ?prefix,
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              onChanged: onChanged,
              style: TextStyle(
                color: const Color(0xFF4A3F44),
                fontSize: token.fontBodyLarge?.size ?? 16,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFFC0AEB7),
                  fontSize: 15,
                ),
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }
}
