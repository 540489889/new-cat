import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/user/member_api.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 消息设置页（对齐参考项目 f-cat 的 notification_settings.dart）：
/// 三个通知开关，状态以后端为准（GET /app/member/notice、POST /app/member/noticeSet）。
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _divider = Color(0x66F1EAE4);

  bool _petMsg = true;
  bool _deviceMsg = true;
  bool _sysMsg = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await MemberApiService.getNoticeSettings();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess && res.isMap) {
        final data = res.asMap;
        _petMsg = (data['petMsg'] ?? 1).toString() == '1';
        _deviceMsg = (data['deviceMsg'] ?? 1).toString() == '1';
        _sysMsg = (data['sysMsg'] ?? 1).toString() == '1';
      }
    });
  }

  /// 切换即保存（全量提交三项）；失败回滚并提示
  Future<void> _save({
    bool? petMsg,
    bool? deviceMsg,
    bool? sysMsg,
  }) async {
    if (_saving) return;
    final prev = (_petMsg, _deviceMsg, _sysMsg);
    setState(() {
      _saving = true;
      if (petMsg != null) _petMsg = petMsg;
      if (deviceMsg != null) _deviceMsg = deviceMsg;
      if (sysMsg != null) _sysMsg = sysMsg;
    });
    final res = await MemberApiService.updateNoticeSettings(
      petMsg: _petMsg,
      deviceMsg: _deviceMsg,
      sysMsg: _sysMsg,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!res.isSuccess) {
      setState(() {
        _petMsg = prev.$1;
        _deviceMsg = prev.$2;
        _sysMsg = prev.$3;
      });
      TToast.showText(res.message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('消息设置'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: [
                  _Card(
                    child: Column(
                      children: [
                        _SwitchRow(
                          title: '宠物消息',
                          subtitle: '宠物健康提醒、AI 日报等',
                          value: _petMsg,
                          onChanged: (v) => _save(petMsg: v),
                        ),
                        Container(height: 1, color: _divider),
                        _SwitchRow(
                          title: '设备消息',
                          subtitle: '设备离线、电量、异常告警等',
                          value: _deviceMsg,
                          onChanged: (v) => _save(deviceMsg: v),
                        ),
                        Container(height: 1, color: _divider),
                        _SwitchRow(
                          title: '系统通知',
                          subtitle: '版本更新、活动公告等',
                          value: _sysMsg,
                          onChanged: (v) => _save(sysMsg: v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 清除缓存（参考项目同为本地演示行为）
                  _Card(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => TToast.showSuccess('缓存已清除', context: context),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        child: Row(
                          children: [
                            Text('清除缓存',
                                style: TextStyle(fontSize: 15, color: _ink)),
                            Spacer(),
                            Text('0.00 MB',
                                style: TextStyle(fontSize: 13, color: _sub)),
                            Icon(Icons.chevron_right, size: 16, color: _sub),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        color: _NotificationSettingsPageState._ink)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _NotificationSettingsPageState._sub)),
              ],
            ),
          ),
          // tdesign 开关：颜色随品牌主题走
          TSwitch(
            value: value,
            onChanged: onChanged,
            size: TSwitchSize.medium,
          ),
        ],
      ),
    );
  }
}
