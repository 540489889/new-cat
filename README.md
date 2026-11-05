# New F Cat

基于 Flutter + [TDesign Flutter](https://tdesign.tencent.com/flutter/getting-started) 的基础工程脚手架。

## 环境要求

- Flutter >= 3.32.0（当前使用 3.44.0）
- Dart >= 3.8.0（当前使用 3.12.0）
- tdesign_flutter ^1.1.0

## 运行

```bash
flutter pub get
flutter run            # 选择设备
flutter run -d chrome  # Web 调试
```

## 目录结构

```
lib/
├── main.dart                     入口
├── app.dart                      MaterialApp / 主题 / 路由挂载
├── core/
│   ├── router/app_router.dart    路由表与 onGenerateRoute
│   └── theme/
│       ├── app_theme.dart        TDesign Token 与 ThemeData
│       └── theme_controller.dart 明暗模式控制器 + AppThemeScope
├── shared/
│   ├── layouts/main_shell.dart   底部 TTabBar 主框架
│   └── widgets/
│       ├── app_page.dart         页面骨架（导航栏 / 背景 / 滚动）
│       └── section_card.dart     区块卡片
└── features/
    ├── home/home_page.dart       首页：Hero / AI 日报 / Agent 动态 / 时间轴 / 悬浮提问栏
    ├── community/community_page.dart    猫圈（占位）
    ├── log/log_page.dart                日志（占位）
    ├── components/components_page.dart  组件速览（路由 /components）
    ├── settings/settings_page.dart      「我的」与主题切换
    └── demo/demo_detail_page.dart       二级页面 / 路由传参示例
```

## TDesign 使用要点

1. 统一入口导入，该入口已重新导出 Material：

   ```dart
   import 'package:tdesign_flutter/tdesign_flutter.dart';
   ```

2. 组件为 `T` 前缀：`TButton`、`TCell`、`TCellGroup`、`TTabBar`、`TNavBar`、
   `TTag`、`TSwitch`、`TToast`、`TDialog` 等，图标使用 `TIcons.xxx`。

3. 主题：`AppTheme` 基于 `TThemeData.defaultData()` 覆盖 `brandColor` Token，
   再通过 `TThemeBuilder.light/dark` 生成 `ThemeData`。业务里用
   `context.tTheme.brandColor` 等 Token 取值，避免硬编码颜色。

4. 换肤：`AppThemeScope.of(context).setMode(ThemeMode.dark)`，`MaterialApp`
   会重建并同步所有 TDesign 组件。

## 新增页面

1. 在 `lib/features/xxx/` 下新建 `xxx_page.dart`，用 `AppPage` 包裹内容；
2. 在 `AppRoutes` 增加路由常量，并在 `AppRouter.onGenerateRoute` 返回对应页面；
3. 通过 `Navigator.pushNamed(context, AppRoutes.xxx, arguments: ...)` 跳转。
