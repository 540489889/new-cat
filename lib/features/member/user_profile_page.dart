import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../core/user/member_api.dart';
import '../../core/user/user_state.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/date_picker_sheet.dart';
import '../../shared/widgets/image_picker_dialog.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 用户资料页（对齐参考项目 f-cat 的 user_profile.dart）：
/// 头像上传、昵称修改、生日修改、退出登录、注销账户。
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // 与「我的」页一致的设计稿色板
  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _red = Color(0xFFE05A5A);
  static const Color _divider = Color(0x66F1EAE4);

  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // 进入资料页时静默刷新一次会员信息（离线时沿用本地缓存）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserState>().refreshFromServer();
    });
  }

  /// 弹窗选择「拍照 / 从相册选择」→ 上传 → 回写 headimg
  Future<void> _changeAvatar() async {
    if (_uploading) return;
    // 与参考项目 f-cat 一致：先弹底部选择框，再调用系统相机/相册
    final source = await showImagePickerDialog(context);
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final res = await ApiClient.instance.uploadFile(
        '/app/user/file/upload',
        bytes: bytes,
        filename: picked.name,
        extraFields: {'scene': 'avatar'},
      );
      if (!mounted) return;
      if (!res.isSuccess) {
        TToast.showText(res.message, context: context);
        return;
      }
      // 响应可能是 url 字符串，也可能是 {url: ...}
      final url = res.data is String
          ? res.data as String
          : (res.asMap['url']?.toString() ?? '');
      if (url.isEmpty) {
        TToast.showText('上传返回为空', context: context);
        return;
      }
      final upd = await MemberApiService.updateMemberInfo(headimg: url);
      if (!mounted) return;
      if (upd.isSuccess) {
        context.read<UserState>().updateUserInfo({'headimg': url});
        TToast.showSuccess('头像已更新', context: context);
      } else {
        TToast.showText(upd.message, context: context);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// 修改昵称：TDialog 弹窗输入 → POST /app/member/update
  Future<void> _editNickname() async {
    final userState = context.read<UserState>();
    final controller = TextEditingController(text: userState.username);
    final input = await TDialog.show<String>(
      context,
      dialog: TDialog(
        // 暂时去掉标题（预览无标题样式）
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: InputDecoration(
            hintText: '请输入昵称',
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          const TDialogAction(child: Text('取消')),
          TDialogAction(
            child: const Text('保存'),
            role: TDialogActionRole.primary,
            // 手动关闭，把输入框内容作为弹窗返回值
            closeOnPressed: false,
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (input == null || input.isEmpty || !mounted) return;
    if (input == userState.username) return;
    final res = await MemberApiService.updateMemberInfo(nickname: input);
    if (!mounted) return;
    if (res.isSuccess) {
      context.read<UserState>().updateUserInfo({'nickname': input, 'nickName': input});
      TToast.showSuccess('昵称已更新', context: context);
    } else {
      TToast.showText(res.message, context: context);
    }
  }

  /// 修改生日：tdesign 滚轮日期选择 → POST /app/member/update
  Future<void> _pickBirthday() async {
    final current = context.read<UserState>().birthday;
    final picked = await showBirthdayPicker(context, initial: current);
    if (picked == null || !mounted) return;
    final res = await MemberApiService.updateMemberInfo(birthday: picked);
    if (!mounted) return;
    if (res.isSuccess) {
      context
          .read<UserState>()
          .updateUserInfo({'birthday': picked.toIso8601String()});
      TToast.showSuccess('生日已更新', context: context);
    } else {
      TToast.showText(res.message, context: context);
    }
  }

  Future<void> _logout() async {
    final ok = await showConfirmDialog(
      context,
      title: '退出登录',
      content: '确定要退出当前账号吗？',
      confirmText: '退出登录',
    );
    if (!ok) return;
    // AuthGate 监听 AuthService，登出后自动切回登录页
    await AuthService.instance.logout();
  }

  Future<void> _deleteAccount() async {
    final ok = await showConfirmDialog(
      context,
      title: '注销账户',
      content: '注销后账号数据将无法恢复，确定继续吗？',
      confirmText: '注销',
    );
    if (!ok || !mounted) return;
    // 后端注销接口尚未对接（参考项目同样为 TODO）
    TToast.showText('注销功能暂未开放，请联系客服处理', context: context);
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();
    final birthday = userState.birthday;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('个人资料'),
          useDefaultBack: true,
          // 避开状态栏，否则标题会与刘海/状态栏重叠
          useSafeArea: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            // 头像：左标题 + 右侧小圆头像 + 箭头（对齐参考项目 f-cat 的左右排版）
            _Card(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _changeAvatar,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      const Text('头像',
                          style: TextStyle(fontSize: 15, color: _ink)),
                      const Spacer(),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x1A3D2E33),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: userState.avatarUrl != null
                                  ? Image.network(userState.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _defaultAvatar())
                                  : _defaultAvatar(),
                            ),
                          ),
                          if (_uploading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 16, color: _sub),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 基本信息
            _Card(
              child: Column(
                children: [
                  _InfoRow(
                    label: '昵称',
                    value: userState.username,
                    onTap: _editNickname,
                  ),
                  Container(height: 1, color: _divider),
                  _InfoRow(
                    label: '生日',
                    value: birthday == null
                        ? '未设置'
                        : '${birthday.year}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}',
                    onTap: _pickBirthday,
                  ),
                  Container(height: 1, color: _divider),
                  _InfoRow(
                    label: '手机号',
                    value: userState.maskedMobile.isEmpty
                        ? '未绑定'
                        : userState.maskedMobile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 第三方账号（参考项目同为静态占位）
            _Card(
              child: Column(
                children: [
                  _InfoRow(label: '微信', value: '未授权', onTap: _comingSoon),
                  Container(height: 1, color: _divider),
                  _InfoRow(label: 'Apple ID', value: '未绑定', onTap: _comingSoon),
                  Container(height: 1, color: _divider),
                  _InfoRow(label: '检查更新', value: '最新版本', onTap: _comingSoon),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 退出登录
            _Card(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _logout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: _red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('退出登录',
                            style: TextStyle(fontSize: 15, color: _red)),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: _sub),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 注销账户
            _Card(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _deleteAccount,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      Icon(Icons.person_off_outlined, size: 20, color: _red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('注销账户',
                            style: TextStyle(fontSize: 15, color: _red)),
                      ),
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

  void _comingSoon() {
    TToast.showText('功能即将开放', context: context);
  }

  Widget _defaultAvatar() {
    return Image.asset('assets/images/group-1.png', fit: BoxFit.cover);
  }
}

/// 白色圆角卡片
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

/// 信息行：左标题 + 右值 + 箭头（无 onTap 时为只读）
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 15, color: _UserProfilePageState._ink)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, color: _UserProfilePageState._sub)),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 16, color: _UserProfilePageState._sub),
          ],
        ),
      ),
    );
  }
}
