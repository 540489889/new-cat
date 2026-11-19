import 'package:tobias/tobias.dart';

import '../http/api_client.dart';
import 'shop_models.dart';

/// 商城模块 API（商品 / Banner / 订单 / 地址）。
///
/// 契约与参考项目 f-cat 一致（后端同一套接口）：
/// - 列表统一 `{records, total, pageNum, pageSize}` 分页结构
/// - 订单创建参数 `deviceId` 即商品 id（历史遗留命名，保持契约）
/// - 支付：POST /app/order/pay?orderId=&payType=，data 即支付串
///   （支付宝为订单 info 串，交 Tobias 拉起；微信后端未实装参数化支付）
class ShopApiService {
  ShopApiService._();

  static final ApiClient _api = ApiClient.instance;

  // ---------------- 商品 ----------------

  /// 商品分页列表。
  static Future<ApiResponse> products({int pageNum = 1, int pageSize = 10}) =>
      _api.get('/app/mall/list', queryParams: {
        'pageNum': pageNum,
        'pageSize': pageSize,
      });

  /// 商品详情。
  static Future<ApiResponse> productDetail(int id) =>
      _api.get('/app/mall/detail/$id');

  // ---------------- Banner ----------------

  /// 商城轮播图（position 固定 mall）。
  static Future<ApiResponse> banners() => _api.get('/app/ads/list/mall');

  // ---------------- 订单 ----------------

  /// 创建订单。返回 CreateOrderResult（含支付倒计时 expireTime）。
  static Future<ApiResponse> createOrder({
    required int productId,
    required int quantity,
    required int addressId,
    String? remark,
  }) =>
      _api.post('/app/order/create', body: {
        'deviceId': productId, // 历史遗留：字段名 deviceId 即商品 id
        'num': quantity,
        'addressId': addressId,
        'remark': ?remark,
      });

  /// 发起支付，data 即支付串。
  /// [payType]：'wechat' / 'alipay'。
  static Future<ApiResponse> payOrder({
    required int orderId,
    required String payType,
  }) =>
      _api.post('/app/order/pay?orderId=$orderId&payType=$payType');

  /// 取消订单。
  static Future<ApiResponse> cancelOrder(int orderId) =>
      _api.post('/app/order/cancel/$orderId');

  /// 删除订单。
  static Future<ApiResponse> deleteOrder(int orderId) =>
      _api.post('/app/order/delete/$orderId');

  /// 订单分页列表。[status]：null 全部 / 0 待付款 / 1 已付款 / 2 已发货 / 3 已完成。
  static Future<ApiResponse> orders({
    int pageNum = 1,
    int pageSize = 10,
    int? status,
  }) =>
      _api.get('/app/order/list', queryParams: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        'status': ?status,
      });

  // ---------------- 地址 ----------------

  static Future<ApiResponse> addresses() => _api.get('/app/address/list');

  static Future<ApiResponse> addAddress(ShopAddress addr) =>
      _api.post('/app/address/add', body: addr.toAddJson());

  static Future<ApiResponse> updateAddress(ShopAddress addr) =>
      _api.post('/app/address/update', body: {...addr.toAddJson(), 'id': addr.id});

  static Future<ApiResponse> deleteAddress(int id) =>
      _api.post('/app/address/delete/$id');
}

/// 支付宝拉起封装（tobias 本地补丁）。
///
/// 返回 resultStatus：9000 成功 / 8000 处理中 / 6001 取消 / 4000 失败等。
Future<String> invokeAlipay(String orderInfo) async {
  final result = await Tobias().pay(orderInfo);
  return result['resultStatus']?.toString() ?? '4000';
}
