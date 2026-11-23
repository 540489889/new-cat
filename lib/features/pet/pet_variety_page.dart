import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/pet/cates_api.dart';
import '../../shared/widgets/status_bar_style.dart';
import '../shop/shop_theme.dart';

/// 品种选择页：按首字母分组 + 搜索 + 右侧字母索引（对齐参考项目 VarietyPage）。
/// mark: cat / dog；pop 返回品种名称 String。
class PetVarietyPage extends StatefulWidget {
  const PetVarietyPage({super.key, required this.mark, this.initialVariety});

  final String mark; // cat / dog
  final String? initialVariety;

  @override
  State<PetVarietyPage> createState() => _PetVarietyPageState();
}

class _PetVarietyPageState extends State<PetVarietyPage> {
  final _searchCtrl = TextEditingController();
  final _sectionKeys = <String, GlobalKey>{};

  bool _loading = true;
  String _query = '';
  List<BreedItem> _all = [];
  List<BreedItem> _hot = []; // 热门品种：接口返回列表前 10 个
  Map<String, List<BreedItem>> _data = {};
  Map<String, List<BreedItem>> _filtered = {};
  String? _selected;

  List<String> get _keys => _filtered.keys.toList()..sort();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialVariety;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q == _query) return;
      setState(() {
        _query = q;
        _applyFilter();
      });
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    _sectionKeys.clear();
    if (_query.isEmpty) {
      _filtered = Map.from(_data);
    } else {
      _filtered = {};
      for (final b in _all) {
        if (b.title.toLowerCase().contains(_query.toLowerCase())) {
          _filtered.putIfAbsent(b.title[0].toUpperCase(), () => []).add(b);
        }
      }
    }
    for (final k in _filtered.keys) {
      _sectionKeys[k] = GlobalKey();
    }
  }

  Future<void> _load() async {
    final res = await CatesApiService.getCatesTree(mark: widget.mark);
    if (!mounted) return;
    if (res.isSuccess && res.isMap) {
      final map = res.asMap;
      final all = <BreedItem>[];
      final data = <String, List<BreedItem>>{};
      for (final entry in map.entries) {
        final list = (entry.value as List<dynamic>?)
                ?.map((e) => BreedItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <BreedItem>[];
        data[entry.key] = list;
        all.addAll(list);
      }
      setState(() {
        _loading = false;
        _all = all;
        _hot = all.take(10).toList();
        _data = data;
        _applyFilter();
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _scrollTo(String key) {
    final ctx = _sectionKeys[key]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 250), alignment: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: TNavBar(
          title: const Text('选择品种'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: ShopColors.pink))
            : Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // 搜索框
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                size: 20, color: ShopColors.sub),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: '搜索品种',
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 热门品种（无搜索词时展示）
                      if (_query.isEmpty && _hot.isNotEmpty) ...[
                        const Text('热门品种',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ShopColors.ink)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _hot
                              .map((b) => _hotChip(b))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // 搜索结果提示
                      if (_query.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('搜索结果',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ShopColors.ink)),
                        ),
                      // 分组列表
                      ..._keys.map((key) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                key: _sectionKeys[key],
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 8),
                                child: Text(key,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: ShopColors.ink)),
                              ),
                              ..._filtered[key]!.map((b) => _breedRow(b)),
                            ],
                          )),
                    ],
                  ),
                  // 右侧字母索引
                  Positioned(
                    right: 0,
                    top: 80,
                    bottom: 24,
                    child: SizedBox(
                      width: 20,
                      child: ListView(
                        primary: false,
                        children: _keys
                            .map((k) => GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _scrollTo(k),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 3),
                                    child: Text(k,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: ShopColors.pink)),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _hotChip(BreedItem b) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, b.title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(b.title,
            style: const TextStyle(fontSize: 13, color: ShopColors.ink)),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Image.asset('assets/images/pet_avatar.png', fit: BoxFit.cover);
  }

  Widget _breedRow(BreedItem b) {
    final selected = _selected == b.title;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context, b.title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: b.icon.isNotEmpty
                    ? Image.network(
                        b.icon,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _defaultAvatar(),
                      )
                    : _defaultAvatar(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(b.title,
                  style: const TextStyle(
                      fontSize: 14, color: ShopColors.ink)),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: ShopColors.pink, size: 20),
          ],
        ),
      ),
    );
  }
}
