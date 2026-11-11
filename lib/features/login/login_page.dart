import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../core/auth/auth_service.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 登录页：优先展示「一键登录」，手机不支持时回落为「验证码登录」，
/// 两态可通过底部链接互相切换。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _LoginMode { oneClick, code }

class _LoginPageState extends State<LoginPage> {
  /// 能力探测完成前为 null，展示加载态。
  _LoginMode? _mode;

  /// 当前手机是否支持一键登录（探测结果）。
  bool _oneClickSupported = false;

  bool _agreed = false;
  bool _submitting = false;

  // 验证码登录表单
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _countdownTimer;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    _detectOneClickSupport();
  }

  Future<void> _detectOneClickSupport() async {
    final supported = await AuthService.instance.isOneClickSupported();
    if (!mounted) return;
    setState(() {
      // 手机不支持一键登录时，隐藏一键登录入口，直接进验证码登录
      _oneClickSupported = supported;
      _mode = supported ? _LoginMode.oneClick : _LoginMode.code;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  bool get _phoneValid =>
      RegExp(r'^1\d{10}$').hasMatch(_phoneController.text.trim());
  bool get _codeValid =>
      RegExp(r'^\d{4,6}$').hasMatch(_codeController.text.trim());

  void _switchMode(_LoginMode mode) {
    FocusScope.of(context).unfocus();
    setState(() => _mode = mode);
  }

  void _ensureAgreed(VoidCallback submit) {
    if (_agreed) {
      submit();
      return;
    }
    _showProtocolDialog(onAgree: submit);
  }

  Future<void> _submitOneClick() async {
    if (_submitting) return;
    _ensureAgreed(() async {
      setState(() => _submitting = true);
      await AuthService.instance.loginWithOneClick();
    });
  }

  Future<void> _submitCode() async {
    if (_submitting) return;
    // 先校验手机号与验证码格式
    if (!_phoneValid || !_codeValid) {
      TToast.showText('请输入正确的手机号和验证码', context: context);
      return;
    }
    // 最后校验是否同意协议：未勾选则弹确认框，确认后再继续登录
    _ensureAgreed(() async {
      setState(() => _submitting = true);
      final res = await AuthService.instance.loginByMobileCode(
        _phoneController.text.trim(),
        _codeController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      // 成功时 AuthService 已置 loggedIn，AuthGate 会自动切到首页；
      // 失败则停留在登录页并提示
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
        // 键盘弹出时不压缩页面高度，避免把底部协议区顶上来（键盘浮于其上覆盖）
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 设计稿同款背景图（渐变 + 圆弧 + J 形/爪印装饰）
            // 宽度铺满、高度按比例自适应，不拉伸；锚定顶部
            Image.asset(
              'assets/images/logo-bg.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
            SafeArea(
              child: Stack(
                children: [
                  // 主体内容
                  switch (_mode) {
                    null => const Center(child: CircularProgressIndicator()),
                    _LoginMode.oneClick => _buildOneClickBody(token),
                    _LoginMode.code => _buildCodeBody(token),
                  },
                  // 底部协议
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: _buildAgreement(token),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 一键登录 ----------------

  Widget _buildOneClickBody(TThemeData token) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 96),
          // App Logo（占位，替换为真实 Logo 资源）
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: token.brandColor,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Text(
              'J',
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            AuthService.instance.maskedPhone,
            style: TextStyle(
              color: const Color(0xFF4A3F44),
              fontSize: token.fontTitleLarge?.size ?? 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '中国移动提供认证服务',
            style: TextStyle(
              color: const Color(0xFFB29AA5),
              fontSize: token.fontBodySmall?.size ?? 12,
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: _submitting ? '登录中...' : '本机号码一键登录',
            onPressed: _submitting ? null : _submitOneClick,
          ),
          const SizedBox(height: 20),
          TButton(
            variant: TButtonVariant.text,
            onPressed: () => _switchMode(_LoginMode.code),
            child: Text(
              '验证码登录',
              style: TextStyle(
                color: const Color(0xFF4A3F44),
                fontSize: token.fontBodyLarge?.size ?? 16,
              ),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  // ---------------- 验证码登录 ----------------

  Widget _buildCodeBody(TThemeData token) {
    // 用滚动容器包裹：键盘弹出、页面不压缩时，聚焦的输入框仍能被滚到可见区域
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
          const SizedBox(height: 20),
          TButton(
            variant: TButtonVariant.text,
            onPressed: _oneClickSupported
                ? () => _switchMode(_LoginMode.oneClick)
                : null,
            child: Text(
              '一键登录',
              style: TextStyle(
                color: const Color(0xFF4A3F44),
                fontSize: token.fontBodyLarge?.size ?? 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 协议 ----------------

  // 协议链接：name + 跳转地址（无地址的用占位提示）
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
      // platformDefault：移动端用内置浏览器、桌面端用系统浏览器，避免
      // inAppBrowserView 在桌面不支持时静默返回 false 导致“点击没反应”
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) {
        TToast.showText('无法打开链接', context: context);
      }
    } catch (e) {
      TToast.showText('无法打开链接', context: context);
    }
  }

  /// 未勾选协议时弹出的确认框（与 f-cat 登录页一致）：
  /// 「不同意」关闭；「同意并继续」勾选协议并执行后续登录动作。
  void _showProtocolDialog({VoidCallback? onAgree}) {
    final brand = context.tTheme.brandColor;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('隐私政策和服务协议',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.left,
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5),
                    children: [
                      const TextSpan(
                          text: '为了更好地保障您的合法权益，请你阅读'),
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
                          ..onTap =
                              () => _openUrl(ApiConfig.userAgreementUrl),
                      ),
                      const TextSpan(text: '，点击同意后将继续登录'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('不同意'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() => _agreed = true);
                          onAgree?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: brand,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('同意并继续'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
    // 白色胶囊输入框：保留背景，去掉底部边框（仅用圆角底色区分输入区）
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
                // 显式置空各态边框：tdesign 主题默认注入了下划线边框，
                // 仅写 border: none 会被主题默认值覆盖
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

