import 'package:flutter/material.dart';

import '../../core/pet/pet_models.dart';
import '../../core/pet/pet_state.dart';

/// 弹出底部宠物选择面板：横向卡片 + 错落入场动画，点击即切换。
/// 供首页顶部切换条与宠物页档案卡共用。
void showPetPicker(BuildContext context, PetState petState) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PetPickerSheet(petState: petState),
  );
}

/// 宠物选择底部面板：横向卡片 + 错落弹入动画，选中项带主题色光环。
class _PetPickerSheet extends StatefulWidget {
  final PetState petState;
  const _PetPickerSheet({required this.petState});

  @override
  State<_PetPickerSheet> createState() => _PetPickerSheetState();
}

class _PetPickerSheetState extends State<_PetPickerSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pets = widget.petState.pets;
    final selected = widget.petState.selectedIndex;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽手柄
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 头部：左→右主题渐变标题栏
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF7F6370), Color(0xFF9E6F84)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7F6370).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.pets, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('选择你的毛孩子',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Spacer(),
                  Text('左右滑也能切',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 宠物卡片：横向列表，错落入场
            SizedBox(
              height: 152,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pets.length,
                itemBuilder: (_, i) {
                  final delay = (i * 0.08).clamp(0.0, 1.0);
                  final curve = Interval(delay, (delay + 0.5).clamp(0.0, 1.0),
                      curve: Curves.easeOutCubic);
                  final animated = SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: _ctrl, curve: curve)),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0, end: 1)
                          .animate(CurvedAnimation(parent: _ctrl, curve: curve)),
                      child: _PetCard(
                        pet: pets[i],
                        selected: i == selected,
                        onTap: () {
                          widget.petState.selectPet(i);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                  // 卡片间 14px 间距（首项不加左间距）
                  return i == 0
                      ? animated
                      : Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: animated);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 单个宠物卡片：选中态带主题渐变光环 + 高亮，未选中为浅灰描边。
class _PetCard extends StatelessWidget {
  final PetInfo pet;
  final bool selected;
  final VoidCallback onTap;
  const _PetCard(
      {required this.pet, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final head = pet.headimg;
    final name = pet.nickname.isNotEmpty ? pet.nickname : '宠物';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 110,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF7F6370)
                : const Color(0xFFEDE6E3),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7F6370).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 渐变光环头像
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF7F6370), Color(0xFF9E6F84)])
                    : const LinearGradient(
                        colors: [Color(0xFFEDE6E3), Color(0xFFEDE6E3)]),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFF3ECEA),
                backgroundImage:
                    head.isNotEmpty ? NetworkImage(head) : null,
                child:
                    head.isEmpty ? Text(name.isNotEmpty ? name[0] : '?') : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF7F6370)
                      : const Color(0xFF3D2E33),
                )),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF7F6370) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(selected ? '当前' : '选择',
                  style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF9A8F93),
                      fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }
}
