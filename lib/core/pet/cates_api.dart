import '../http/api_client.dart';

/// 宠物分类（品种）接口：GET /app/cates/data/{cat|dog}。
/// 返回 {字母: [品种...]} 的分组结构。
class CatesApiService {
  CatesApiService._();

  static Future<ApiResponse> getCatesTree({required String mark}) =>
      ApiClient.instance.get('/app/cates/data/$mark');
}

/// 品种项（接口返回的每项：id / title / icon）。
class BreedItem {
  final int id;
  final String title;
  final String icon;

  BreedItem({required this.id, required this.title, required this.icon});

  factory BreedItem.fromJson(Map<String, dynamic> json) => BreedItem(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
      );
}
