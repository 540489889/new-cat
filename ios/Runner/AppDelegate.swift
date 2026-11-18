import Flutter
import UIKit
import wechat_bridge

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// 微信授权回调走 Universal Link（https://app.jolipaw.pet/jolipaw/）。
  /// 先让 FlutterAppDelegate 转发给已注册的插件（wechat_bridge 通过
  /// addApplicationDelegate 注册）；若该 iOS/Flutter 版本未自动转发，
  /// 再手动调用插件公开的 handleUniversalLink 兜底。
  /// 两步互斥：handled 为 true 时不重复调用，避免 onAuthResp 触发两次。
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    let handled = super.application(
      application, continue: userActivity, restorationHandler: restorationHandler)
    if handled { return true }
    return WechatBridgePlugin.handleUniversalLink(userActivity)
  }
}
