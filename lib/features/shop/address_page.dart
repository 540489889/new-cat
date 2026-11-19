import 'package:city_pickers/city_pickers.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/shop/shop_api.dart';
import '../../core/shop/shop_models.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/status_bar_style.dart';
import 'shop_theme.dart';

/// 收货地址管理页：列表 + 新增/编辑入口。
class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  List<ShopAddress> _list = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final res = await ShopApiService.addresses();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _list = res.isSuccess
          ? res.asList
              .whereType<Map<String, dynamic>>()
              .map(ShopAddress.fromJson)
              .toList()
          : const <ShopAddress>[];
      if (!res.isSuccess) {
        TToast.showText(res.message, context: context);
      }
    });
  }

  Future<void> _openEditor([ShopAddress? addr]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddressEditPage(address: addr)),
    );
    if (changed == true) _refresh();
  }

  Future<void> _delete(ShopAddress addr) async {
    final ok = await showConfirmDialog(
      context,
      content: '确定删除「${addr.name}」的收货地址吗？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    final res = await ShopApiService.deleteAddress(addr.id);
    if (!mounted) return;
    TToast.showText(res.isSuccess ? '已删除' : res.message, context: context);
    if (res.isSuccess) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F2),
        appBar: TNavBar(
          title: const Text('收货地址'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: ShopColors.pink))
            : _list.isEmpty
                ? const TEmpty(emptyText: '还没有收货地址')
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        12, 12, 12, 100 + bottomInset),
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final addr = _list[i];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openEditor(addr),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    addr.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: ShopColors.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(addr.phone,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: ShopColors.sub)),
                                  const Spacer(),
                                  if (addr.isDefault)
                                    const TTag(
                                      '默认',
                                      colorPreset: TTagColorPreset.primary,
                                      variant: TTagVariant.light,
                                      size: TTagSize.small,
                                      shape: TTagShape.round,
                                    ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _delete(addr),
                                    child: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: ShopColors.sub),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${addr.region} ${addr.detail}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: ShopColors.ink,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, bottomInset > 0 ? bottomInset * 0.3 : 12),
            child: TButton(
              size: TButtonSize.large,
              variant: TButtonVariant.fill,
              colorPreset: TButtonColorPreset.primary,
              shape: TButtonShape.round,
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => _openEditor(),
              child: const Text('新增收货地址'),
            ),
          ),
        ),
      ),
    );
  }
}

/// 地址编辑页（[address] 为空 = 新增）。
class AddressEditPage extends StatefulWidget {
  const AddressEditPage({super.key, this.address});

  final ShopAddress? address;

  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  final TextEditingController _region = TextEditingController();
  final TextEditingController _detail = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final addr = widget.address;
    _region.text = addr?.region ?? '';
    _detail.text = addr?.detail ?? '';
    _name.text = addr?.name ?? '';
    _phone.text = addr?.phone ?? '';
    _isDefault = addr?.isDefault ?? false;
  }

  @override
  void dispose() {
    _region.dispose();
    _detail.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  // ---------- 省市区选择（city_pickers 三级联动） ----------
  Future<void> _showRegionPicker() async {
    final result = await CityPickers.showCityPicker(
      context: context,
      showType: ShowType.pca, // 省/市/区三级
    );
    if (result != null && mounted) {
      setState(() {
        _region.text = [
          result.provinceName,
          result.cityName,
          result.areaName,
        ].whereType<String>().join(' ');
      });
    }
  }

  Future<void> _save() async {
    final region = _region.text.trim();
    final detail = _detail.text.trim();
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (region.isEmpty) {
      TToast.showText('请选择所在地区', context: context);
      return;
    }
    if (detail.isEmpty) {
      TToast.showText('请填写详细地址', context: context);
      return;
    }
    if (name.isEmpty) {
      TToast.showText('请填写收件人姓名', context: context);
      return;
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      TToast.showText('请输入正确的手机号', context: context);
      return;
    }
    setState(() => _saving = true);
    final addr = ShopAddress(
      id: widget.address?.id ?? 0,
      region: region,
      detail: detail,
      name: name,
      phone: phone,
      isDefault: _isDefault,
    );
    final res = widget.address == null
        ? await ShopApiService.addAddress(addr)
        : await ShopApiService.updateAddress(addr);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.isSuccess) {
      TToast.showText('保存成功', context: context);
      Navigator.of(context).pop(true);
    } else {
      TToast.showText(res.message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F2),
        appBar: TNavBar(
          title: Text(widget.address == null ? '新增收货地址' : '修改收货地址'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // 收货信息表单卡：左 label + 无边框输入行 + 分隔线
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('收货信息',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ShopColors.ink)),
                    const SizedBox(height: 6),
                    _fieldRow(
                      label: '所在地区',
                      hint: '请选择省/市/区',
                      controller: _region,
                      suffix: const Icon(Icons.chevron_right,
                          size: 20, color: ShopColors.sub),
                      onTap: _showRegionPicker,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1EAE4)),
                    _fieldRow(
                      label: '详细地址',
                      hint: '小区 / 楼栋 / 门牌号',
                      controller: _detail,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1EAE4)),
                    _fieldRow(
                      label: '收货人',
                      hint: '请输入收货人姓名',
                      controller: _name,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1EAE4)),
                    _fieldRow(
                      label: '手机号码',
                      hint: '请输入收货人手机号码',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 设为默认收货地址：独立白卡
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('设为默认收货地址',
                        style: TextStyle(
                            fontSize: 14, color: ShopColors.ink)),
                    const Spacer(),
                    TSwitch(
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16,
                bottomInset > 0 ? bottomInset * 0.3 : 12),
            child: TButton(
              size: TButtonSize.large,
              variant: TButtonVariant.fill,
              colorPreset: TButtonColorPreset.primary,
              shape: TButtonShape.round,
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('保存并使用'),
            ),
          ),
        ),
      ),
    );
  }

  /// 行式表单行：左固定宽 label + 无边框输入 + 可选后缀，整体可点（如省市区）。
  Widget _fieldRow({
    required String label,
    required String hint,
    required TextEditingController controller,
    Widget? suffix,
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: ShopColors.ink)),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: onTap != null,
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: 1,
                  readOnly: onTap != null,
                  style: const TextStyle(
                      fontSize: 14, color: ShopColors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    // 全局主题可能给输入框设了边框，逐个状态显式关闭，
                    // 否则与行间 Divider 叠成双线
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                        fontSize: 14, color: ShopColors.sub),
                  ),
                ),
              ),
            ),
            if (suffix != null) suffix,
          ],
        ),
      ),
    );
  }
}
