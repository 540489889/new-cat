import '../http/api_client.dart';

/// 宠物资料接口（对齐参考项目 f-cat 的 PetApiService）。
///
/// 请求均为 JSON body：
/// - 添加：POST /app/pet/add
/// - 编辑：POST /app/pet/update
/// 图片先经 /app/user/file/upload 上传拿到 URL，再随表单提交。
class PetApiService {
  PetApiService._();

  /// 添加宠物。type=cat/dog，sex=male/female，sterilization=y/n，
  /// birthday 为 ISO 字符串（YYYY-MM-DDT00:00:00.000Z）。
  static Future<ApiResponse> addPet({
    required String nickname,
    required String type,
    required String variety,
    required String sex,
    required String sterilization,
    required String birthday,
    required double weight,
    String? headimg,
    String? imgFace,
    String? imgBody,
    String? imgWhole,
  }) {
    return ApiClient.instance.post('/app/pet/add', body: {
      'nickname': nickname,
      'type': type,
      'variety': variety,
      'sex': sex,
      'sterilization': sterilization,
      'birthday': birthday,
      'weight': weight,
      'headimg': headimg ?? '',
      'imgFace': imgFace ?? '',
      'imgBody': imgBody ?? '',
      'imgWhole': imgWhole ?? '',
    });
  }

  /// 编辑宠物：字段同添加，额外带 id。
  static Future<ApiResponse> updatePet({
    required int id,
    required String nickname,
    required String type,
    required String variety,
    required String sex,
    required String sterilization,
    required String birthday,
    required double weight,
    String? headimg,
    String? imgFace,
    String? imgBody,
    String? imgWhole,
  }) {
    return ApiClient.instance.post('/app/pet/update', body: {
      'id': id,
      'nickname': nickname,
      'type': type,
      'variety': variety,
      'sex': sex,
      'sterilization': sterilization,
      'birthday': birthday,
      'weight': weight,
      'headimg': headimg ?? '',
      'imgFace': imgFace ?? '',
      'imgBody': imgBody ?? '',
      'imgWhole': imgWhole ?? '',
    });
  }
}
