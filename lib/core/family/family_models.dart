/// 家庭信息与家庭成员模型。
///
/// 字段对齐参考项目 f-cat 的 `/app/home/**` 接口：
/// - 家庭详情来自 `POST /app/home/info`（`id / name / avatar / inviteCode / ownerId / maxMembers`）；
/// - 成员列表来自 `GET /app/home/member/list?homeId=`（`memberId / nickname / role`，
///   参考项目接口无头像字段，这里兼容后端后续新增 headimg / avatar）。
class FamilyInfo {
  const FamilyInfo({
    required this.id,
    required this.name,
    this.avatar,
    this.inviteCode,
    this.ownerId,
    this.maxMembers,
  });

  final int id;
  final String name;
  final String? avatar;
  final String? inviteCode;
  final int? ownerId;
  final int? maxMembers;

  factory FamilyInfo.fromJson(Map<String, dynamic> json) {
    return FamilyInfo(
      // 参考项目接口返回的是 id（HomeInfo.fromJson 兼容 homeId）
      id: _toInt(json['id'] ?? json['homeId'] ?? json['home_id']),
      name: (json['name'] ?? '').toString(),
      avatar: _toStr(json['avatar']),
      inviteCode: _toStr(json['inviteCode'] ?? json['invite_code']),
      ownerId: _toIntOrNull(json['ownerId'] ?? json['owner_id']),
      maxMembers: _toIntOrNull(json['maxMembers'] ?? json['max_members']),
    );
  }

  FamilyInfo copyWith({String? name, String? avatar}) => FamilyInfo(
        id: id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        inviteCode: inviteCode,
        ownerId: ownerId,
        maxMembers: maxMembers,
      );
}

/// 单个家庭成员。
class FamilyMember {
  const FamilyMember({
    required this.memberId,
    required this.nickname,
    required this.role,
    this.avatar,
    this.mobile,
  });

  final int memberId;
  final String nickname;

  /// `owner`（所有者）/ `admin`（管理员）/ 其它视为普通成员。
  final String role;
  final String? avatar;
  final String? mobile;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get canManage => isOwner || isAdmin;

  String get roleLabel {
    if (isOwner) return '所有者';
    if (isAdmin) return '管理员';
    return '成员';
  }

  /// 展示名：昵称 → 手机号脱敏 → 用户 ID 兜底。
  ///
  /// 成员接口不返回昵称（实测 `nickname: null`），这里用 abs(memberId) 前 4 位
  /// 区分成员，兼容负数 id，避免参考项目 `substring(0, 4)` 的崩溃。
  String get displayName {
    if (nickname.isNotEmpty) return nickname;
    final m = mobile ?? '';
    if (m.length >= 11) return '${m.substring(0, 3)}****${m.substring(7)}';
    if (m.isNotEmpty) return m;
    if (memberId != 0) {
      final id = memberId.abs().toString();
      return '用户${id.length > 4 ? id.substring(0, 4) : id}';
    }
    return '家庭成员';
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      memberId: _toInt(json['memberId'] ?? json['member_id'] ?? json['id']),
      nickname: (json['nickname'] ??
              json['nickName'] ??
              json['name'] ??
              json['userName'] ??
              json['memberName'] ??
              '')
          .toString(),
      role: (json['role'] ?? 'member').toString(),
      avatar: _toStr(json['headimg'] ?? json['avatar']),
      mobile: _toStr(json['mobile'] ?? json['phone']),
    );
  }
}

int _toInt(dynamic v) => _toIntOrNull(v) ?? 0;

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _toStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}
