import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../http/api_client.dart';
import 'pet_models.dart';

/// 宠物列表与展示状态。
///
/// 登录后由首页触发 [loadPets]：先拉 /app/pet/list，默认选中默认宠物，
/// 再拉 /app/pet/show/{id} 拿到顶部视频地址（mediaUrl）与封面（imgUrl）。
/// 首页顶部的宠物切换条通过 [selectPet] 切换，切换后重新拉取对应宠物的展示信息
/// （并调用 /app/pet/setDefaultPet 持久化默认宠物，与 f-cat 行为一致）。
class PetState extends ChangeNotifier {
  List<PetInfo> _pets = [];
  int _selectedIndex = 0;
  bool _loaded = false;
  bool _loading = false;

  String? _mediaUrl;
  String? _coverUrl;
  List<String> _words = [];

  /// 展示信息请求序号：快速切换宠物时，用序号丢弃过期响应，避免旧宠物的
  /// 视频/封面覆盖当前选中宠物。
  int _showEpoch = 0;

  PetState() {
    // 登录态变化时（退出登录）重置，便于重新登录后再次拉取
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!AuthService.instance.loggedIn) {
      _pets = [];
      _selectedIndex = 0;
      _mediaUrl = null;
      _coverUrl = null;
      _words = [];
      _loaded = false;
      _loading = false;
      notifyListeners();
    }
  }

  List<PetInfo> get pets => _pets;
  int get selectedIndex => _selectedIndex;
  bool get isLoaded => _loaded;
  bool get isEmpty => _pets.isEmpty;
  bool get isNotEmpty => _pets.isNotEmpty;

  /// 当前选中的宠物（可能为 null）。
  PetInfo? get selectedPet =>
      (_pets.isNotEmpty && _selectedIndex < _pets.length)
          ? _pets[_selectedIndex]
          : null;

  /// 顶部视频地址（来自当前选中宠物 /app/pet/show 的 mediaUrl）。
  String? get mediaUrl => _mediaUrl;

  /// 封面图地址（接口 imgUrl 优先，其次列表自带 petUserShow.imgUrl）。
  String? get coverUrl => _coverUrl;

  List<String> get words => _words;

  /// 切换选中宠物，重新加载对应展示信息并持久化默认宠物。
  void selectPet(int index) {
    if (index < 0 || index >= _pets.length || index == _selectedIndex) return;
    _selectedIndex = index;
    // 立即清掉上一个宠物的展示信息，否则切换瞬间顶部仍是旧宠物的视频，
    // 与新宠物昵称对不上号（先用列表自带封面兜底，请求返回后再补全）。
    _mediaUrl = null;
    _words = [];
    final listImg = _pets[index].petUserShow?['imgUrl'] as String?;
    _coverUrl =
        (listImg != null && listImg.isNotEmpty) ? listImg : null;
    notifyListeners();
    _loadShowForSelected();
    _setDefaultPet(_pets[index].id);
  }

  /// 添加/编辑宠物后强制重新拉取列表（loadPets 在加载中时会跳过）。
  Future<void> refresh() async {
    _loaded = false;
    await loadPets();
  }

  Future<void> loadPets() async {
    debugPrint('[PetState] loadPets called');
    if (_loading) return;
    _loading = true;
    try {
      // 无 Token 时不发起请求（未登录 / 测试环境），直接结束加载
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('[PetState] no access token, skip');
        _loaded = true;
        _loading = false;
        notifyListeners();
        return;
      }
      final res = await ApiClient.instance.get('/app/pet/list');
      debugPrint(
          '[PetState] /app/pet/list isSuccess=${res.isSuccess} msg=${res.message}');
      if (res.isSuccess && res.data is List) {
        _pets = (res.data as List)
            .map((e) => PetInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('[PetState] pets=${_pets.length}');
        final defaultIdx = _pets.indexWhere((p) => p.isDefault);
        _selectedIndex = defaultIdx >= 0 ? defaultIdx : 0;
        // 列表刷新后展示信息作废，重新拉取，避免残留上一个宠物的视频
        _mediaUrl = null;
        _coverUrl = null;
        _words = [];
        await _loadShowForSelected();
      }
    } catch (e) {
      debugPrint('[PetState] loadPets error: $e');
    }
    _loaded = true;
    _loading = false;
    notifyListeners();
  }

  Future<void> _setDefaultPet(int petId) async {
    try {
      await ApiClient.instance.post('/app/pet/setDefaultPet/$petId');
    } catch (e) {
      debugPrint('[PetState] setDefaultPet error: $e');
    }
  }

  Future<void> _loadShowForSelected() async {
    final pet = selectedPet;
    if (pet == null) return;
    final epoch = ++_showEpoch;
    // 列表自带封面先兜底
    final listImg = pet.petUserShow?['imgUrl'] as String?;
    if (listImg != null && listImg.isNotEmpty) _coverUrl = listImg;

    try {
      final res = await ApiClient.instance.get('/app/pet/show/${pet.id}');
      debugPrint(
          '[PetState] /app/pet/show/${pet.id} isSuccess=${res.isSuccess} msg=${res.message} data=${res.data}');
      // 响应回来时已切到别的宠物：丢弃，避免旧宠物数据覆盖当前选中项
      if (epoch != _showEpoch) return;
      if (res.isSuccess && res.isMap) {
        final show = PetShow.fromJson(res.asMap);
        // mediaUrl 为空时显式清空，便于 UI 走封面兜底
        _mediaUrl = (show.mediaUrl != null && show.mediaUrl!.isNotEmpty)
            ? show.mediaUrl
            : null;
        if (show.imgUrl != null && show.imgUrl!.isNotEmpty) {
          _coverUrl = show.imgUrl;
        }
        _words = show.words;
      }
    } catch (e) {
      debugPrint('[PetState] loadShow error: $e');
    }
    if (epoch != _showEpoch) return;
    debugPrint(
        '[PetState] => mediaUrl=$_mediaUrl coverUrl=$_coverUrl words=$_words');
    notifyListeners();
  }
}
