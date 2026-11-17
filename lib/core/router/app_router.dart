import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../features/components/components_page.dart';
import '../../features/demo/demo_detail_page.dart';
import '../../features/member/about_us_page.dart';
import '../../features/member/news_page.dart';
import '../../features/member/notification_settings_page.dart';
import '../../features/member/user_profile_page.dart';
import '../../features/pet/highlights_page.dart';
import '../../features/pet/pet_detail_page.dart';
import '../../features/settings/setting_prefs_page.dart';
import '../../shared/widgets/status_bar_style.dart';
import '../auth/auth_gate.dart';

/// 路由表，新增页面时在这里登记。
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String demoDetail = '/demo/detail';
  static const String components = '/components';
  static const String petDetail = '/pet/detail';
  static const String highlights = '/pet/highlights';
  static const String settings = '/settings';
  static const String userProfile = '/member/profile';
  static const String noticeSettings = '/member/notice-settings';
  static const String aboutUs = '/member/about';
  static const String news = '/member/news';
}

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return MaterialPageRoute(
          builder: (_) => const AuthGate(),
          settings: settings,
        );
      case AppRoutes.demoDetail:
        return MaterialPageRoute(
          builder: (_) => DemoDetailPage(
            entry: settings.arguments is String
                ? settings.arguments! as String
                : null,
          ),
          settings: settings,
        );
      case AppRoutes.components:
        return MaterialPageRoute(
          builder: (_) => const ComponentsPage(),
          settings: settings,
        );
      case AppRoutes.petDetail:
        return MaterialPageRoute(
          builder: (_) => const PetDetailPage(),
          settings: settings,
        );
      case AppRoutes.highlights:
        return MaterialPageRoute(
          builder: (_) => const HighlightsPage(),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingPrefsPage(),
          settings: settings,
        );
      case AppRoutes.userProfile:
        return MaterialPageRoute(
          builder: (_) => const UserProfilePage(),
          settings: settings,
        );
      case AppRoutes.noticeSettings:
        return MaterialPageRoute(
          builder: (_) => const NotificationSettingsPage(),
          settings: settings,
        );
      case AppRoutes.aboutUs:
        return MaterialPageRoute(
          builder: (_) => const AboutUsPage(),
          settings: settings,
        );
      case AppRoutes.news:
        return MaterialPageRoute(
          builder: (_) => const NewsPage(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => _NotFoundPage(routeName: settings.name),
          settings: settings,
        );
    }
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      child: Scaffold(
        appBar: TNavBar(
          title: const Text('页面不存在'),
          useDefaultBack: true,
          useSafeArea: true,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.tTheme.spacer3),
            child: Text(
              '未找到路由：${routeName ?? 'unknown'}',
              style: TextStyle(color: context.tTheme.textColorSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
