import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/http/api_client.dart';
import '../../core/pet/pet_models.dart';
import '../../shared/widgets/date_picker_sheet.dart';
import '../../shared/widgets/image_picker_dialog.dart';
import '../../shared/widgets/status_bar_style.dart';
import '../shop/shop_theme.dart';

/// 单字段编辑页：从「编辑宠物资料」进入，一次只改一个字段。
///
/// 与添加向导彻底分离，因此没有「上一步」：左上角返回 = 放弃退出，
/// 底部「保存」才把改动带回上一页。字段：
/// - photo    头像
/// - nickname 昵称
/// - type     类型（猫 / 狗）
/// - detail   性别 / 绝育 / 生日 / 体重
class PetFieldEditPage extends StatefulWidget {
  const PetFieldEditPage({
    super.key,
    required this.pet,
    required this.field,
  });

  /// 当前资料，用于回填；返回时未被编辑的字段原样带回
  final PetInfo pet;

  /// photo / nickname / type / detail
  final String field;

  @override
  State<PetFieldEditPage> createState() => _PetFieldEditPageState();
}

class _PetFieldEditPageState extends State<PetFieldEditPage> {
  static const Color _theme = Color(0xFF8E6B84);

  final _nicknameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  String _headimg = '';
  String _type = 'cat';
  String _sex = 'male';
  String _sterilization = 'n';
  DateTime? _birthday;

  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    _headimg = pet.headimg;
    _type = pet.type == 'dog' ? 'dog' : 'cat';
    _sex = pet.sex == 'female' ? 'female' : 'male';
    _sterilization = pet.sterilization == 'y' ? 'y' : 'n';
    _birthday = DateTime.tryParse(pet.birthday);
    _nicknameCtrl.text = pet.nickname;
    _weightCtrl.text = pet.weight > 0 ? pet.weight.toStringAsFixed(1) : '';
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.field) {
      case 'photo':
        return '编辑头像';
      case 'nickname':
        return '编辑昵称';
      case 'type':
        return '编辑类型';
      default:
        return '编辑资料';
    }
  }

  /// 保存按钮是否可用（detail 允许留空，留空即沿用原值）
  bool get _canSave {
    switch (widget.field) {
      case 'photo':
        return _headimg.isNotEmpty;
      case 'nickname':
        return _nicknameCtrl.text.trim().isNotEmpty;
      case 'type':
        return _type.isNotEmpty;
      default:
        return true;
    }
  }

  /// 把当前状态组装成新的 PetInfo 返回；未被编辑的字段取原值
  void _save() {
    if (!_canSave) return;
    final pet = widget.pet;
    Navigator.of(context).pop<PetInfo>(PetInfo(
      id: pet.id,
      nickname:
          _nicknameCtrl.text.trim().isEmpty ? pet.nickname : _nicknameCtrl.text.trim(),
      isDefault: pet.isDefault,
      petUserShow: pet.petUserShow,
      headimg: _headimg,
      type: _type.isEmpty ? pet.type : _type,
      variety: pet.variety,
      sex: _sex,
      sterilization: _sterilization,
      birthday: _birthday?.toIso8601String() ?? pet.birthday,
      weight: double.tryParse(_weightCtrl.text.trim()) ?? pet.weight,
    ));
  }

  /// 选图 → 上传（scene=pet）→ 回填 URL
  Future<void> _pickPhoto() async {
    if (_uploading) return;
    final source = await showImagePickerDialog(context);
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
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
        extraFields: {'scene': 'pet'},
      );
      if (!mounted) return;
      if (!res.isSuccess) {
        TToast.showText(res.message, context: context);
        return;
      }
      final url = res.data is String
          ? res.data as String
          : (res.asMap['url']?.toString() ?? '');
      if (url.isEmpty) {
        TToast.showText('上传返回为空', context: context);
        return;
      }
      setState(() => _headimg = url);
    } catch (e) {
      if (mounted) TToast.showText('上传失败：$e', context: context);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showBirthdayPicker(context, initial: _birthday);
    if (picked != null && mounted) setState(() => _birthday = picked);
  }

  /// 体重：底部弹窗 + 刻度条，猫 0~10kg / 狗 0~50kg，步长 0.1
  Future<void> _pickWeight() async {
    final max = _type == 'dog' ? 50.0 : 10.0;
    double weight =
        (double.tryParse(_weightCtrl.text.trim()) ?? 4.0).clamp(0.0, max);
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('选择体重',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: ShopColors.ink)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(weight.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: _theme)),
                    const SizedBox(width: 6),
                    const Text('kg',
                        style: TextStyle(fontSize: 18, color: ShopColors.sub)),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: weight,
                  min: 0,
                  max: max,
                  divisions: (max * 10).toInt(),
                  activeColor: _theme,
                  onChanged: (v) => setSheet(() => weight = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TButton(
                    size: TButtonSize.large,
                    variant: TButtonVariant.fill,
                    colorPreset: TButtonColorPreset.primary,
                    shape: TButtonShape.round,
                    onPressed: () => Navigator.pop(ctx, weight),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _weightCtrl.text = picked.toStringAsFixed(1));
    }
  }

  /// 年龄展示：N年M个月 / N个月 / N天
  String? get _ageLabel {
    final d = _birthday;
    if (d == null) return null;
    final now = DateTime.now();
    final days = now.difference(d).inDays;
    if (days < 0) return null;
    if (days < 30) return '$days天';
    var years = now.year - d.year;
    var months = now.month - d.month;
    if (now.day < d.day) months--;
    if (months < 0) {
      years--;
      months += 12;
    }
    if (years > 0 && months > 0) return '$years年$months个月';
    if (years > 0) return '$years年';
    return '$months个月';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: _body(),
                ),
              ),
              _bottomBar(bottomInset),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 单字段编辑没有「上一步」，返回即放弃修改
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.keyboard_arrow_left,
                  size: 24, color: ShopColors.ink),
            ),
          ),
          Expanded(
            child: Text(_title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: ShopColors.ink)),
          ),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _bottomBar(double bottomInset) {
    final enabled = _canSave;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, bottomInset > 0 ? bottomInset * 0.3 : 16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _save : null,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: enabled ? _theme : const Color(0xFFE9E3E6),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text('保存',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.white : ShopColors.sub)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (widget.field) {
      case 'photo':
        return _photoBody();
      case 'nickname':
        return _nicknameBody();
      case 'type':
        return _typeBody();
      default:
        return _detailBody();
    }
  }

  Widget _photoBody() {
    return Column(
      children: [
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickPhoto,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: Colors.white,
                backgroundImage:
                    _headimg.isNotEmpty ? NetworkImage(_headimg) : null,
                child: _headimg.isEmpty
                    ? const Icon(Icons.pets, size: 40, color: ShopColors.pink)
                    : null,
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _theme,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _uploading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.photo_camera,
                        size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(_uploading ? '上传中…' : '点击更换头像',
            style: const TextStyle(fontSize: 14, color: ShopColors.sub)),
      ],
    );
  }

  Widget _nicknameBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('宠物昵称',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ShopColors.ink)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _nicknameCtrl,
            maxLength: 12,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 16, color: ShopColors.ink),
            // TextField 会优先用 enabledBorder / focusedBorder，
            // 只写 border: none 仍会露出默认下划线，必须三条都置空
            decoration: const InputDecoration(
              hintText: '给它起个名字',
              hintStyle: TextStyle(fontSize: 16, color: Color(0xFFB7B1BB)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _typeBody() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _typeCard(
                title: '喵星人',
                icon: 'assets/images/icon/cat-ico.png',
                value: 'cat',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _typeCard(
                title: '汪星人',
                icon: 'assets/images/icon/dog-ico.png',
                value: 'dog',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typeCard({
    required String title,
    required String icon,
    required String value,
  }) {
    final selected = _type == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _type = value),
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _theme : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? _theme : const Color(0xFFEDEAEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : ShopColors.ink)),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: selected ? Colors.white : const Color(0xFFD9D2D6),
                ),
              ],
            ),
            const Spacer(),
            Image.asset(icon, width: 64, height: 64),
          ],
        ),
      ),
    );
  }

  Widget _detailBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _label('性别'),
        Row(
          children: [
            _choice('弟弟', _sex == 'male', () => setState(() => _sex = 'male')),
            const SizedBox(width: 10),
            _choice('妹妹', _sex == 'female',
                () => setState(() => _sex = 'female')),
          ],
        ),
        const SizedBox(height: 24),
        _label('是否绝育'),
        Row(
          children: [
            _choice('已绝育', _sterilization == 'y',
                () => setState(() => _sterilization = 'y')),
            const SizedBox(width: 10),
            _choice('未绝育', _sterilization == 'n',
                () => setState(() => _sterilization = 'n')),
          ],
        ),
        const SizedBox(height: 24),
        _label('生日'),
        _field(
          value: _birthday == null
              ? null
              : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
          hint: '请选择生日',
          suffix: _ageLabel ?? '',
          onTap: _pickBirthday,
        ),
        const SizedBox(height: 24),
        _label('体重'),
        _field(
          value: _weightCtrl.text.trim().isEmpty ? null : _weightCtrl.text,
          hint: '请选择体重',
          suffix: 'kg',
          onTap: _pickWeight,
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ShopColors.ink)),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6ECEF) : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
              color: selected ? _theme : const Color(0xFFEDEAEC)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? _theme : ShopColors.ink)),
      ),
    );
  }

  Widget _field({
    required String? value,
    required String hint,
    String suffix = '',
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                    fontSize: 15,
                    color: value == null
                        ? const Color(0xFFB7B1BB)
                        : ShopColors.ink),
              ),
            ),
            if (suffix.isNotEmpty)
              Text(suffix,
                  style: const TextStyle(fontSize: 14, color: ShopColors.sub)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: ShopColors.sub),
          ],
        ),
      ),
    );
  }
}
