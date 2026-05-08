import Flutter
import UIKit
import BDASignalSDK

/// Flutter 到 iOS 的 BDASignalSDK 桥接层。
///
/// 说明：
/// - 所有 Flutter 方法名与原生能力映射集中在 `handle` 中统一维护。
/// - 部分配置会缓存到 UserDefaults，确保冷启动回调时也能及时生效。
/// - 直接依赖 BDASignalSDK，使用强类型 API 调用 BDASignalManager。
public class BdasignalsdkPlugin: NSObject, FlutterPlugin {
  private enum DefaultsKey {
    static let optionalDataJson = "bdasignalsdk_optional_data_json"
    static let delayUploadEnabled = "bdasignalsdk_delay_upload_enabled"
    static let idfaEnabled = "bdasignalsdk_idfa_enabled"
  }

  private var hasReportedLaunch = false
  private static weak var sharedInstance: BdasignalsdkPlugin?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "bdasignalsdk", binaryMessenger: registrar.messenger())
    let instance = BdasignalsdkPlugin()
    BdasignalsdkPlugin.sharedInstance = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.nativeLog("plugin_registered", extra: [:])
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Flutter API -> iOS SDK 的统一分发入口。
    nativeLog("handle_call", extra: ["method": call.method])
    switch call.method {
    case "initialize":
      let args = call.arguments as? [String: Any]
      let optionalData = args?["optionalData"] as? [String: Any]
      let delayUploadEnabled = args?["delayUploadEnabled"] as? Bool
      let idfaEnabled = args?["idfaEnabled"] as? Bool
      nativeLog("initialize_start", extra: [
        "hasOptionalData": optionalData != nil,
        "delayUploadEnabled": delayUploadEnabled as Any,
        "idfaEnabled": idfaEnabled as Any,
      ])

      if let optionalData {
        // 持久化可选参数，确保 Dart 尚未启动时冷启动上报也能使用。
        saveOptionalData(optionalData)
        let normalized = normalizeOptionalData(optionalData)
        BDASignalManager.register(withOptionalData: normalized)
        nativeLog("initialize_register_optional_data_done", extra: ["keys": normalized.keys.map { String(describing: $0) }])
      }

      if let delayUploadEnabled {
        UserDefaults.standard.set(delayUploadEnabled, forKey: DefaultsKey.delayUploadEnabled)
        if delayUploadEnabled {
          // 延时上报一般用于宿主等待隐私授权后再允许发送事件。
          BDASignalManager.enableDelayUpload()
          nativeLog("initialize_enable_delay_upload_done", extra: ["enabled": true])
        }
      }

      if let idfaEnabled {
        UserDefaults.standard.set(idfaEnabled, forKey: DefaultsKey.idfaEnabled)
        BDASignalManager.enableIdfa(idfaEnabled)
        nativeLog("initialize_enable_idfa_done", extra: ["enabled": idfaEnabled])
      }

      nativeLog("initialize_done", extra: [:])
      result(nil)
    case "setOptionalData":
      guard let args = call.arguments as? [String: Any],
            let optionalData = args["optionalData"] as? [String: Any] else {
        nativeLog("set_optional_data_bad_args", extra: [:])
        result(FlutterError(code: "bad_args", message: "optionalData required", details: nil))
        return
      }
      saveOptionalData(optionalData)
      let normalized = normalizeOptionalData(optionalData)
      BDASignalManager.register(withOptionalData: normalized)
      nativeLog("set_optional_data_done", extra: ["keys": normalized.keys.map { String(describing: $0) }])
      result(nil)
    case "enableIdfa":
      guard let args = call.arguments as? [String: Any],
            let enabled = args["enabled"] as? Bool else {
        nativeLog("enable_idfa_bad_args", extra: [:])
        result(FlutterError(code: "bad_args", message: "enabled required", details: nil))
        return
      }
      UserDefaults.standard.set(enabled, forKey: DefaultsKey.idfaEnabled)
      BDASignalManager.enableIdfa(enabled)
      nativeLog("enable_idfa_done", extra: ["enabled": enabled])
      result(nil)
    case "enableDelayUpload":
      UserDefaults.standard.set(true, forKey: DefaultsKey.delayUploadEnabled)
      BDASignalManager.enableDelayUpload()
      nativeLog("enable_delay_upload_done", extra: ["enabled": true])
      result(nil)
    case "startSendingEvents":
      BDASignalManager.startSendingEvents()
      nativeLog("start_sending_events_done", extra: [:])
      result(nil)
    case "analyzeDeeplinkClickid":
      guard let args = call.arguments as? [String: Any],
            let openUrl = args["openUrl"] as? String else {
        nativeLog("analyze_deeplink_bad_args", extra: [:])
        result(FlutterError(code: "bad_args", message: "openUrl required", details: nil))
        return
      }
      BDASignalManager.anylyseDeeplinkClickid(withOpenUrl: openUrl)
      nativeLog("analyze_deeplink_done", extra: ["openUrl": openUrl])
      result(nil)
    case "trackEvent":
      guard let args = call.arguments as? [String: Any],
            let name = args["name"] as? String else {
        nativeLog("track_event_bad_args", extra: [:])
        result(FlutterError(code: "bad_args", message: "name required", details: nil))
        return
      }
      let params = args["params"] as? [String: Any] ?? [:]
      BDASignalManager.trackEssentialEvent(withName: name, params: params)
      nativeLog("track_event_done", extra: ["name": name, "paramCount": params.count])
      result(nil)
    case "trackRegisterEvent":
      guard let args = call.arguments as? [String: Any],
            let registerMethod = args["registerMethod"] as? String,
            let isSuccess = args["isSuccess"] as? Bool else {
        nativeLog("track_register_bad_args", extra: [:])
        result(FlutterError(code: "bad_args", message: "registerMethod/isSuccess required", details: nil))
        return
      }
      BDASignalManager.trackEssentialEvent(
        withName: "register",
        params: ["register_method": registerMethod, "is_success": isSuccess]
      )
      nativeLog("track_register_done", extra: ["registerMethod": registerMethod, "isSuccess": isSuccess])
      result(nil)
    case "trackPurchaseEvent":
      guard let args = call.arguments as? [String: Any],
            let isSuccess = args["isSuccess"] as? Bool else {
        nativeLog("track_purchase_bad_args", extra: [:])
        result(FlutterError(code: "bad_args", message: "isSuccess required", details: nil))
        return
      }
      let params: [String: Any] = [
        "content_type": args["contentType"] as? String ?? "",
        "content_name": args["contentName"] as? String ?? "",
        "content_id": args["contentId"] as? String ?? "",
        "content_number": args["contentNumber"] as? Int ?? 1,
        "payment_channel": args["paymentChannel"] as? String ?? "",
        "currency": args["currency"] as? String ?? "",
        "is_success": isSuccess,
        "currency_amount": args["currencyAmount"] as? NSNumber ?? 0,
      ]
      BDASignalManager.trackEssentialEvent(withName: "purchase", params: params)
      nativeLog("track_purchase_done", extra: ["isSuccess": isSuccess, "currency": params["currency"] as Any])
      result(nil)
    case "trackLoginEvent":
      guard let args = call.arguments as? [String: Any],
            let method = args["method"] as? String,
            let isSuccess = args["isSuccess"] as? Bool else {
        nativeLog("track_login_bad_args", extra: [:])
        result(FlutterError(code: "bad_args", message: "method/isSuccess required", details: nil))
        return
      }
      BDASignalManager.trackEssentialEvent(
        withName: "login",
        params: ["method": method, "is_success": isSuccess]
      )
      nativeLog("track_login_done", extra: ["method": method, "isSuccess": isSuccess])
      result(nil)
    case "trackGameAddictionEvent":
      let args = call.arguments as? [String: Any]
      let params = args?["params"] as? [String: Any] ?? [:]
      BDASignalManager.trackEssentialEvent(withName: "game_addiction", params: params)
      nativeLog("track_game_addiction_done", extra: ["paramCount": params.count])
      result(nil)
    case "sendLaunchEvent":
      let args = call.arguments as? [String: Any]
      let launchOptionsRaw = args?["launchOptions"] as? [String: Any]
      let launchOptions = launchOptionsRaw?.reduce(into: [AnyHashable: Any]()) { partialResult, pair in
        partialResult[pair.key] = pair.value
      }
      // sendLaunchEvent 在 iOS 仅作为兜底：
      // 只有当启动回调未触发时，才补发启动事件，避免重复上报。
      _ = reportLaunchIfNeeded(
        launchOptions: launchOptions
      )
      nativeLog("send_launch_event_done", extra: ["hasLaunchOptions": launchOptions != nil])
      result(nil)
    case "enablePurchaseEvent":
      BDASignalManager.enablePurchaseEvent()
      nativeLog("enable_purchase_event_done", extra: [:])
      result(nil)
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      nativeLog("method_not_implemented", extra: ["method": call.method])
      result(FlutterMethodNotImplemented)
    }
  }

  /// 宿主生命周期可显式调用：对应 didFinishLaunchingWithOptions。
  public static func didFinishLaunchingWithOptions(
    launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) {
    let anyHashableOptions = launchOptions?.reduce(into: [AnyHashable: Any]()) { partialResult, pair in
      partialResult[pair.key] = pair.value
    }
    if let instance = sharedInstance {
      instance.nativeLog("did_finish_launching_with_options", extra: ["hasLaunchOptions": launchOptions != nil])
      _ = instance.reportLaunchIfNeeded(launchOptions: anyHashableOptions)
    } else {
      NSLog("%@", "[flutter_bdasignalsdk][iOS] did_finish_launching_with_options | sharedInstance=nil")
    }
  }

  /// 宿主生命周期可显式调用：对应 openURL 场景的 clickid 分析。
  public static func anylyseDeeplinkClickidWithOpenUrl(_ openUrl: String) {
    BDASignalManager.anylyseDeeplinkClickid(withOpenUrl: openUrl)
    if let instance = sharedInstance {
      instance.nativeLog("anylyse_deeplink_clickid_with_open_url", extra: ["openUrl": openUrl])
    } else {
      NSLog("%@", "[flutter_bdasignalsdk][iOS] anylyse_deeplink_clickid_with_open_url | sharedInstance=nil")
    }
  }

  @discardableResult
  private func reportLaunchIfNeeded(
    launchOptions: [AnyHashable: Any]?
  ) -> Bool {
    if hasReportedLaunch {
      nativeLog("report_launch_skipped_already_reported", extra: [
        "hasLaunchOptions": launchOptions != nil,
      ])
      return false
    }
    // 防止多个生命周期路径重复触发启动上报。
    hasReportedLaunch = true
    nativeLog("report_launch_start", extra: [
      "hasLaunchOptions": launchOptions != nil,
    ])
    applyCachedConfiguration()
    BDASignalManager.didFinishLaunching(options: launchOptions, connect: nil)
    nativeLog("report_launch_done", extra: [:])
    return true
  }

  private func applyCachedConfiguration() {
    // 默认不启用延时上报；如业务需要，显式调用 enableDelayUpload。
    let delayObj = UserDefaults.standard.object(forKey: DefaultsKey.delayUploadEnabled)
    let delayEnabled = (delayObj as? Bool) ?? false
    if delayObj == nil {
      UserDefaults.standard.set(false, forKey: DefaultsKey.delayUploadEnabled)
    }
    if delayEnabled {
      BDASignalManager.enableDelayUpload()
      nativeLog("apply_cached_delay_upload_done", extra: ["enabled": true])
    }

    if UserDefaults.standard.bool(forKey: DefaultsKey.idfaEnabled) {
      // 仅当宿主已完成 ATT 授权流程时，此开关才会真正生效。
      BDASignalManager.enableIdfa(true)
      nativeLog("apply_cached_idfa_done", extra: ["enabled": true])
    }

    if let optionalData = loadOptionalData() {
      let normalized = normalizeOptionalData(optionalData)
      BDASignalManager.register(withOptionalData: normalized)
      nativeLog("apply_cached_optional_data_done", extra: ["keys": normalized.keys.map { String(describing: $0) }])
    }
  }

  private func saveOptionalData(_ data: [String: Any]) {
    // 以 JSON 字符串持久化，便于跨重启恢复与向后兼容。
    if let json = try? JSONSerialization.data(withJSONObject: data, options: []),
       let jsonStr = String(data: json, encoding: .utf8) {
      UserDefaults.standard.set(jsonStr, forKey: DefaultsKey.optionalDataJson)
      nativeLog("save_optional_data_done", extra: ["keyCount": data.count])
    } else {
      nativeLog("save_optional_data_failed", extra: ["reason": "json_encode_failed"])
    }
  }

  private func loadOptionalData() -> [String: Any]? {
    guard let jsonStr = UserDefaults.standard.string(forKey: DefaultsKey.optionalDataJson),
          let data = jsonStr.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data, options: []),
          let dict = obj as? [String: Any] else {
      nativeLog("load_optional_data_empty_or_invalid", extra: [:])
      return nil
    }
    nativeLog("load_optional_data_done", extra: ["keyCount": dict.count])
    return dict
  }

  private func normalizeOptionalData(_ data: [String: Any]) -> [AnyHashable: Any] {
    var normalized: [AnyHashable: Any] = [:]
    for (key, value) in data {
      switch key {
      case "user_unique_id", "kBDADSignalSDKUserUniqueId":
        normalized[kBDADSignalSDKUserUniqueId] = value
      default:
        normalized[key] = value
      }
    }
    return normalized
  }

  private func nativeLog(_ event: String, extra: [String: Any]) {
    let message = "[flutter_bdasignalsdk][iOS] \(event) | \(extra)"
    // NSLog 在 iOS 控制台中更稳定，尤其是早期启动阶段日志。
    NSLog("%@", message)
  }

}
