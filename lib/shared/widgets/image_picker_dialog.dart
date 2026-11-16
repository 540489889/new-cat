import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 通用图片选择弹窗（对齐参考项目 f-cat 的 `showImagePickerDialog`）。
///
/// 从底部弹出「拍照 / 从相册选择 / 取消」，返回用户选中的 [ImageSource]；
/// 取消或点击蒙层时返回 null。
Future<ImageSource?> showImagePickerDialog(BuildContext context) {
  // 品牌紫：与「我的」页/资料页的强调色一致
  const brand = Color(0xFF7F6370);

  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // 顶部拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: brand),
            title: const Text('拍照'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: brand),
            title: const Text('从相册选择'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 12),
          // 取消：灰底圆角按钮
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F0EA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  '取消',
                  style: TextStyle(fontSize: 16, color: Color(0xFF8A8085)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
