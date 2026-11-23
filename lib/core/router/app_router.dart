import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../features/components/components_page.dart';
import '../../features/login/bind_mobile_page.dart';
import '../../features/demo/demo_detail_page.dart';
import '../../features/member/about_us_page.dart';
import '../../features/member/feedback_page.dart';
import '../../features/member/news_page.dart';
import '../../features/member/notification_settings_page.dart';
import '../../features/member/user_profile_page.dart';
import '../../features/pet/highlights_page.dart';
import '../../features/pet/pet_add_guide_page.dart';
import '../../features/pet/pet_detail_page.dart';
import '../../features/pet/pet_edit_page.dart';
import '../../features/pet/pet_option_pages.dart';
import '../../features/pet/pet_variety_page.dart';
import '../../features/settings/setting_prefs_page.dart';
import '../../features/shop/address_page.dart';
import '../../features/shop/goods_detail_page.dart';
import '../../features/shop/order_list_page.dart';
import '../../features/shop/pay_order_page.dart';
import '../../features/shop/pay_success_page.dart';
import '../../features/shop/shop_page.dart';
import '../../shared/widgets/status_bar_style.dart';
import '../auth/auth_gate.dart';
import '../pet/pet_models.dart';
import '../shop/shop_models.dart';

/// 路由表，新增页面时在这里登记。
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String bindMobile = '/login/bind-mobile';
  static const String demoDetail = '/demo/detail';
  static const String components = '/components';
  static const String petDetail = '/pet/detail';
  static const String petAdd = '/pet/add';
  static const String petEdit = '/pet/edit';
  static const String petType = '/pet/select/type';
  static const String petGender = '/pet/select/gender';
  static const String petVariety = '/pet/select/variety';
  static const String petWeight = '/pet/select/weight';
  static const String highlights = '/pet/highlights';
  static const String settings = '/settings';
  static const String userProfile = '/member/profile';
  static const String noticeSettings = '/member/notice-settings';
  static const String aboutUs = '/member/about';
  static const String news = '/member/news';
  static const String feedback = '/member/feedback';
  static const String shop = '/shop';
  static const String shopGoodsDetail = '/shop/goods-detail';
  static const String shopOrderList = '/shop/orders';
  static const String shopPayOrder = '/shop/pay-order';
  static const String shopPaySuccess = '/shop/pay-success';
  static const String shopAddress = '/shop/address';
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
      case AppRoutes.bindMobile:
        final cacheKey = settings.arguments is String
            ? settings.arguments! as String
            : '';
        // 显式声明 <bool>：登录页用 pushNamed<bool> 接收绑定结果
        // (pop(true))，泛型不匹配会在 pushNamed 内部 cast 时崩溃。
        return MaterialPageRoute<bool>(
          builder: (_) => BindMobilePage(cacheKey: cacheKey),
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
      case AppRoutes.petAdd:
        return MaterialPageRoute<bool>(
          builder: (_) => const PetAddGuidePage(),
          settings: settings,
        );
      case AppRoutes.petEdit:
        // arguments: PetInfo?（传入 = 编辑，不传 = 新增）
        return MaterialPageRoute<bool>(
          builder: (_) => PetEditPage(
            pet: settings.arguments is PetInfo
                ? settings.arguments as PetInfo
                : null,
          ),
          settings: settings,
        );
      case AppRoutes.petType:
        return MaterialPageRoute<String>(
          builder: (_) => const PetTypePage(),
          settings: settings,
        );
      case AppRoutes.petGender:
        return MaterialPageRoute<Map<String, String>>(
          builder: (_) => const PetGenderPage(),
          settings: settings,
        );
      case AppRoutes.petVariety:
        // arguments: {mark: cat|dog, initialVariety?: String}
        final args = settings.arguments is Map
            ? settings.arguments as Map
            : const <String, dynamic>{};
        return MaterialPageRoute<String>(
          builder: (_) => PetVarietyPage(
            mark: args['mark']?.toString() ?? 'cat',
            initialVariety: args['initialVariety']?.toString(),
          ),
          settings: settings,
        );
      case AppRoutes.petWeight:
        // arguments: {petType: cat|dog, initialWeight: double}
        final args = settings.arguments is Map
            ? settings.arguments as Map
            : const <String, dynamic>{};
        return MaterialPageRoute<String>(
          builder: (_) => PetWeightPage(
            petType: args['petType']?.toString() ?? 'cat',
            initialWeight: (args['initialWeight'] as num?)?.toDouble() ?? 4,
          ),
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
      case AppRoutes.feedback:
        return MaterialPageRoute<bool>(
          builder: (_) => const FeedbackPage(),
          settings: settings,
        );
      case AppRoutes.shop:
        return MaterialPageRoute(
          builder: (_) => const ShopPage(),
          settings: settings,
        );
      case AppRoutes.shopGoodsDetail:
        // arguments: MallProduct（列表预传，先展示再拉详情）
        final product = settings.arguments is MallProduct
            ? settings.arguments! as MallProduct
            : null;
        final productId =
            settings.arguments is int ? settings.arguments! as int : null;
        return MaterialPageRoute(
          builder: (_) => GoodsDetailPage(
            product: product,
            productId: productId ?? product?.id,
          ),
          settings: settings,
        );
      case AppRoutes.shopOrderList:
        return MaterialPageRoute(
          builder: (_) => const OrderListPage(),
          settings: settings,
        );
      case AppRoutes.shopPayOrder:
        // arguments: int productId
        return MaterialPageRoute(
          builder: (_) => PayOrderPage(
            productId: settings.arguments is int
                ? settings.arguments! as int
                : 0,
          ),
          settings: settings,
        );
      case AppRoutes.shopPaySuccess:
        // arguments: PaySuccessArgs（金额 + 订单号）
        final args = settings.arguments is PaySuccessArgs
            ? settings.arguments! as PaySuccessArgs
            : null;
        return MaterialPageRoute(
          builder: (_) => PaySuccessPage(args: args),
          settings: settings,
        );
      case AppRoutes.shopAddress:
        return MaterialPageRoute(
          builder: (_) => const AddressPage(),
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
