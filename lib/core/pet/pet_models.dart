/// 宠物列表项（首页视频接口只需要 id / 是否默认 / 列表自带封面）。
class PetInfo {
  final int id;
  final String nickname;
  final bool isDefault;
  final Map<String, dynamic>? petUserShow;
  final String headimg;

  PetInfo({
    required this.id,
    required this.nickname,
    required this.isDefault,
    this.petUserShow,
    this.headimg = '',
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
    );
  }
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
