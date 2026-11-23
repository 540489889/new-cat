/// 宠物列表项（首页视频 + 宠物档案编辑共用）。
class PetInfo {
  final int id;
  final String nickname;
  final bool isDefault;
  final Map<String, dynamic>? petUserShow;
  final String headimg;

  // 档案资料（添加/编辑表单回填用）
  final String type; // cat / dog
  final String variety; // 品种
  final String sex; // male / female
  final String sterilization; // y / n
  final String birthday; // yyyy-MM-dd（或 ISO）
  final double weight; // kg

  PetInfo({
    required this.id,
    required this.nickname,
    required this.isDefault,
    this.petUserShow,
    this.headimg = '',
    this.type = '',
    this.variety = '',
    this.sex = '',
    this.sterilization = '',
    this.birthday = '',
    this.weight = 0,
  });

  factory PetInfo.fromJson(Map<String, dynamic> json) {
    final petUserShow = json['petUserShow'] as Map<String, dynamic>?;
    final headimg = (json['headimg'] as String?) ??
        (petUserShow?['headimg'] as String?) ??
        '';
    return PetInfo(
      id: json['id'] ?? 0,
      nickname: json['nickname'] ?? '',
      isDefault: json['default'] ?? false,
      petUserShow: petUserShow,
      headimg: headimg,
      type: json['type'] ?? '',
      variety: json['variety'] ?? '',
      sex: json['sex'] ?? '',
      sterilization: json['sterilization'] ?? '',
      birthday: json['birthday'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
    );
  }

  /// 年龄文案（基于 birthday）。
  String get ageLabel {
    if (birthday.isEmpty) return '/';
    final date = DateTime.tryParse(birthday);
    if (date == null) return '/';
    final diff = DateTime.now().difference(date);
    if (diff.inDays <= 0) return '1天';
    if (diff.inDays < 30) return '${diff.inDays}天';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月';
    return '${(diff.inDays / 365).floor()}岁';
  }

  /// 性别文案（GG/MM）。
  String get genderLabel => sex == 'male' ? 'GG' : 'MM';
}

/// 宠物展示信息（来自 /app/pet/show/{id}）。
class PetShow {
  final String? mediaUrl; // 顶部视频地址
  final String? imgUrl; // 视频缺失时的封面图地址
  final List<String> words; // 宠物心情/状态短句

  PetShow({this.mediaUrl, this.imgUrl, this.words = const []});

  factory PetShow.fromJson(Map<String, dynamic> json) {
    final rawWords = json['words'];
    final words = rawWords is List
        ? rawWords.map((e) => e.toString()).toList()
        : <String>[];
    return PetShow(
      mediaUrl: json['mediaUrl'] as String?,
      imgUrl: json['imgUrl'] as String?,
      words: words,
    );
  }
}
