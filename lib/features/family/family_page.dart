import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/family/family_models.dart';
import '../../core/family/family_state.dart';
import '../../core/router/app_router.dart';
import '../../core/user/user_state.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 「我的家庭」页（对接参考项目 f-cat 的 FamilyPage）。
///
/// 数据链路：
/// - 家庭详情 `POST /app/home/info`；
/// - 成员列表 `GET /app/home/member/list?homeId=`；
/// - 邀请成员 `POST /app/home/member/invite`；
/// - 创建家庭 `POST /app/home/create`；
/// - 改名/换头像在 [AppRoutes.familyEdit] 页完成（`POST /app/home/update`）。
///
/// 三种状态：加载中 / 还没有家庭（空态，可创建）/ 已有家庭（家庭卡 + 成员卡 + 邀请）。
class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  // 与「我的」页一致的设计稿色板
  static const Color _bg = Color(0xFFF7F2ED); // 页面暖米底
  static const Color _ink = Color(0xFF3D2E33); // 主文字
  static const Color _sub = Color(0xFFA89EA2); // 次要文字
  static const Color _brand = Color(0xFF7F6370); // 品牌紫
  static const Color _accent = Color(0xFFB48CA3); // 渐变浅紫
  static const Color _tagBg = Color(0xFFF6ECEF); // 浅紫标签底
  static const Color _pinkText = Color(0xFFB08CA0); // 浅紫文字
  static const Color _divider = Color(0x66F1EAE4); // 细分隔线

  /// 成员首字头像的底色循环。
  static const List<Color> _avatarBg = [
    Color(0xFFF3E3EA),
    Color(0xFFE9E4F2),
    Color(0xFFE2EDE6),
    Color(0xFFF7EADF),
    Color(0xFFE4EBF5),
  ];

  @override
  void initState() {
    super.initState();
    // 每次进入都强制刷新，成员/家庭名可能已在别处变更
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FamilyState>().load(force: true);
    });
  }

  Future<void> _invite() async {
    final family = context.read<FamilyState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _FamilyFormDialog(
        title: '邀请家庭成员',
        subtitle: '输入对方注册手机号，邀请 TA 加入家庭',
        hint: '请输入手机号',
        confirmText: '发送邀请',
        keyboardType: TextInputType.phone,
        maxLength: 11,
        validator: (v) =>
            RegExp(r'^1[3-9]\d{9}$').hasMatch(v) ? null : '请输入正确的手机号',
        onSubmit: (v) => family.invite(v),
      ),
    );
    if (ok == true && mounted) {
      TToast.showText('邀请已发送', context: context);
    }
  }

  Future<void> _create() async {
    final family = context.read<FamilyState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _FamilyFormDialog(
        title: '创建家庭',
        subtitle: '给家庭起个名字，邀请 TA 一起照顾毛孩子',
        hint: '请输入家庭名称',
        confirmText: '创建',
        maxLength: 12,
        validator: (v) => v.isEmpty ? '请输入家庭名称' : null,
        onSubmit: (v) => family.createFamily(v),
      ),
    );
    if (ok == true && mounted) {
      TToast.showText('家庭创建成功', context: context);
    }
  }

  Future<void> _edit(FamilyInfo home) async {
    await Navigator.of(context)
        .pushNamed<bool>(AppRoutes.familyEdit, arguments: home);
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    TToast.showText('邀请码已复制', context: context);
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('我的家庭'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: Consumer<FamilyState>(
          builder: (context, family, _) {
            if (family.loading && !family.loaded) {
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            return family.hasFamily
                ? _buildFamily(context, family)
                : _buildEmpty(context, family);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 空态

  Widget _buildEmpty(BuildContext context, FamilyState family) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变圆 + 家庭图标
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accent, Color(0xFFE5D2DC)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brand.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.family_restroom_rounded,
                  size: 44, color: Colors.white),
            ),
            const SizedBox(height: 22),
            const Text('还没有加入任何家庭哦~',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink)),
            const SizedBox(height: 8),
            const Text('创建家庭，邀请 TA 加入\n一起记录毛孩子的每一天',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _sub, height: 1.6)),
            const SizedBox(height: 26),
            GestureDetector(
              onTap: _create,
              child: Container(
                width: 180,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [_brand, _accent]),
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: _brand.withValues(alpha: 0.26),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text('创建家庭',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
            if (family.error.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(family.error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _sub)),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- 有家庭

  Widget _buildFamily(BuildContext context, FamilyState family) {
    final home = family.home!;
    final members = family.members;
    final userState = context.watch<UserState>();
    final uid = _idOf(userState);
    // 成员接口不返回昵称，自己那一行用当前登录用户的昵称兜底
    final meName = userState.username;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: _brand,
            onRefresh: () => family.load(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              children: [
                _homeCard(home, family),
                const SizedBox(height: 12),
                _memberCard(members, uid, meName),
                if (family.error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(family.error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: _sub)),
                ],
              ],
            ),
          ),
        ),
        _bottomInviteButton(context),
      ],
    );
  }

  Widget _homeCard(FamilyInfo home, FamilyState family) {
    final name = home.name.isEmpty ? '我的家庭' : home.name;
    final code = home.inviteCode;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _HomeAvatar(url: home.avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    const SizedBox(height: 4),
                    Text('${family.memberCount} 位成员',
                        style:
                            const TextStyle(fontSize: 12, color: _sub)),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _edit(home),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _tagBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit_outlined, size: 12, color: _pinkText),
                      SizedBox(width: 4),
                      Text('编辑',
                          style: TextStyle(fontSize: 12, color: _pinkText)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (code != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: _divider),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('邀请码',
                    style: TextStyle(fontSize: 12, color: _sub)),
                const SizedBox(width: 8),
                Text(code,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: 2)),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copyCode(code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _tagBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.copy_rounded, size: 12, color: _pinkText),
                        SizedBox(width: 4),
                        Text('复制',
                            style:
                                TextStyle(fontSize: 12, color: _pinkText)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberCard(List<FamilyMember> members, int? uid, String meName) {
    Widget row(int i) {
      final member = members[i];
      final isMe = uid != null && member.memberId == uid;
      return _MemberRow(
        name: (isMe && member.nickname.isEmpty) ? meName : member.displayName,
        roleLabel: member.roleLabel,
        role: member.role,
        avatar: member.avatar,
        isMe: isMe,
        bg: _avatarBg[i % _avatarBg.length],
        showDivider: i != members.length - 1,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('家庭成员',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink)),
              const Spacer(),
              Text('${members.length} 人',
                  style: const TextStyle(fontSize: 12, color: _sub)),
            ],
          ),
          const SizedBox(height: 6),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('还没有其他成员，邀请 TA 一起照顾毛孩子吧',
                    style: TextStyle(fontSize: 12, color: _sub)),
              ),
            )
          else
            for (int i = 0; i < members.length; i++) row(i),
        ],
      ),
    );
  }

  Widget _bottomInviteButton(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      color: _bg,
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 12),
      child: GestureDetector(
        onTap: _invite,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_brand, _accent]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _brand.withValues(alpha: 0.26),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.person_add_alt_1_rounded,
                  size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text('邀请成员',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  /// 当前登录用户的会员 id（用于在成员列表标记「我」），拿不到返回 null。
  int? _idOf(UserState userState) {
    final raw = userState.userInfo?['id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }
}

/// 家庭头像：网络图优先，缺失时用品牌色圆 + 家庭图标。
class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({this.url});

  final String? url;

  static const Color _brand = Color(0xFF7F6370);

  @override
  Widget build(BuildContext context) {
    final u = url;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1E7EA),
        border: Border.all(color: const Color(0xFFE7D9DF), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: (u != null && u.startsWith('http'))
          ? Image.network(
              u,
              fit: BoxFit.cover,
              width: 48,
              height: 48,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.home_rounded, size: 24, color: _brand),
            )
          : const Icon(Icons.home_rounded, size: 24, color: _brand),
    );
  }
}

