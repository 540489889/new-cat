import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/pet/pet_api.dart';
import '../../core/pet/pet_models.dart';
import '../../core/pet/pet_state.dart';
import '../../core/router/app_router.dart';
import '../../shared/widgets/status_bar_style.dart';
import 'pet_3d_generated_page.dart';
import 'pet_add_guide_page.dart';
import '../shop/shop_theme.dart';

/// 添加 / 编辑宠物页。
/// 字段与参考项目 f-cat 的 AddPetPage 一致：
/// 头像、昵称、类型（猫/狗）、品种、性别、绝育、生日、体重。
/// 图片先上传拿 URL，再提交 JSON 给 /app/pet/add 或 /app/pet/update。
class PetEditPage extends StatefulWidget {
  const PetEditPage({super.key, this.pet});

  /// 传入宠物 = 编辑；不传 = 新增
  final PetInfo? pet;

  @override
  State<PetEditPage> createState() => _PetEditPageState();
}

class _PetEditPageState extends State<PetEditPage> {
  final _nameCtrl = TextEditingController();
  final _varietyCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  String _headimg = '';
  String _type = 'cat'; // cat / dog
  String _sex = 'male'; // male / female
  String _sterilization = 'n'; // y / n
  DateTime? _birthday;
  bool _saving = false;

