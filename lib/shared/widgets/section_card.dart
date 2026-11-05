import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 带标题的内容卡片，页面里的功能区块统一用它包一层。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final token = context.tTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: token.spacer / 2, bottom: token.spacer),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: token.textColorPrimary,
                        fontSize: token.fontTitleMedium?.size ?? 16,
                        height: token.fontTitleMedium?.height,
                        fontWeight:
                            token.fontTitleMedium?.fontWeight ??
                            FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: token.spacer / 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: token.textColorPlaceholder,
                          fontSize: token.fontBodySmall?.size ?? 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: padding ?? EdgeInsets.all(token.spacer2),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: token.bgColorContainer,
            borderRadius: BorderRadius.circular(token.radiusExtraLarge),
            border: Border.all(
              color: token.componentStroke.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          child: child,
        ),
        SizedBox(height: token.spacer3),
      ],
    );
  }
}