/// 成员行：首字头像 + 昵称 + 角色标签 + 「我」标记。
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.roleLabel,
    required this.role,
    required this.avatar,
    required this.bg,
    required this.isMe,
    required this.showDivider,
  });

  final String name;
  final String roleLabel;
  final String role;
  final String? avatar;
  final Color bg;
  final bool isMe;
  final bool showDivider;

  static const Color _ink = Color(0xFF3D2E33);
  static const Color _divider = Color(0x66F1EAE4);

  @override
  Widget build(BuildContext context) {
    final url = avatar;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bg,
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: (url != null && url.startsWith('http'))
                    ? Image.network(
                        url,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _initial(),
                      )
                    : _initial(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6ECEF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('我',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFB08CA0))),
                      ),
                    ],
                  ],
                ),
              ),
              _RoleTag(roleLabel: roleLabel, role: role),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: _divider),
      ],
    );
  }

  Widget _initial() {
    final first = name.runes.isEmpty
        ? '?'
        : String.fromCharCode(name.runes.first);
    return Text(
      first,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF7F6370)),
    );
  }
}

/// 角色标签：所有者 / 管理员 / 成员。
class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.roleLabel, required this.role});

  final String roleLabel;
  final String role;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    if (role == 'owner') {
      bg = const Color(0xFFF6ECEF);
      fg = const Color(0xFFB08CA0);
    } else if (role == 'admin') {
      bg = const Color(0xFFFBEEE0);
      fg = const Color(0xFFD98E3B);
    } else {
      bg = const Color(0xFFF2EFEC);
      fg = const Color(0xFFA89EA2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(roleLabel,
          style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

/// 通用表单弹窗：邀请成员（手机号）与创建家庭（名称）共用。
/// [onSubmit] 返回 null 表示成功，否则为后端错误提示。
class _FamilyFormDialog extends StatefulWidget {
  const _FamilyFormDialog({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.confirmText,
    required this.validator,
    required this.onSubmit,
    this.keyboardType,
    this.maxLength,
  });

  final String title;
  final String subtitle;
  final String hint;
  final String confirmText;
  final String? Function(String value) validator;
  final Future<String?> Function(String value) onSubmit;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  State<_FamilyFormDialog> createState() => _FamilyFormDialogState();
}

class _FamilyFormDialogState extends State<_FamilyFormDialog> {
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _brand = Color(0xFF7F6370);
  static const Color _accent = Color(0xFFB48CA3);

  final TextEditingController _ctrl = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final value = _ctrl.text.trim();
    final err = widget.validator(value);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await widget.onSubmit(value);
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _sending = false;
        _error = result;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink)),
            const SizedBox(height: 6),
            Text(widget.subtitle,
                style: const TextStyle(
                    fontSize: 12, color: _sub, height: 1.5)),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4F1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _ctrl,
                enabled: !_sending,
                autofocus: true,
                keyboardType: widget.keyboardType,
                maxLength: widget.maxLength,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 14, color: _ink),
                // TDesign 主题给 InputDecorationTheme 设了 enabledBorder /
                // focusedBorder 下划线，必须逐状态覆盖，否则输入框会带一条下边框
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(fontSize: 13, color: _sub),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                  counterText: '',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFE05A5A))),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _sending
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F1EF),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: const Text('取消',
                          style: TextStyle(fontSize: 14, color: _sub)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _sending ? null : _submit,
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _sending
                              ? const [Color(0xFFC9BFC4), Color(0xFFD6CBCF)]
                              : const [_brand, _accent],
                        ),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Text(_sending ? '提交中…' : widget.confirmText,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
