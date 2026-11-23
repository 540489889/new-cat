import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/http/api_client.dart';
import '../../core/pet/pet_api.dart';
import '../../core/pet/pet_models.dart';
import '../../core/pet/pet_state.dart';
import '../../core/router/app_router.dart';
import '../../shared/widgets/date_picker_sheet.dart';
import '../../shared/widgets/image_picker_dialog.dart';
import '../../shared/widgets/status_bar_style.dart';
import 'pet_3d_generation_page.dart';
import '../shop/shop_theme.dart';

/// 添加宠物 4 步向导：
/// ① 类型（猫/狗）→ ② 上传照片（正脸/侧身/全身）→ ③ 介绍宠物（语音/手动）→ ④ 资料（头像/性别/品种/昵称/生日/体重）→ 提交。
/// 顶部 4 段进度条，样式对齐 UI 图（紫粉高亮 + 灰色未完成）。
class PetAddGuidePage extends StatefulWidget {
  const PetAddGuidePage({
    super.key,
    this.initialPet,
    this.editTarget,
  });

  /// 编辑模式：传入已有宠物 + 目标步骤，隐藏进度条，改完直接返回数据。
  /// editTarget: type / photo / nickname / detail（性别/生日/体重/绝育）。
  final PetInfo? initialPet;
  final String? editTarget;

  bool get isEditMode => initialPet != null && editTarget != null;

  @override
  State<PetAddGuidePage> createState() => _PetAddGuidePageState();
}

class _PetAddGuidePageState extends State<PetAddGuidePage> {
  static const int _totalSteps = 4;
  int _step = 0;

  String _type = ''; // cat / dog（默认不选中，对齐 UI 图，用户点选后才赋值）
  String _sex = 'male';
  String _sterilization = 'n';
  String _variety = '';
  DateTime? _birthday;
  String _headimg = '';

  /// 三张照片（正脸 / 侧身 / 全身），对齐参考项目 figure.dart 的 front/side/body。
  final List<String?> _petPhotos = [null, null, null];
  final List<bool> _photoUploading = [false, false, false];

  /// 第③步介绍内容（语音识别结果或手动输入），用于提交时一并带给后端。
  final _introCtrl = TextEditingController();
  final _introFocus = FocusNode();
  bool _listening = false; // 语音聆听中的 UI 态（无 ASR 依赖时仅作占位）
  bool _manualMode = false; // 第③步：false 语音介绍 / true 手动填昵称
  bool _detailStep = false; // 手动模式下：false 昵称输入 / true 性别年龄体重绝育

  /// 手动输入模式的昵称推荐池（点击「换一批」轮换）。
  static const List<List<String>> _nicknameGroups = [
    ['奶芙', '团子', '米糕', '逗包', '奶盖'],
    ['豆包', '布丁', '可可', '汤圆', '芝麻'],
    ['奶油', '年糕', '球球', '小七', '花卷'],
  ];
  int _nicknameGroupIndex = 0;

  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  /// 详细信息子页：性别用 male/female，绝育 y/n，年龄以周岁数字展示。
  String _detailSex = '';
  String _detailSterilization = '';
  final _ageCtrl = TextEditingController();

  bool _saving = false;

  bool get _allPhotosUploaded =>
      _petPhotos.every((url) => url != null && url.isNotEmpty);

  bool get _editing => widget.isEditMode;

