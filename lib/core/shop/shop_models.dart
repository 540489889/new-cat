/// 商城模块数据模型。
///
/// 注意：后端接口由「设备商城」改造而来，存在历史遗留命名——
/// 订单创建参数为 `deviceId`（实指商品 id），订单返回字段前缀为
/// `deviceXxx`（实指商品信息）。保持与后端契约一致，勿改名。
///
/// 另：旧接口数字字段可能被序列化为字符串（如 total: "2"），
/// 统一用 [parseNum] 容错解析，禁止直接 `as num?`。
library;

/// 容错解析数字：兼容 num 与字符串（"2"、"2.5"）两种形态。
num? parseNum(dynamic v) => switch (v) {
      num n => n,
      String s => num.tryParse(s.trim()),
      _ => null,
    };

/// 商品（接口：GET /app/mall/list、/app/mall/detail/{id}）。
class MallProduct {
  final int id;
  final String title;
  final double price;
  final double? orgPrice; // 划线原价
  final String? subtitle; // 促销标签文案（红标）
  final String? imglogo; // 主图 URL
  final String? imgs; // 详情图
  final String? model; // 型号
  final String? type;
  final int stock; // 库存
  final int sales; // 销量

  const MallProduct({
    required this.id,
    required this.title,
    required this.price,
    this.orgPrice,
    this.subtitle,
    this.imglogo,
    this.imgs,
    this.model,
    this.type,
    this.stock = 0,
    this.sales = 0,
  });

  factory MallProduct.fromJson(Map<String, dynamic> json) => MallProduct(
        id: parseNum(json['id'])?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        price: parseNum(json['price'])?.toDouble() ?? 0,
        orgPrice: parseNum(json['orgPrice'])?.toDouble(),
        subtitle: json['subtitle']?.toString(),
        imglogo: json['imglogo']?.toString(),
        imgs: json['imgs']?.toString(),
        model: json['model']?.toString(),
        type: json['type']?.toString(),
        stock: parseNum(json['stock'])?.toInt() ?? 0,
        sales: parseNum(json['sales'])?.toInt() ?? 0,
      );
}

/// 商城 Banner（接口：GET /app/ads/list/mall）。
class ShopBanner {
  final String image; // imgurl
  final String linkType; // 'h5' / 'page'（由 link 前缀判断）
  final int? targetId; // page 类型时从 link 解析 productDetail?id=N
  final String url; // 原始 link

  const ShopBanner({
    required this.image,
    required this.linkType,
    this.targetId,
    required this.url,
  });

  factory ShopBanner.fromJson(Map<String, dynamic> json) {
    final link = json['link']?.toString() ?? '';
    // link 以 http 开头为 H5 外链，否则为应用内页面（如 productDetail?id=1）
    final isH5 = link.startsWith('http');
    int? targetId;
    if (!isH5) {
      final match = RegExp(r'id=(\d+)').firstMatch(link);
      targetId = match != null ? int.tryParse(match.group(1)!) : null;
    }
    return ShopBanner(
      image: json['imgurl']?.toString() ?? '',
      linkType: isH5 ? 'h5' : 'page',
      targetId: targetId,
      url: link,
    );
  }
}

/// 订单（接口：GET /app/order/list、POST /app/order/create）。
///
/// 状态：-1 已取消 / 0 待付款 / 1 已付款 / 2 已发货 / 3 已完成 / 4 售后退货。
class ShopOrder {
  final int id;
  final String sn; // 订单号
  final String? title; // 商品标题（json: deviceTitle）
  final double price; // 单价
  final double totalPrice; // 总价
  final int quantity; // 数量（json: num）
  final int? status;
  final String? createTime;
  final String? image; // 商品图（json: deviceImg）
  final String? model; // 型号（json: deviceModel）
  final String? subtitle; // 促销标签（json: deviceSubtitle）
  final int productId; // 商品 id（json: deviceId，再次购买/去支付跳详情用）

