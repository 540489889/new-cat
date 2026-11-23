import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../shared/widgets/status_bar_style.dart';
import '../shop/shop_theme.dart';

/// 通用选择页：顶部大标题 + 返回箭头 + 副标题。
class _OptionScaffold extends StatelessWidget {
  const _OptionScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.keyboard_arrow_left, size: 32),
                    ),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: ShopColors.ink)),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(subtitle,
                    style: const TextStyle(
                        fontSize: 15, color: ShopColors.sub)),
              ),
              const SizedBox(height: 20),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// 宠物类型：喵星人 / 汪星人（pop 返回 'cat' / 'dog'）。
class PetTypePage extends StatelessWidget {
  const PetTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _OptionScaffold(
      title: '宠物类型',
      subtitle: '请选择您的宠物类型',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: _bigCard(
                color: const Color(0xFF8E6B84),
                title: '喵星人',
                onTap: () => Navigator.pop(context, 'cat'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _bigCard(
                color: const Color(0xFFD98E3B),
                title: '汪星人',
                onTap: () => Navigator.pop(context, 'dog'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigCard({
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            const Positioned(
              right: 12,
              bottom: 12,
              child: Icon(Icons.pets, size: 56, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

/// 宠物性别 + 绝育：GG / MM / 绝育GG / 绝育MM
/// pop 返回 {sex: male|female, sterilization: y|n, label: ...}。
class PetGenderPage extends StatelessWidget {
  const PetGenderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _OptionScaffold(
      title: '宠物性别',
      subtitle: '请选择宠物性别与绝育情况',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _genderCard(context, 'GG', Icons.male,
                      const Color(0xFF4A84F0), 'male', 'n'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _genderCard(context, 'MM', Icons.female,
                      const Color(0xFFF78233), 'female', 'n'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _genderCard(context, '绝育GG', Icons.face,
                      const Color(0xFFF7B030), 'male', 'y'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _genderCard(context, '绝育MM', Icons.favorite,
                      const Color(0xFF03C7CA), 'female', 'y'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderCard(BuildContext context, String label, IconData icon,
      Color color, String sex, String sterilization) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, <String, String>{
        'sex': sex,
        'sterilization': sterilization,
        'label': label,
      }),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Icon(icon, size: 44, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// 宠物体重：滑块选择（猫 0~10kg / 狗 0~50kg），pop 返回 String。
class PetWeightPage extends StatefulWidget {
  const PetWeightPage({
    super.key,
    required this.petType,
    required this.initialWeight,
  });

  final String petType; // cat / dog
  final double initialWeight;

  @override
  State<PetWeightPage> createState() => _PetWeightPageState();
}

class _PetWeightPageState extends State<PetWeightPage> {
  late double _weight;

  double get _maxWeight => widget.petType == 'dog' ? 50 : 10;

  @override
  void initState() {
    super.initState();
    _weight = widget.initialWeight.clamp(0, _maxWeight);
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.keyboard_arrow_left, size: 32),
                    ),
                    const Expanded(
                      child: Text('宠物体重',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: ShopColors.ink)),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const SizedBox(height: 54),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_weight.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.price)),
                  const SizedBox(width: 6),
                  const Text('Kg',
                      style: TextStyle(fontSize: 20, color: ShopColors.sub)),
                ],
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Slider(
                  value: _weight,
                  min: 0,
                  max: _maxWeight,
                  divisions: (_maxWeight * 10).toInt(),
                  activeColor: ShopColors.pink,
                  onChanged: (v) => setState(() => _weight = v),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TButton(
                    size: TButtonSize.large,
                    variant: TButtonVariant.fill,
                    colorPreset: TButtonColorPreset.primary,
                    shape: TButtonShape.round,
                    onPressed: () =>
                        Navigator.pop(context, _weight.toStringAsFixed(1)),
                    child: const Text('完成'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
