import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 通用确认弹窗：基于 tdesign [TDialog] 统一实现。
///
/// - 外观跟随 tdesign 主题（含深浅色联动、圆角与按钮样式）；
/// - [destructive] 为 true 时确认按钮使用危险色（退出登录、注销账户等），
///   否则使用品牌色主要按钮。
/// 返回 true 表示用户确认，false/关闭表示取消。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? content,
  String cancelText = '取消',
  required String confirmText,
  bool destructive = true,
}) async {
  final result = await TDialog.show<bool>(
    context,
    dialog: TDialog(
      // 暂时去掉标题（预览无标题样式）；title 参数保留，需要时改回 Text(title)
      content: Text(content ?? ''),
      actions: [
        TDialogAction(
          child: Text(cancelText),
          result: false,
          role: TDialogActionRole.normal,
        ),
        TDialogAction(
          child: Text(confirmText),
          result: true,
          role: destructive
              ? TDialogActionRole.destructive
              : TDialogActionRole.primary,
        ),
      ],
    ),
  );
  return result == true;
}
