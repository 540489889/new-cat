import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 通用确认弹窗：基于 tdesign [TDialog] 统一实现。
///
/// 样式与登录页「隐私政策和服务协议」弹窗保持一致：
/// - 正文 14px（与登录页协议富文本相同）；
/// - 取消按钮用默认 normal（浅色），确认按钮用 primary（品牌色），
///   按钮文字大小由 tdesign 主题统一管理。
/// 返回 true 表示用户确认，false/关闭表示取消。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? content,
  String cancelText = '取消',
  required String confirmText,
}) async {
  final result = await TDialog.show<bool>(
    context,
    dialog: TDialog(
      // 暂时去掉标题（预览无标题样式）；title 参数保留，需要时改回 Text(title)
      content: Text(
        content ?? '',
        style: const TextStyle(fontSize: 14),
      ),
      actions: [
        TDialogAction(
          child: Text(cancelText),
          result: false,
        ),
        TDialogAction(
          child: Text(confirmText),
          result: true,
          role: TDialogActionRole.primary,
        ),
      ],
    ),
  );
  return result == true;
}
