import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bdasignalsdk_platform_interface.dart';

/// An implementation of [BdasignalsdkPlatform] that uses method channels.
class MethodChannelBdasignalsdk extends BdasignalsdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('bdasignalsdk');
  final StreamController<Map<String, dynamic>> _lifecycleController = StreamController<Map<String, dynamic>>.broadcast();

  MethodChannelBdasignalsdk() {
    methodChannel.setMethodCallHandler(_handleNativeCallback);
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'androidLifecycleCallback') {
      final args = call.arguments;
      if (args is Map) {
        final event = Map<String, dynamic>.from(args);
        event['platform'] ??= 'android';
        _lifecycleController.add(event);
      }
    } else if (call.method == 'iosLifecycleCallback') {
      final args = call.arguments;
      if (args is Map) {
        final event = Map<String, dynamic>.from(args);
        event['platform'] ??= 'ios';
        _lifecycleController.add(event);
      }
    }
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> initialize({
    Map<String, dynamic>? optionalData,
    bool delayUploadEnabled = false,
    bool idfaEnabled = false,
    bool autoSendLaunchEvent = true,
    bool enableLog = false,
    bool playSessionEnable = true,
    bool enableOAID = true,
    bool enableLifecycleCallback = false,
  }) async {
    await methodChannel.invokeMethod<void>('initialize', {
      'optionalData': optionalData,
      'delayUploadEnabled': delayUploadEnabled,
      'idfaEnabled': idfaEnabled,
      'autoSendLaunchEvent': autoSendLaunchEvent,
      'enableLog': enableLog,
      'playSessionEnable': playSessionEnable,
      'enableOAID': enableOAID,
      'enableLifecycleCallback': enableLifecycleCallback,
    });
  }

  @override
  Future<void> setOptionalData(Map<String, dynamic> optionalData) async {
    await methodChannel.invokeMethod<void>('setOptionalData', {'optionalData': optionalData});
  }

  @override
  Future<void> enableIdfa(bool enabled) async {
    await methodChannel.invokeMethod<void>('enableIdfa', {'enabled': enabled});
  }

  @override
  Future<void> enableDelayUpload() async {
    await methodChannel.invokeMethod<void>('enableDelayUpload');
  }

  @override
  Future<void> startSendingEvents() async {
    await methodChannel.invokeMethod<void>('startSendingEvents');
  }

  @override
  Future<void> analyzeDeeplinkClickid(String openUrl) async {
    await methodChannel.invokeMethod<void>('analyzeDeeplinkClickid', {'openUrl': openUrl});
  }

  @override
  Future<void> trackEvent(String name, {Map<String, dynamic>? params}) async {
    await methodChannel.invokeMethod<void>('trackEvent', {'name': name, 'params': params ?? <String, dynamic>{}});
  }

  @override
  Future<void> trackRegisterEvent({required String registerMethod, required bool isSuccess}) async {
    await methodChannel.invokeMethod<void>('trackRegisterEvent', {'registerMethod': registerMethod, 'isSuccess': isSuccess});
  }

  @override
  Future<void> trackPurchaseEvent({
    String? contentType,
    String? contentName,
    String? contentId,
    int? contentNumber,
    String? paymentChannel,
    String? currency,
    required bool isSuccess,
    num? currencyAmount,
  }) async {
    await methodChannel.invokeMethod<void>('trackPurchaseEvent', {
      'contentType': contentType,
      'contentName': contentName,
      'contentId': contentId,
      'contentNumber': contentNumber,
      'paymentChannel': paymentChannel,
      'currency': currency,
      'isSuccess': isSuccess,
      'currencyAmount': currencyAmount,
    });
  }

  @override
  Future<void> trackLoginEvent({required String method, required bool isSuccess}) async {
    await methodChannel.invokeMethod<void>('trackLoginEvent', {'method': method, 'isSuccess': isSuccess});
  }

  @override
  Future<void> trackGameAddictionEvent({Map<String, dynamic>? params}) async {
    await methodChannel.invokeMethod<void>('trackGameAddictionEvent', {'params': params ?? <String, dynamic>{}});
  }

  @override
  Future<void> enablePurchaseEvent() async {
    await methodChannel.invokeMethod<void>('enablePurchaseEvent');
  }

  @override
  Future<void> sendLaunchEvent({Map<String, dynamic>? launchOptions, Map<String, dynamic>? connectOptions}) async {
    await methodChannel.invokeMethod<void>('sendLaunchEvent', {'launchOptions': launchOptions, 'connectOptions': connectOptions});
  }

  @override
  Stream<Map<String, dynamic>> get lifecycleCallbackStream {
    return _lifecycleController.stream;
  }
}
