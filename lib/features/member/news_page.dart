import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/http/api_client.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 消息中心入口（对齐参考项目 f-cat 的 news.dart）：
/// 宠物消息 / 设备消息 / 公告 三类入口，点击进入对应列表。
class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _brand = Color(0xFF7F6370);
  static const Color _divider = Color(0x66F1EAE4);

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('消息中心'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            _Card(
              child: Column(
                children: [
                  _EntryRow(
                    icon: Icons.pets_rounded,
                    title: '宠物消息',
                    type: 'pet',
                  ),
                  Container(height: 1, color: _divider),
                  _EntryRow(
                    icon: Icons.devices_other_rounded,
                    title: '设备消息',
                    type: 'device',
                  ),
                  Container(height: 1, color: _divider),
                  _EntryRow(
                    icon: Icons.campaign_rounded,
                    title: '公告',
                    type: 'notice',
                  ),
                ],
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

class _EntryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String type;

  const _EntryRow({
    required this.icon,
    required this.title,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DeviceNewsPage(type: type)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E9EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: NewsPage._brand),
            ),
            const SizedBox(width: 12),
            Text(title,
                style: const TextStyle(fontSize: 15, color: NewsPage._ink)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 16, color: NewsPage._sub),
          ],
        ),
      ),
    );
  }
}

/// 消息列表页（对齐参考项目 f-cat 的 device_news.dart）：
/// 分页加载 `GET /app/msg/list`，支持全部已读、单条已读。
class DeviceNewsPage extends StatefulWidget {
  /// pet / device / notice
  final String type;

  const DeviceNewsPage({super.key, required this.type});

  @override
  State<DeviceNewsPage> createState() => _DeviceNewsPageState();
}

class _DeviceNewsPageState extends State<DeviceNewsPage> {
  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);

  static const int _pageSize = 20;

  final List<Map<String, dynamic>> _items = [];
  final ScrollController _scrollCtrl = ScrollController();
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 120) {
      if (!_loading && _hasMore) _load();
    }
  }

  String get _title => switch (widget.type) {
        'pet' => '宠物消息',
        'device' => '设备消息',
        'notice' => '公告',
        _ => '消息',
      };

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _items.clear();
      }
    });
    final res = await ApiClient.instance.get(
      '/app/msg/list',
      queryParams: {
        'page': _page,
        'pageSize': _pageSize,
        'type': widget.type,
      },
    );
    if (!mounted) return;
    if (res.isSuccess) {
      final List<dynamic> records;
      final data = res.data;
      if (data is List) {
        records = data;
      } else if (res.isMap) {
        final m = res.asMap;
        final inner = m['records'] ?? m['list'] ?? m['data'];
        records = inner is List ? inner : const [];
      } else {
        records = const [];
      }
      setState(() {
        _items.addAll(
          records.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
        _hasMore = records.length >= _pageSize;
        if (_hasMore) _page += 1;
        _loading = false;
        _initialLoading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _initialLoading = false;
        _hasMore = false;
      });
      TToast.showText(res.message, context: context);
    }
  }

  /// 全部已读
  Future<void> _readAll() async {
    final res = await ApiClient.instance.post(
      '/app/msg/read/all',
      body: {'type': widget.type},
    );
    if (!mounted) return;
    if (res.isSuccess) {
      setState(() {
        for (final item in _items) {
          item['isRead'] = 1;
        }
      });
      TToast.showSuccess('已全部标记为已读', context: context);
    } else {
      TToast.showText(res.message, context: context);
    }
  }

  /// 单条已读
  Future<void> _readOne(Map<String, dynamic> item) async {
    if (_isRead(item)) return;
    final id = item['id'];
    if (id == null) return;
    final res = await ApiClient.instance.post('/app/msg/read/$id');
    if (!mounted) return;
    if (res.isSuccess) {
      setState(() => item['isRead'] = 1);
    }
  }

  bool _isRead(Map<String, dynamic> item) {
    final v = item['isRead'];
    return v == 1 || v == true || v == '1';
  }

  String _titleOf(Map<String, dynamic> item) =>
      (item['title'] ?? item['deviceName'] ?? '通知').toString();

  String _contentOf(Map<String, dynamic> item) =>
      (item['content'] ?? item['message'] ?? '').toString();

  String _timeOf(Map<String, dynamic> item) =>
      (item['createTime'] ?? item['sendTime'] ?? item['time'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: Text(_title),
          useDefaultBack: true,
          useSafeArea: true,
          actions: [
            TNavBarItem(
              customWidget: const Text('全部已读',
                  style: TextStyle(fontSize: 13, color: _ink)),
              onTap: _readAll,
            ),
          ],
        ),
        body: _initialLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
            : _items.isEmpty
                ? const Center(
                    child: Text('暂无消息',
                        style: TextStyle(fontSize: 13, color: _sub)),
                  )
                : ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final read = _isRead(item);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _readOne(item),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (!read)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE05A5A),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(_titleOf(item),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _ink)),
                                  ),
                                  Text(_timeOf(item),
                                      style: const TextStyle(
                                          fontSize: 11, color: _sub)),
                                ],
                              ),
                              if (_contentOf(item).isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(_contentOf(item),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF5C4A50),
                                        height: 1.5)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