  @override
  void initState() {
    super.initState();
    final pet = widget.initialPet;
    if (!_editing || pet == null) return;
    // 回填已有宠物资料
    _type = pet.type;
    _variety = pet.variety;
    _sex = pet.sex;
    _sterilization = pet.sterilization;
    _birthday = DateTime.tryParse(pet.birthday);
    _weightCtrl.text = pet.weight > 0 ? pet.weight.toStringAsFixed(1) : '';
    _nameCtrl.text = pet.nickname;
    _headimg = pet.headimg;
    _detailSex = _sex;
    _detailSterilization = _sterilization;
    _petPhotos[0] = pet.headimg.isNotEmpty ? pet.headimg : null;
    // 根据目标打开对应步骤 / 子页
    switch (widget.editTarget) {
      case 'type':
        _step = 0;
        break;
      case 'photo':
        _step = 1;
        break;
      case 'nickname':
        _step = 2;
        _manualMode = true;
        break;
      case 'detail':
        _step = 2;
        _manualMode = true;
        _detailStep = true;
        break;
    }
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _introFocus.dispose();
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_editing) {
      _finishEdit();
      return;
    }
    if (_step < _totalSteps - 1) setState(() => _step++);
  }

  /// 编辑模式：把当前状态组装成 PetInfo 返回给编辑页。
  void _finishEdit() {
    final pet = widget.initialPet!;
    Navigator.of(context).pop<PetInfo>(PetInfo(
      id: pet.id,
      nickname: _nameCtrl.text.trim().isEmpty ? pet.nickname : _nameCtrl.text.trim(),
      isDefault: pet.isDefault,
      petUserShow: pet.petUserShow,
      headimg: _headimg,
      type: _type.isEmpty ? pet.type : _type,
      variety: _variety.isEmpty ? pet.variety : _variety,
      sex: _sex,
      sterilization: _sterilization,
      birthday: _birthday?.toIso8601String() ?? pet.birthday,
      weight: double.tryParse(_weightCtrl.text.trim()) ?? pet.weight,
    ));
  }

  void _previous() {
    // 第③步手动模式下，返回键逐层回退：详细信息 → 昵称 → 语音介绍。
    if (_step == 2 && _manualMode) {
      setState(() {
        if (_detailStep) {
          _detailStep = false;
        } else {
          _manualMode = false;
        }
      });
      return;
    }
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 上传宠物照片（scene=pet），index: 0 正脸 / 1 侧身 / 2 全身。
  Future<void> _uploadPetPhoto(int index) async {
    if (_photoUploading[index]) return;
    final source = await showImagePickerDialog(context);
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _photoUploading[index] = true);
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
      setState(() {
        _petPhotos[index] = url;
        // 正脸照同时作为默认头像，用户可在资料步骤自行覆盖。
        if (index == 0) _headimg = url;
      });
    } finally {
      if (mounted) setState(() => _photoUploading[index] = false);
    }
  }

  Future<void> _pickBirthday() async {
    // 用 TDesign 滚轮日期弹窗（与项目「我的-生日」一致）。
    final picked = await showBirthdayPicker(context, initial: _birthday);
    if (picked != null && mounted) setState(() => _birthday = picked);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _variety.isEmpty ||
        _birthday == null ||
        double.tryParse(_weightCtrl.text.trim()) == null) {
      TToast.showText('请填写完整的昵称 / 品种 / 生日 / 体重', context: context);
      return;
    }
    if (_saving) return;
    final birthday =
        '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}T00:00:00.000Z';
    setState(() => _saving = true);
    try {
      final res = await PetApiService.addPet(
        nickname: _nameCtrl.text.trim(),
        type: _type,
        variety: _variety,
        sex: _sex,
        sterilization: _sterilization,
        birthday: birthday,
        weight: double.tryParse(_weightCtrl.text.trim()) ?? 0,
        headimg: _headimg.isNotEmpty
            ? _headimg
            : (_petPhotos[0] ?? ''),
        imgFace: _petPhotos[0],
        imgBody: _petPhotos[1],
        imgWhole: _petPhotos[2],
      );
      if (!mounted) return;
      if (!res.isSuccess) {
        TToast.showText(res.message, context: context);
        return;
      }
      await context.read<PetState>().refresh();
      if (!mounted) return;
      // 提交成功后进入 3D 形象生成过程页（参考项目链路）。
      final imageUrl = _headimg.isNotEmpty ? _headimg : _petPhotos[0];
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Pet3DGenerationPage(petImageUrl: imageUrl),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F6F7),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              if (!_editing) _progressBar(),
              Expanded(child: _stepBody()),
              if (_step == 3 && !_editing)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16,
                        bottomInset > 0 ? bottomInset * 0.3 : 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TButton(
                        size: TButtonSize.large,
                        variant: TButtonVariant.fill,
                        colorPreset: TButtonColorPreset.primary,
                        shape: TButtonShape.round,
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('生成专属3D形象'),
                      ),
                    ),
                  ),
                ),
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
            onTap: _previous,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.keyboard_arrow_left,
                  size: 24, color: ShopColors.ink),
            ),
          ),
          const Expanded(
            child: Text('添加宠物',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: ShopColors.ink)),
          ),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      // 短粗条居中：每段固定宽，不再通栏拉满
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalSteps, (i) {
          final active = i <= _step;
          return Container(
            width: 50,
            height: 5,
            margin: EdgeInsets.only(right: i == _totalSteps - 1 ? 0 : 12),
            decoration: BoxDecoration(
              color: active ? ShopColors.pink : const Color(0xFFE6E0E3),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _typeStep();
      case 1:
        return _photoStep();
      case 2:
        return _introStep();
      default:
        return _profileStep();
    }
  }

  Widget _heading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ShopColors.ink)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(fontSize: 14, color: ShopColors.sub)),
        ],
      ),
    );
  }

  /// ① 宠物类型（UI 图 1:1）
  Widget _typeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('宠物类型', '请选择您的宠物类型'),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _typeCard(
                  selected: _type == 'cat',
                  title: '喵星人',
                  icon: 'assets/images/icon/cat-ico.png',
                  onTap: () {
                    setState(() => _type = 'cat');
                    Future.delayed(const Duration(milliseconds: 180), _next);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _typeCard(
                  selected: _type == 'dog',
                  title: '汪星人',
                  icon: 'assets/images/icon/dog-ico.png',
                  onTap: () {
                    setState(() => _type = 'dog');
                    Future.delayed(const Duration(milliseconds: 180), _next);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeCard({
    required bool selected,
    required String title,
    required String icon,
    required VoidCallback onTap,
  }) {
    final theme = const Color(0xFF8E6B84);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? theme : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0F000000),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : ShopColors.ink)),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : Colors.white,
                    border: Border.all(
                      color: selected
                          ? Colors.white
                          : const Color(0xFFD9D2D6),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check, size: 15, color: theme)
                      : null,
                ),
              ],
            ),
            Positioned(
              right: 6,
              bottom: 0,
              // 图标按选中态染色：选中紫底上显示白色，未选中白底上显示灰色
              child: Image.asset(
                icon,
                width: 52,
                height: 52,
                color: selected ? Colors.white : const Color(0xFFB8B0B5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ② 上传宠物照片（正脸 / 侧身 / 全身），对齐参考项目 figure.dart。
  Widget _photoStep() {
    // 占位剪影按宠物类型切换：猫用猫头/猫身，狗用参考项目的狗剪影。
    final icons = _type == 'dog'
        ? const [
            'assets/images/icon/photo1.png',
            'assets/images/icon/photo2.png',
            'assets/images/icon/photo3.png',
          ]
        : const [
            'assets/images/icon/photo1.png',
            'assets/images/icon/cat-ico.png',
            'assets/images/icon/cat-ico.png',
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('上传宠物照片', '添加 3 个角度，3D形象更精准'),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _photoItem(
                index: 0,
                title: '正脸照',
                subtitle: '请拍摄宠物正脸清晰的照片',
                iconAsset: icons[0],
              ),
              _photoItem(
                index: 1,
                title: '侧身照',
                subtitle: '请拍摄宠物侧身的照片',
                iconAsset: icons[1],
              ),
              _photoItem(
                index: 2,
                title: '全身照',
                subtitle: '请拍摄宠物全身的照片',
                iconAsset: icons[2],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: GestureDetector(
              onTap: _allPhotosUploaded ? _next : null,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  // 上传齐全用更深的品牌紫，避免淡粉看起来像白色蒙层。
                  color: _allPhotosUploaded
                      ? const Color(0xFF8E6B84)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: Text(
                    '下一步',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _allPhotosUploaded
                            ? Colors.white
                            : const Color(0xFFAAAAAA)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoItem({
    required int index,
    required String title,
    required String subtitle,
    required String iconAsset,
  }) {
    final url = _petPhotos[index];
    final uploading = _photoUploading[index];
    final hasPhoto = url != null && url.isNotEmpty;
    final accent = ShopColors.pink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          // 底部对齐：让右侧图片底边与左侧「点击上传」行齐平。
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: ShopColors.ink)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: ShopColors.sub)),
                  const SizedBox(height: 22),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: uploading ? null : () => _uploadPetPhoto(index),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/icon/camera.png',
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Text('点击上传',
                            style: TextStyle(fontSize: 14, color: accent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: uploading ? null : () => _uploadPetPhoto(index),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  // 白色圆角块，无额外灰层；已上传：照片铺满。
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  image: hasPhoto
                      ? DecorationImage(
                          image: NetworkImage(url), fit: BoxFit.cover)
                      : null,
                ),
                child: uploading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: accent),
                        ),
                      )
                    : hasPhoto
                        ? Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                margin: const EdgeInsets.all(6),
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                    color: accent, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt,
                                    size: 14, color: Colors.white),
                              ),
                            ],
                          )
                        : Center(
                            // photo1/2/3 自带浅灰剪影+白底，不能整体染色（会把白底一起染掉导致图标不可见）；
                            // cat-ico 是白色剪影+透明底，才需要染成浅灰。
                            child: Image.asset(
                              iconAsset,
                              width: 56,
                              height: 56,
                              fit: BoxFit.contain,
                              color: iconAsset.contains('cat-ico')
                                  ? const Color(0xFFE6E6E6)
                                  : null,
                            ),
                          ),
              ),
            ),
          ],
        ),
        // 加粗分隔线，并在上下留出安全距离（height 为占位高度，线居中）。
        const Divider(height: 32, thickness: 2, color: Color(0xFFEEEEEE)),
      ],
    );
  }

  /// ③ 性别 + 绝育
  /// ③ 介绍宠物：语音介绍 / 手动填昵称两种模式。
  Widget _introStep() {
    if (_manualMode && _detailStep) return _detailIntroStep();
    if (_manualMode) return _manualIntroStep();
    return _voiceIntroStep();
  }

  /// ③-a 语音介绍界面（UI 对齐截图）。
  Widget _voiceIntroStep() {
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('先来介绍一下它', '你可以通过语音或手动输入来介绍它'),
        const SizedBox(height: 24),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('语音内容',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ShopColors.ink)),
                  const SizedBox(height: 14),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F4F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _introCtrl,
                      focusNode: _introFocus,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (_introCtrl.text.trim().isNotEmpty) _next();
                      },
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: ShopColors.ink),
                      decoration: const InputDecoration(
                        hintText: '例如：它叫豆包，是只比熊，性别是弟弟，2岁，体重15斤"',
                        hintStyle: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: Color(0xFFB7B1BB)),
                        contentPadding:
                            EdgeInsets.fromLTRB(16, 16, 16, 16),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GestureDetector(
                    onTap: _toggleListening,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E6B84),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _listening ? Icons.stop_circle_outlined : Icons.mic_none,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _listening ? '停止语音输入' : '开始语音输入',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GestureDetector(
                    onTap: () => setState(() => _manualMode = true),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFFE5DFE3)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/icon/edit.png',
                              width: 18,
                              height: 18,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 8),
                            const Text('手动输入',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8E6B84))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  /// ③-b 手动输入模式：昵称输入 + 昵称推荐 + 下一步（UI 对齐截图）。
  Widget _manualIntroStep() {
    final names = _nicknameGroups[_nicknameGroupIndex];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('先来介绍一下它',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.ink)),
                  const SizedBox(height: 8),
                  const Text('你可以通过语音或手动输入来介绍它',
                      style: TextStyle(fontSize: 14, color: ShopColors.sub)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('昵称',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ShopColors.ink)),
            const SizedBox(height: 12),
            Container(
              height: 44,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 16, color: ShopColors.ink),
                decoration: const InputDecoration(
                  hintText: '请填写昵称',
                  hintStyle: TextStyle(fontSize: 15, color: Color(0xFFB7B1BB)),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Text('昵称推荐',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ShopColors.ink)),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _nicknameGroupIndex =
                      (_nicknameGroupIndex + 1) % _nicknameGroups.length),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh,
                          size: 16, color: Color(0xFF8E6B84)),
                      const SizedBox(width: 4),
                      const Text('换一批',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF8E6B84))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: names.map((name) {
                return GestureDetector(
                  onTap: () => setState(() => _nameCtrl.text = name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 15, color: ShopColors.ink)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: GestureDetector(
                onTap: _nameCtrl.text.trim().isEmpty
                    ? null
                    : () {
                        if (_editing) {
                          _finishEdit();
                        } else {
                          setState(() => _detailStep = true);
                        }
                      },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFE5DFE3)),
                  ),
                  child: Center(
                    child: Text(
                      '下一步',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _nameCtrl.text.trim().isEmpty
                              ? ShopColors.sub
                              : const Color(0xFF8E6B84)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _manualMode = false),
                child: const Text(
                  '返回语音输入',
                  style: TextStyle(fontSize: 14, color: ShopColors.sub),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ③-c 详细信息子页：性别 / 年龄 / 体重 / 是否绝育（UI 对齐截图）。
  Widget _detailIntroStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('先来介绍一下它',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.ink)),
                  const SizedBox(height: 8),
                  const Text('你可以通过语音或手动输入来介绍它',
                      style: TextStyle(fontSize: 14, color: ShopColors.sub)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('性别',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ShopColors.ink)),
            const SizedBox(height: 12),
            Row(
              children: [
                _detailChoice('弟弟', 'male', _detailSex, (v) {
                  setState(() {
                    _detailSex = v;
                    _sex = v;
                  });
                }),
                const SizedBox(width: 10),
                _detailChoice('妹妹', 'female', _detailSex, (v) {
                  setState(() {
                    _detailSex = v;
                    _sex = v;
                  });
                }),
                const SizedBox(width: 10),
                _detailChoice('未知', 'unknown', _detailSex, (v) {
                  setState(() => _detailSex = v);
                }),
              ],
            ),
            const SizedBox(height: 24),
            const Text('宠物年龄',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ShopColors.ink)),
            const SizedBox(height: 12),
            _detailField(
              hint: '请选择年龄',
              suffix: '',
              onTap: _pickBirthday,
              value: _formatAge(),
            ),
            const SizedBox(height: 24),
            const Text('体重',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ShopColors.ink)),
            const SizedBox(height: 12),
            _detailField(
              hint: '请选择体重',
              suffix: 'kg',
              onTap: _pickDetailWeight,
              value: _weightCtrl.text.trim().isEmpty ? null : _weightCtrl.text,
            ),
            const SizedBox(height: 24),
            const Text('是否绝育',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ShopColors.ink)),
            const SizedBox(height: 12),
            Row(
              children: [
                _detailChoice('是', 'y', _detailSterilization, (v) {
                  setState(() {
                    _detailSterilization = v;
                    _sterilization = v;
                  });
                }),
                const SizedBox(width: 10),
                _detailChoice('否', 'n', _detailSterilization, (v) {
                  setState(() {
                    _detailSterilization = v;
                    _sterilization = v;
                  });
                }),
                const SizedBox(width: 10),
                _detailChoice('未知', 'unknown', _detailSterilization, (v) {
                  setState(() => _detailSterilization = v);
                }),
              ],
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: GestureDetector(
                onTap: _next,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFE5DFE3)),
                  ),
                  child: const Center(
                    child: Text('下一步',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8E6B84))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChoice(
      String label, String value, String current, ValueChanged<String> onTap) {
    final selected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF6ECEF) : Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
                color: selected
                    ? const Color(0xFF8E6B84)
                    : const Color(0xFFEDEAEC)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: selected
                      ? const Color(0xFF8E6B84)
                      : ShopColors.ink)),
        ),
      ),
    );
  }

  Widget _detailField({
    required String hint,
    required String suffix,
    TextEditingController? controller,
    String? value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: controller != null
                  ? TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(fontSize: 15, color: ShopColors.ink),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(
                            fontSize: 15, color: Color(0xFFB7B1BB)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : Text(
                      value ?? hint,
                      style: TextStyle(
                          fontSize: 15,
                          color: value == null
                              ? const Color(0xFFB7B1BB)
                              : ShopColors.ink),
                    ),
            ),
            const SizedBox(width: 8),
            Text(suffix,
                style: const TextStyle(fontSize: 15, color: ShopColors.sub)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: ShopColors.sub),
          ],
        ),
      ),
    );
  }

  /// 年龄展示：对齐参考项目 _formatAge（N年M个月 / N个月 / N天）。
  /// 无有效生日返回 null，让 _detailField 显示「请选择年龄」提示。
  String? _formatAge() {
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

  /// 体重：底部弹窗 + 刻度条（Slider）选择，猫 0~10kg / 狗 0~50kg，步长 0.1。
  Future<void> _pickDetailWeight() async {
    final max = _type == 'dog' ? 50.0 : 10.0;
    double weight = (double.tryParse(_weightCtrl.text.trim()) ?? 4.0)
        .clamp(0.0, max);
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
                            color: Color(0xFF8E6B84))),
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
                  activeColor: const Color(0xFF8E6B84),
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

  /// 语音输入：当前工程未接入 ASR 依赖，先给出提示并聚焦手动输入框。
  void _toggleListening() {
    if (_listening) {
      setState(() => _listening = false);
      return;
    }
    TToast.showText('当前设备暂不支持语音识别，请使用手动输入', context: context);
    _introFocus.requestFocus();
  }

  /// ④ 宠物信息确认（对齐 UI 图）：分组卡片展示，点击回访对应选择。
  Widget _profileStep() {
    final typeLabel = _type == 'dog' ? '汪星人' : '喵星人';
    final sexLabel = _sex == 'female' ? '妹妹' : '弟弟';
    final stLabel = _sterilization == 'y'
        ? '已绝育'
        : (_sterilization == 'n' ? '未绝育' : '未知');
    final photoCount = _petPhotos.where((u) => u != null && u.isNotEmpty).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        _heading('宠物信息确认', '信息已同步，核对后生成 3D 形象'),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
        _confirmCard([
          _confirmRow('昵称', _nameCtrl.text.isEmpty ? '未填写' : _nameCtrl.text,
              onTap: () => _editConfirmField('昵称', _nameCtrl)),
        ]),
        const SizedBox(height: 12),
        _confirmCard([
          _confirmRow('宠物类型', typeLabel,
              onTap: () => _gotoStep(0)),
          _confirmDivider,
          _confirmRow('品种', _variety.isEmpty ? '未选择' : _variety,
              onTap: _pickVariety),
        ]),
        const SizedBox(height: 12),
        _confirmCard([
          _confirmRow('性别', sexLabel, onTap: () => _gotoStep(2)),
          _confirmDivider,
          _confirmRow('是否绝育', stLabel, onTap: () => _gotoStep(2)),
        ]),
        const SizedBox(height: 12),
        _confirmCard([
          _confirmRow('宠物年龄', _formatAge() ?? '请选择', onTap: _pickBirthday),
          _confirmDivider,
          _confirmRow(
              '体重',
              _weightCtrl.text.trim().isEmpty
                  ? '请选择'
                  : '${_weightCtrl.text}kg', onTap: _pickDetailWeight),
        ]),
        const SizedBox(height: 12),
        _confirmCard([
          _confirmRow('宠物照片', '已传 $photoCount 张', onTap: () => _gotoStep(1)),
        ]),
            ],
          ),
        ),
      ],
    );
  }

  /// 跳回指定步骤重新编辑。
  void _gotoStep(int step) => setState(() => _step = step);

  /// 品种：push 独立选择页回填。
  Future<void> _pickVariety() async {
    final v = await Navigator.of(context).pushNamed<String>(
      AppRoutes.petVariety,
      arguments: {'mark': _type, 'initialVariety': _variety},
    );
    if (v != null && v.isNotEmpty && mounted) setState(() => _variety = v);
  }

  /// 确认页分组白卡。
  Widget _confirmCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: rows),
    );
  }

  static const Widget _confirmDivider = Padding(
    padding: EdgeInsets.only(left: 20),
    child: Divider(height: 1, thickness: 0.5, color: Color(0xFFEFEDEF)),
  );

  Widget _confirmRow(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 15, color: ShopColors.sub)),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ShopColors.ink)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: ShopColors.sub),
          ],
        ),
      ),
    );
  }

  /// 点击确认页字段弹出输入框编辑。
  Future<void> _editConfirmField(String label, TextEditingController ctrl) async {
    final edited = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final tmp = TextEditingController(text: ctrl.text);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('编辑$label',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: ShopColors.ink)),
                const SizedBox(height: 16),
                TextField(
                  controller: tmp,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16, color: ShopColors.ink),
                  decoration: InputDecoration(
                    hintText: '请输入$label',
                    hintStyle: const TextStyle(
                        fontSize: 15, color: Color(0xFFB7B1BB)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: const Color(0xFFF6F4F8),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TButton(
                    size: TButtonSize.large,
                    variant: TButtonVariant.fill,
                    colorPreset: TButtonColorPreset.primary,
                    shape: TButtonShape.round,
                    onPressed: () => Navigator.pop(ctx, tmp.text.trim()),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (edited != null && edited.isNotEmpty && mounted) {
      setState(() => ctrl.text = edited);
    }
  }

}
