/// API 统一配置
///
/// 所有接口域名、超时等集中在此，切换环境只改这里。
/// 地址与 f-cat 项目保持一致。
class ApiConfig {
  ApiConfig._();

  /// 接口基础地址
  /// 开发环境：http://192.168.1.135:8080
  /// 生产环境：https://app.jolipaw.pet
  static const String baseUrl = 'https://app.jolipaw.pet';

  /// 请求超时（秒）
  static const int connectTimeout = 15;
  static const int receiveTimeout = 30;

  /// 静态资源 H5 页面地址
  static const String staticBase = 'http://static.jolipaw.pet';

  /// 隐私政策
  static const String privacyUrl = '$staticBase/privacy_agreement.html';

  /// 用户协议
  static const String userAgreementUrl = '$staticBase/user_agreement.html';
}