  const ShopOrder({
    required this.id,
    required this.sn,
    this.title,
    required this.price,
    required this.totalPrice,
    this.quantity = 1,
    this.status,
    this.createTime,
    this.image,
    this.model,
    this.subtitle,
    this.productId = 0,
  });

  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
        id: parseNum(json['id'])?.toInt() ?? 0,
        sn: json['sn']?.toString() ?? '',
        title: json['deviceTitle']?.toString(),
        price: parseNum(json['price'])?.toDouble() ?? 0,
        totalPrice: parseNum(json['totalPrice'])?.toDouble() ?? 0,
        quantity: parseNum(json['num'])?.toInt() ?? 1,
        status: parseNum(json['status'])?.toInt(),
        createTime: json['createTime']?.toString(),
        image: json['deviceImg']?.toString(),
        model: json['deviceModel']?.toString(),
        subtitle: json['deviceSubtitle']?.toString(),
        productId: (json['deviceId'] as num?)?.toInt() ?? 0,
      );

  /// 状态文案（列表 Tab 与操作按钮共用）。
  String get statusText => switch (status) {
        -1 => '已取消',
        0 => '待付款',
        1 => '已付款',
        2 => '已发货',
        3 => '已完成',
        4 => '售后/退货',
        _ => '未知',
      };

  /// 状态对应主题色。
  int get statusColor => switch (status) {
        0 => 0xFFFF4D26, // 待付款：警示橙红
        1 => 0xFF07C160, // 已付款：绿
        2 => 0xFF3D7FFF, // 已发货：蓝
        3 => 0xFF07C160,
        -1 => 0xFF999999,
        _ => 0xFF999999,
      };
}

/// 收货地址（接口：GET /app/address/list、POST /app/address/add|update）。
class ShopAddress {
  final int id;
  final String region; // '省 市 区' 空格分隔
  final String detail; // 详细地址
  final String name; // 收件人
  final String phone;
  final bool isDefault;

  const ShopAddress({
    required this.id,
    required this.region,
    required this.detail,
    required this.name,
    required this.phone,
    this.isDefault = false,
  });

  factory ShopAddress.fromJson(Map<String, dynamic> json) => ShopAddress(
        id: parseNum(json['id'])?.toInt() ?? 0,
        region: [
          json['province'],
          json['city'],
          json['district'],
        ].where((e) => e != null && e.toString().isNotEmpty).join(' '),
        detail: json['address']?.toString() ?? '',
        name: json['uname']?.toString() ?? '',
        phone: json['mobile']?.toString() ?? '',
        isDefault: json['isDefault']?.toString() == '1',
      );

  Map<String, dynamic> toAddJson() {
    final parts = region.split(RegExp(r'\s+'))..removeWhere((e) => e.isEmpty);
    return {
      'province': parts.isNotEmpty ? parts[0] : region,
      'city': parts.length > 1 ? parts[1] : '',
      'district': parts.length > 2 ? parts[2] : '',
      'address': detail,
      'uname': name,
      'mobile': phone,
      'isDefault': isDefault ? 1 : 0,
    };
  }
}

/// 订单创建响应（POST /app/order/create 的 data）。
class CreateOrderResult {
  final int id;
  final String sn;
  final double totalPrice;
  final double price;
  final int? expireTime; // 支付有效期（Unix 秒），待付款倒计时用

  const CreateOrderResult({
    required this.id,
    required this.sn,
    required this.totalPrice,
    required this.price,
    this.expireTime,
  });

  factory CreateOrderResult.fromJson(Map<String, dynamic> json) =>
      CreateOrderResult(
        id: parseNum(json['id'])?.toInt() ?? 0,
        sn: json['sn']?.toString() ?? '',
        totalPrice: parseNum(json['totalPrice'])?.toDouble() ?? 0,
        price: parseNum(json['price'])?.toDouble() ?? 0,
        expireTime: parseNum(json['expireTime'])?.toInt(),
      );
}
