import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'bdasignalsdk_method_channel.dart';

abstract class BdasignalsdkPlatform extends PlatformInterface {
  /// Constructs a BdasignalsdkPlatform.
  BdasignalsdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static BdasignalsdkPlatform _instance = MethodChannelBdasignalsdk();

  /// The default instance of [BdasignalsdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelBdasignalsdk].
  static BdasignalsdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BdasignalsdkPlatform] when
  /// they register themselves.
  static set instance(BdasignalsdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> initialize({
    Map<String, dynamic>? optionalData,
    bool delayUploadEnabled = false,
    bool idfaEnabled = false,
    bool autoSendLaunchEvent = true,
    bool enableLog = false,
    bool playSessionEnable = true,
    bool enableOAID = true,
    String? customOaid,
    bool enableLifecycleCallback = false,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> setOptionalData(Map<String, dynamic> optionalData) {
    throw UnimplementedError('setOptionalData() has not been implemented.');
  }

  Future<void> enableIdfa(bool enabled) {
    throw UnimplementedError('enableIdfa() has not been implemented.');
  }

  Future<void> enableDelayUpload() {
    throw UnimplementedError('enableDelayUpload() has not been implemented.');
  }

  Future<void> startSendingEvents() {
    throw UnimplementedError('startSendingEvents() has not been implemented.');
  }

  Future<void> analyzeDeeplinkClickid(String openUrl) {
    throw UnimplementedError('analyzeDeeplinkClickid() has not been implemented.');
  }

  Future<void> trackEvent(String name, {Map<String, dynamic>? params}) {
    throw UnimplementedError('trackEvent() has not been implemented.');
  }

  Future<void> trackRegisterEvent({required String registerMethod, required bool isSuccess}) {
    throw UnimplementedError('trackRegisterEvent() has not been implemented.');
  }

  Future<void> trackPurchaseEvent({
    String? contentType,
    String? contentName,
    String? contentId,
    int? contentNumber,
    String? paymentChannel,
    String? currency,
    required bool isSuccess,
    num? currencyAmount,
  }) {
    throw UnimplementedError('trackPurchaseEvent() has not been implemented.');
  }

  Future<void> trackLoginEvent({required String method, required bool isSuccess}) {
    throw UnimplementedError('trackLoginEvent() has not been implemented.');
  }

  Future<void> trackGameAddictionEvent({Map<String, dynamic>? params}) {
    throw UnimplementedError('trackGameAddictionEvent() has not been implemented.');
  }

  Future<void> enablePurchaseEvent() {
    throw UnimplementedError('enablePurchaseEvent() has not been implemented.');
  }

  Future<void> sendLaunchEvent({Map<String, dynamic>? launchOptions, Map<String, dynamic>? connectOptions}) {
    throw UnimplementedError('sendLaunchEvent() has not been implemented.');
  }

  Stream<Map<String, dynamic>> get lifecycleCallbackStream {
    return const Stream<Map<String, dynamic>>.empty();
  }
}