  bool get _isEdit => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    if (pet != null) {
      _nameCtrl.text = pet.nickname;
      _varietyCtrl.text = pet.variety;
      _weightCtrl.text = pet.weight > 0 ? pet.weight.toStringAsFixed(1) : '';
      _headimg = pet.headimg;
      _type = pet.type == 'dog' ? 'dog' : 'cat';
      _sex = pet.sex == 'female' ? 'female' : 'male';
      _sterilization = pet.sterilization == 'y' ? 'y' : 'n';
      _birthday = DateTime.tryParse(pet.birthday);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _varietyCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _varietyCtrl.text.trim().isNotEmpty &&
      _birthday != null &&
      double.tryParse(_weightCtrl.text.trim()) != null;

  /// 性别 + 绝育合并展示文案
  String get _genderLabel {
    final gender = _sex == 'male' ? 'GG' : 'MM';
    return _sterilization == 'y' ? '绝育$gender' : gender;
  }

  /// 选头像 → 上传 → 回填 URL
  /// 跳转到添加向导的对应步骤编辑单个字段，完成后回填。
  Future<void> _editViaGuide(String target) async {
    final current = PetInfo(
      id: widget.pet?.id ?? 0,
      nickname: _nameCtrl.text,
      isDefault: widget.pet?.isDefault ?? false,
      petUserShow: widget.pet?.petUserShow,
      headimg: _headimg,
      type: _type,
      variety: _varietyCtrl.text,
      sex: _sex,
      sterilization: _sterilization,
      birthday: _birthday?.toIso8601String() ?? '',
      weight: double.tryParse(_weightCtrl.text) ?? 0,
    );
    final updated = await Navigator.of(context).push<PetInfo>(
      MaterialPageRoute<PetInfo>(
        builder: (_) => PetAddGuidePage(
          initialPet: current,
          editTarget: target,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _nameCtrl.text = updated.nickname;
      _headimg = updated.headimg;
      _type = updated.type.isEmpty ? _type : updated.type;
      _varietyCtrl.text = updated.variety;
      _sex = updated.sex.isEmpty ? _sex : updated.sex;
      _sterilization = updated.sterilization.isEmpty
          ? _sterilization
          : updated.sterilization;
      _birthday = DateTime.tryParse(updated.birthday) ?? _birthday;
      _weightCtrl.text = updated.weight > 0
          ? updated.weight.toStringAsFixed(1)
          : _weightCtrl.text;
    });
  }

  Future<void> _save() async {
    if (!_canSave || _saving) {
      TToast.showText('请填写完整资料', context: context);
      return;
    }
    final birthday =
        '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}T00:00:00.000Z';
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      final res = _isEdit
          ? await PetApiService.updatePet(
              id: widget.pet!.id,
              nickname: _nameCtrl.text.trim(),
              type: _type,
              variety: _varietyCtrl.text.trim(),
              sex: _sex,
              sterilization: _sterilization,
              birthday: birthday,
              weight: weight,
              headimg: _headimg,
            )
          : await PetApiService.addPet(
              nickname: _nameCtrl.text.trim(),
              type: _type,
              variety: _varietyCtrl.text.trim(),
              sex: _sex,
              sterilization: _sterilization,
              birthday: birthday,
              weight: weight,
              headimg: _headimg,
            );
      if (!mounted) return;
      if (!res.isSuccess) {
        TToast.showText(res.message, context: context);
        return;
      }
      // 刷新全局宠物列表
      await context.read<PetState>().refresh();
      if (!mounted) return;
      TToast.showSuccess(_isEdit ? '已保存' : '添加成功', context: context);
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: TNavBar(
          title: Text(_isEdit ? '编辑宠物资料' : '添加宠物'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            // 头像（左右排列：左标签，右圆形头像）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 72,
                    child: Text('头像',
                        style: TextStyle(fontSize: 14, color: ShopColors.ink)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _editViaGuide('photo'),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: ShopColors.tagBg,
                          backgroundImage: _headimg.isNotEmpty
                              ? NetworkImage(_headimg)
                              : null,
                          child: _headimg.isEmpty
                              ? const Icon(Icons.pets,
                                  size: 28, color: ShopColors.pink)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: ShopColors.pink,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 11, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 18, color: ShopColors.sub),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 表单卡
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _optionRow(
                    label: '昵称',
                    value: _nameCtrl.text.isEmpty ? '请填写' : _nameCtrl.text,
                    onTap: () => _editViaGuide('nickname'),
                  ),
                  _divider,
                  _optionRow(
                    label: '类型',
                    value: _type == 'cat' ? '喵星人' : '汪星人',
                    onTap: () => _editViaGuide('type'),
                  ),
                  _divider,
                  _optionRow(
                    label: '品种',
                    value: _varietyCtrl.text.isEmpty
                        ? '请选择'
                        : _varietyCtrl.text,
                    onTap: () async {
                      final v = await Navigator.of(context).pushNamed<String>(
                        AppRoutes.petVariety,
                        arguments: {
                          'mark': _type,
                          'initialVariety': _varietyCtrl.text,
                        },
                      );
                      if (v != null && mounted) {
                        setState(() => _varietyCtrl.text = v);
                      }
                    },
                  ),
                  _divider,
                  // 性别 + 绝育合并为一个选择页（GG / MM / 绝育GG / 绝育MM）
                  _optionRow(
                    label: '性别',
                    value: _genderLabel,
                    onTap: () => _editViaGuide('detail'),
                  ),
                  _divider,
                  _optionRow(
                    label: '生日',
                    value: _birthday == null
                        ? '请选择'
                        : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
                    onTap: () => _editViaGuide('detail'),
                  ),
                  _divider,
                  _optionRow(
                    label: '体重',
                    value: _weightCtrl.text.isEmpty
                        ? '请选择'
                        : '${_weightCtrl.text} kg',
                    onTap: () => _editViaGuide('detail'),
                  ),
                  if (_isEdit) ...[
                    _divider,
                    _optionRow(
                      label: '查看3D形象',
                      value: '',
                      labelWidth: 88,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Pet3DGeneratedPage(
                            imageUrl: _headimg.isNotEmpty ? _headimg : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? '更新资料' : '添加宠物'),
            ),
          ),
        ),
      ),
    );
  }

  static const Widget _divider = Divider(height: 1, color: Color(0xFFF1EAE4));

  Widget _optionRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    double labelWidth = 72,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(label,
                  style: const TextStyle(fontSize: 14, color: ShopColors.ink)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: ShopColors.ink)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: ShopColors.sub),
          ],
        ),
      ),
    );
  }
}
