import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 通用确认弹窗：基于 tdesign [TDialog] 统一实现。
///
/// 样式与登录页「隐私政策和服务协议」弹窗保持一致：
/// - 无标题、正文 14px（与登录页协议富文本相同）；
/// - 取消按钮用默认 normal（浅色）；
/// - 确认按钮默认 primary（品牌色），[danger] 为 true 时用 destructive（红色），
///   适合删除、取消订单等破坏性操作。
/// 返回 true 表示用户确认，false/关闭表示取消。
Future<bool> showConfirmDialog(
  BuildContext context, {
  String? content,
  String cancelText = '取消',
  required String confirmText,
  bool danger = false,
}) async {
  final result = await TDialog.show<bool>(
    context,
    dialog: TDialog(
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
          role: danger
              ? TDialogActionRole.destructive
              : TDialogActionRole.primary,
        ),
      ],
    ),
  );
  return result == true;
}
