import 'dart:async';

import 'bdasignalsdk_platform_interface.dart';

class Bdasignalsdk {
  Bdasignalsdk._();

  static Future<String?> getPlatformVersion() {
    return BdasignalsdkPlatform.instance.getPlatformVersion();
  }

  static Future<void> initialize({
    Map<String, dynamic>? optionalData,
    // iOS 延时上报默认关闭。若开启，必须配合 startSendingEvents() 使用。
    bool delayUploadEnabled = false,
    bool idfaEnabled = false,
    bool autoSendLaunchEvent = true,
    bool enableLog = false,
    bool playSessionEnable = true,
    bool enableOAID = true,
    // 仅 OHOS 生效：自定义 OAID 提供值，配置后 SDK 将使用该值。
    String? customOaid,
    // 仅 Android 生效：透传 BDConvertLifecycleCallback 到 Flutter。
    bool enableLifecycleCallback = false,
  }) {
    return BdasignalsdkPlatform.instance.initialize(
      optionalData: optionalData,
      delayUploadEnabled: delayUploadEnabled,
      idfaEnabled: idfaEnabled,
      autoSendLaunchEvent: autoSendLaunchEvent,
      enableLog: enableLog,
      playSessionEnable: playSessionEnable,
      enableOAID: enableOAID,
      customOaid: customOaid,
      enableLifecycleCallback: enableLifecycleCallback,
    );
  }

  static Future<void> setOptionalData(Map<String, dynamic> optionalData) {
    // 仅 iOS 生效：Android 当前为兼容空实现。
    return BdasignalsdkPlatform.instance.setOptionalData(optionalData);
  }

  static Future<void> enableIdfa(bool enabled) {
    // 仅 iOS 生效：需要宿主先完成 ATT 授权流程。
    return BdasignalsdkPlatform.instance.enableIdfa(enabled);
  }

  static Future<void> enableDelayUpload() {
    // 仅 iOS 生效：开启后需调用 startSendingEvents() 才会开始发送。
    return BdasignalsdkPlatform.instance.enableDelayUpload();
  }

  static Future<void> startSendingEvents() {
    // 仅 iOS 生效：用于延时上报模式下显式放开事件发送。
    return BdasignalsdkPlatform.instance.startSendingEvents();
  }

  static Future<void> analyzeDeeplinkClickid(String openUrl) {
    // iOS 生效；Android 当前为兼容空实现。
    return BdasignalsdkPlatform.instance.analyzeDeeplinkClickid(openUrl);
  }

  static Future<void> trackEvent(String name, {Map<String, dynamic>? params}) {
    return BdasignalsdkPlatform.instance.trackEvent(name, params: params);
  }

  static Future<void> trackRegisterEvent({required String registerMethod, required bool isSuccess}) {
    return BdasignalsdkPlatform.instance.trackRegisterEvent(registerMethod: registerMethod, isSuccess: isSuccess);
  }

  static Future<void> trackPurchaseEvent({
    String? contentType,
    String? contentName,
    String? contentId,
    int? contentNumber,
    String? paymentChannel,
    String? currency,
    required bool isSuccess,
    num? currencyAmount,
  }) {
    return BdasignalsdkPlatform.instance.trackPurchaseEvent(
      contentType: contentType,
      contentName: contentName,
      contentId: contentId,
      contentNumber: contentNumber,
      paymentChannel: paymentChannel,
      currency: currency,
      isSuccess: isSuccess,
      currencyAmount: currencyAmount,
    );
  }

  static Future<void> trackLoginEvent({required String method, required bool isSuccess}) {
    return BdasignalsdkPlatform.instance.trackLoginEvent(method: method, isSuccess: isSuccess);
  }

  static Future<void> trackGameAddictionEvent({Map<String, dynamic>? params}) {
    return BdasignalsdkPlatform.instance.trackGameAddictionEvent(params: params);
  }

  static Future<void> enablePurchaseEvent() {
    // 仅 iOS 生效：开启 IAP 自动监听事件上报。
    return BdasignalsdkPlatform.instance.enablePurchaseEvent();
  }

  static Future<void> sendLaunchEvent({Map<String, dynamic>? launchOptions, Map<String, dynamic>? connectOptions}) {
    // iOS 侧仅在未收到冷启动回调时兜底触发，避免重复上报。
    return BdasignalsdkPlatform.instance.sendLaunchEvent(launchOptions: launchOptions, connectOptions: connectOptions);
  }

  /// 跨平台统一生命周期回调流。
  /// 回调里会带 `platform` 字段：`android` / `ios`。
  static Stream<Map<String, dynamic>> get lifecycleCallbackStream {
    return BdasignalsdkPlatform.instance.lifecycleCallbackStream;
  }
}
