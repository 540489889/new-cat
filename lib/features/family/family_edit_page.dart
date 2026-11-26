import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/family/family_models.dart';
import '../../core/family/family_state.dart';
import '../../core/http/api_client.dart';
import '../../shared/widgets/image_picker_dialog.dart';
import '../../shared/widgets/status_bar_style.dart';

/// 编辑家庭：修改家庭名称、更换家庭头像。
///
/// 头像走 `POST /app/user/file/upload`（multipart，`scene=avatar`），
/// 保存走 `POST /app/home/update`（`homeId + name + avatar`），
/// 与参考项目 f-cat 的 edit_family 页一致。
class FamilyEditPage extends StatefulWidget {
  const FamilyEditPage({super.key, required this.home});

  final FamilyInfo home;

  @override
  State<FamilyEditPage> createState() => _FamilyEditPageState();
}

class _FamilyEditPageState extends State<FamilyEditPage> {
  static const Color _bg = Color(0xFFF7F2ED);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);
  static const Color _brand = Color(0xFF7F6370);
  static const Color _accent = Color(0xFFB48CA3);

  late final TextEditingController _nameCtrl;
  String? _avatar;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.home.name);
    _avatar = widget.home.avatar;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// 选图 → 上传（scene=avatar）→ 回填 URL。
  Future<void> _pickAvatar() async {
    if (_uploading || _saving) return;
    final source = await showImagePickerDialog(context);
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
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
        extraFields: {'scene': 'avatar'},
      );
      if (!mounted) return;
      if (!res.isSuccess) {
        TToast.showText(
            res.message.isEmpty ? '头像上传失败' : '头像上传失败：${res.message}',
            context: context);
        return;
      }
      // 响应可能是 url 字符串，也可能是 {url: ...}
      final url = res.data is String
          ? res.data as String
          : (res.asMap['url'] ?? res.asMap['path'] ?? '').toString();
      if (url.isEmpty) {
        TToast.showText('头像上传失败', context: context);
        return;
      }
      setState(() => _avatar = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      TToast.showText('请输入家庭名称', context: context);
      return;
    }
    if (name.length > 12) {
      TToast.showText('家庭名称最多 12 个字', context: context);
      return;
    }
    setState(() => _saving = true);
    final err = await context
        .read<FamilyState>()
        .updateFamily(name: name, avatar: _avatar);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      TToast.showText(err, context: context);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: _bg,
        appBar: TNavBar(
          title: const Text('编辑家庭'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottom + 24),
          children: [
            _avatarCard(),
            const SizedBox(height: 12),
            _nameCard(),
            const SizedBox(height: 24),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _avatarCard() {
    final url = _avatar;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: GestureDetector(
          onTap: _pickAvatar,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF1E7EA),
                      border: Border.all(
                          color: const Color(0xFFE7D9DF), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: (url != null && url.startsWith('http'))
                        ? Image.network(url,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.home_rounded,
                                size: 34,
                                color: _brand))
                        : const Icon(Icons.home_rounded,
                            size: 34, color: _brand),
                  ),
                  if (_uploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0x66000000),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _brand,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo_camera_outlined,
                          size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('点击更换家庭头像',
                  style: TextStyle(fontSize: 12, color: _sub)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('家庭名称',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink)),
          TextField(
            controller: _nameCtrl,
            enabled: !_saving,
            maxLength: 12,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _ink),
            decoration: const InputDecoration(
              hintText: '请输入家庭名称',
              hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _sub),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0x66F1EAE4)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0x66F1EAE4)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _accent),
              ),
              counterStyle: TextStyle(fontSize: 11, color: _sub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _saving
                ? const [Color(0xFFC9BFC4), Color(0xFFD6CBCF)]
                : const [_brand, _accent],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _brand.withValues(alpha: _saving ? 0.10 : 0.26),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(_saving ? '保存中…' : '保存',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }
}
