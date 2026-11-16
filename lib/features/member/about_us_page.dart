import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 关于我们（对齐参考项目 f-cat 的 about_us.dart）：
/// Logo + 应用名 + slogan + 协议/隐私/公司信息外链 + 版权信息。纯静态页。
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _divider = Color(0x66F1EAE4);

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('关于我们'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: Column(
          children: [
            // 内容区：可滚动，不占满时也不影响底部版权位置
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text('pet',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text('用心陪伴每一只宠物',
                        style: TextStyle(fontSize: 12, color: _sub)),
                  ),
                  const SizedBox(height: 28),
                  // 协议与公司信息
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _LinkRow(
                          title: '用户协议',
                          onTap: () =>
                              _open(context, ApiConfig.userAgreementUrl),
                        ),
                        Container(height: 1, color: _divider),
                        _LinkRow(
                          title: '隐私政策',
                          onTap: () => _open(context, ApiConfig.privacyUrl),
                        ),
                        Container(height: 1, color: _divider),
                        _LinkRow(
                          title: '公司信息',
                          onTap: () => _open(context, ApiConfig.companyUrl),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 版权信息：固定在页面底部（不随内容滚动）
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                child: const Text(
                  'Copyright@2016-2026\n只创智能科技有限公司 版权所有',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _sub, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && context.mounted) {
      TToast.showText('打开失败：$url', context: context);
    }
  }
}

class _LinkRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _LinkRow({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, color: AboutUsPage._ink)),
            const Spacer(),
            const Icon(Icons.chevron_right,
                size: 16, color: AboutUsPage._sub),
          ],
        ),
      ),
    );
  }
}
