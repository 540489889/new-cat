import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 微信授权后需绑定手机号时展示（对齐 f-cat 的 bindMoobile.dart）。
/// [cacheKey] 来自 /auth/app/login/weixin 返回的 message == 'bindMobile'。
class BindMobilePage extends StatefulWidget {
  final String cacheKey;
  const BindMobilePage({super.key, required this.cacheKey});

  @override
  State<BindMobilePage> createState() => _BindMobilePageState();
}

class _BindMobilePageState extends State<BindMobilePage> {
  static const Color _brand = Color(0xFF7F6370);
  static const Color _ink = Color(0xFF4A3F44);
  static const Color _sub = Color(0xFF8C7F85);
  static const Color _bg = Color(0xFFF7F2ED);

  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;
  bool _sending = false;
  bool _submitting = false;
  bool _guard = false;

  bool get _canSubmit =>
      RegExp(r'^1\d{10}$').hasMatch(_phoneCtrl.text.trim()) &&
      _codeCtrl.text.trim().length == 6;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_secondsLeft > 0 || _sending) return;
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      TToast.showText('请输入正确的手机号', context: context);
      return;
    }
    setState(() => _sending = true);
    final res = await AuthService.sendSmsCode(phone);
    if (!mounted) return;
    setState(() => _sending = false);
    TToast.showText(res.message, context: context);
    if (res.isSuccess) {
      setState(() => _secondsLeft = 60);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) timer.cancel();
      });
    }
  }

  Future<void> _submit() async {
    if (_guard || !_canSubmit) return;
    _guard = true;
    setState(() => _submitting = true);
    final res = await AuthService.instance.bindMobile(
      cacheKey: widget.cacheKey,
      mobile: _phoneCtrl.text.trim(),
      code: _codeCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.isSuccess) {
      await AuthService.instance.applyWechatLogin(res);
      if (mounted) Navigator.of(context).pop(true);
    } else {
      TToast.showText(res.message, context: context);
      _guard = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: false,
        appBar: TNavBar(
          title: const Text('绑定手机号'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        // 点击空白处收起键盘：GestureDetector 默认 deferToChild，
        // 输入框/按钮等子控件优先接管手势，点到空白区才命中这里。
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('绑定手机号',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 8),
              const Text('为了您的账号安全，请绑定手机号码',
                  style: TextStyle(fontSize: 14, color: _sub)),
              const SizedBox(height: 32),
              _pill(
                child: Row(
                  children: [
                    const Text('+86',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: _ink)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        // 用 number 而非 phone：iOS 会对 phone 键盘推断出
                        // UITextContentType.telephoneNumber，弹出 "Scan Phone Number"
                        // 相机扫描建议；number 仍是纯数字键盘，不影响 11 位手机号输入。
                        keyboardType: TextInputType.number,
                        maxLength: 11,
                        autofillHints: const [],
                        enableSuggestions: false,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '手机号',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _pill(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofillHints: const [],
                        enableSuggestions: false,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '验证码',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _secondsLeft > 0 || _sending ? null : _sendCode,
                      child: Text(
                        _secondsLeft > 0
                            ? '${_secondsLeft}s 后重发'
                            : _sending
                                ? '发送中...'
                                : '发送验证码',
                        style: const TextStyle(fontSize: 13, color: _brand),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting || !_canSubmit ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCCC3C8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('绑定并登录',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _pill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}
