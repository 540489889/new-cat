import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 生日选择弹窗：tdesign 滚轮 [TDateTimePicker]（年/月/日）+ 顶部取消/确定。
///
/// 返回选中的日期（仅年月日，时分秒为 0）；取消或点蒙层返回 null。
Future<DateTime?> showBirthdayPicker(
  BuildContext context, {
  DateTime? initial,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BirthdayPickerSheet(initial: initial),
  );
}

class _BirthdayPickerSheet extends StatefulWidget {
  const _BirthdayPickerSheet({this.initial});

  /// 当前已选生日（未设置时回落到 3 年前的今天）
  final DateTime? initial;

  @override
  State<_BirthdayPickerSheet> createState() => _BirthdayPickerSheetState();
}

class _BirthdayPickerSheetState extends State<_BirthdayPickerSheet> {
  static const Color _brand = Color(0xFF7F6370);
  static const Color _ink = Color(0xFF3D2E33);
  static const Color _sub = Color(0xFFA89EA2);

  late DateTime _selected;
  late TDateTimePickerValue _value;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = widget.initial ?? DateTime(now.year - 3, now.month, now.day);
    _value = TDateTimePickerValue(
      year: _selected.year,
      month: _selected.month,
      day: _selected.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部操作栏
          SizedBox(
            height: 52,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '取消',
                    style: TextStyle(fontSize: 15, color: _sub),
                  ),
                ),
                Expanded(
                  child: Text(
                    '选择生日',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text(
                    '确定',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0x14000000)),
          // tdesign 滚轮：年 / 月 / 日
          TDateTimePicker(
            value: _value,
            mode: DateTimePickerMode(dateMode: DateMode.date),
            start: const TDateTimePickerValue(year: 1900, month: 1, day: 1),
            end: TDateTimePickerValue(
              year: now.year,
              month: now.month,
              day: now.day,
            ),
            onChanged: (v) {
              setState(() {
                _value = v;
                // 滚轮滚动时实时记录候选值，确定时回传
                _selected = v.toDateTime(fallback: _selected);
              });
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
