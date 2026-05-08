# flutter_bdasignalsdk

`flutter_bdasignalsdk` 是一个 Flutter 插件，用于桥接巨量引擎转化能力：
- iOS：`BDASignalSDK`
- Android：`AppConvert`

插件提供统一的 Flutter API，用于初始化、启动归因、Deeplink 处理、关键转化事件上报与自定义事件上报。

## 1. 安装

在业务工程 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter_bdasignalsdk:
    path: vendor/flutter_bdasignalsdk
```

执行：

```bash
flutter pub get
```

## 2. 原生依赖说明

### iOS

插件 `podspec` 已内置：

```ruby
s.dependency 'BDASignalSDK'
```

在 iOS 目录执行：

```bash
pod install
```

如果当前 CocoaPods 源拉不到 `BDASignalSDK`，请补充可用源后再安装。

### Android

插件已内置：
- Maven 仓库：`https://artifact.bytedance.com/repository/Volcengine/`
- 依赖：`com.bytedance.ads:AppConvert:2.0.4`

## 3. 隐私与合规

- 建议在用户同意隐私协议后再初始化并触发启动上报。
- iOS 若启用 IDFA：
  - 需完成 ATT 授权流程。
  - 需按 App Store 要求申明 IDFA 用途。

## 4. Flutter API

主入口类：`Bdasignalsdk`

```dart
final sdk = Bdasignalsdk();
```

### 初始化

```dart
Future<void> initialize({
  Map<String, dynamic>? optionalData,
  bool delayUploadEnabled = false,
  bool idfaEnabled = false,
  bool autoSendLaunchEvent = true,
  bool enableLog = false,
  bool playSessionEnable = true,
  bool enableOAID = true,
  bool enableLifecycleCallback = false,
})
```

### 运行时控制

```dart
Future<void> setOptionalData(Map<String, dynamic> optionalData)
Future<void> enableIdfa(bool enabled)
Future<void> enableDelayUpload()
Future<void> startSendingEvents()
Future<void> analyzeDeeplinkClickid(String openUrl)
Future<void> sendLaunchEvent({
  Map<String, dynamic>? launchOptions,
  Map<String, dynamic>? connectOptions,
})
Future<void> enablePurchaseEvent()
```

说明：
- `sendLaunchEvent` 在 iOS 侧仅作兜底触发（仅冷启动回调缺失时才会发送，避免重复上报）。
- `connectOptions` 主要用于接口对齐；iOS 真正的 Scene `connectionOptions` 建议通过 SceneDelegate 原生回调转发。

### 事件上报

```dart
Future<void> trackEvent(String name, {Map<String, dynamic>? params})
Future<void> trackRegisterEvent({required String registerMethod, required bool isSuccess})
Future<void> trackLoginEvent({required String method, required bool isSuccess})
Future<void> trackPurchaseEvent({
  String? contentType,
  String? contentName,
  String? contentId,
  int? contentNumber,
  String? paymentChannel,
  String? currency,
  required bool isSuccess,
  num? currencyAmount,
})
Future<void> trackGameAddictionEvent({Map<String, dynamic>? params})
```

## 5. 推荐接入流程

1. 创建 SDK 实例。
2. 用户同意隐私协议后调用 `initialize(...)`。
3. 如果采用延时上报策略，调用 `startSendingEvents()`（未调用将不会发送事件）。
4. 收到 Deeplink 时调用 `analyzeDeeplinkClickid(url)`。
5. 使用类型化 API 上报关键转化事件。
6. 使用 `trackEvent(...)` 上报自定义事件。

## 6. 使用示例

```dart
import 'package:flutter_bdasignalsdk/bdasignalsdk.dart';

final sdk = Bdasignalsdk();

Future<void> initAfterPrivacyAgreed() async {
  await sdk.initialize(
    optionalData: {
      'user_unique_id': 'biz_uid_123',
      'extra_param': 'xxx',
    },
    delayUploadEnabled: false,
    idfaEnabled: false,
    autoSendLaunchEvent: true,
    enableLog: false,
    playSessionEnable: true,
    enableOAID: true,
    enableLifecycleCallback: true,
  );

  await sdk.startSendingEvents();
}

Future<void> onDeepLink(String url) async {
  await sdk.analyzeDeeplinkClickid(url);
}

Future<void> reportEvents() async {
  await sdk.trackRegisterEvent(registerMethod: 'wechat', isSuccess: true);
  await sdk.trackLoginEvent(method: 'wechat', isSuccess: true);
  await sdk.trackPurchaseEvent(
    contentType: 'gift',
    contentName: 'flower',
    contentId: '008',
    contentNumber: 1,
    paymentChannel: 'wechat',
    currency: 'CNY',
    isSuccess: true,
    currencyAmount: 1,
  );
  await sdk.trackGameAddictionEvent(params: {'origin_event': 'some_event'});
  await sdk.trackEvent('custom_event', params: {'k1': 'v1'});
}
```

## 7. 平台兼容性说明

- 仅 iOS 生效的方法：
  - `enableIdfa`
  - `enableDelayUpload`
  - `startSendingEvents`
  - `enablePurchaseEvent`
- Android 对部分接口当前为兼容空实现（调用不报错，但无实际动作）。
- `getClickId` 已按设计从对外 API 移除。
- Android 可通过 `enableLifecycleCallback=true` 开启初始化与事件发送回调透传：

```dart
sdk.androidLifecycleCallbackStream.listen((event) {
  // event["callback"] 为回调名，event["args"] 为参数字符串数组
});
```

- iOS 使用 SceneDelegate 时，可在宿主 `SceneDelegate` 中转发：

```swift
@available(iOS 13.0, *)
func scene(
  _ scene: UIScene,
  willConnectTo session: UISceneSession,
  options connectionOptions: UIScene.ConnectionOptions
) {
  BdasignalsdkPlugin.forwardSceneWillConnect(connectionOptions: connectionOptions)
}

@available(iOS 13.0, *)
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
  BdasignalsdkPlugin.forwardSceneOpenURLContexts(URLContexts)
}
```

## 8. 最小外部 API 建议

业务层建议优先使用以下最小集合：
- `initialize`
- `startSendingEvents`（仅使用延时上报策略时）
- `analyzeDeeplinkClickid`
- `trackRegisterEvent`
- `trackLoginEvent`
- `trackPurchaseEvent`
- `trackGameAddictionEvent`
- `trackEvent`
