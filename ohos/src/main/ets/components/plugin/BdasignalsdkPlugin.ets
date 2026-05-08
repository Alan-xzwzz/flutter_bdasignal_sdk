import {
  AbilityAware,
  Any,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import deviceInfo from '@ohos.deviceInfo';
import hilog from '@ohos.hilog';
import { BDConvert, BDConvertConfig, ConvertReportHelper } from '@bytedance_ads/app_convert';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const LOG_DOMAIN: number = 0x0000;
const LOG_TAG: string = 'BdasignalsdkPlugin';
const CHANNEL_NAME: string = 'bdasignalsdk';

export default class BdasignalsdkPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private abilityContext: common.UIAbilityContext | null = null;

  getUniqueClassName(): string {
    return 'BdasignalsdkPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', 'attached to engine');
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', 'detached from engine');
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityContext = binding.getAbility().context;
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', 'attached to ability');
  }

  onDetachedFromAbility(): void {
    this.abilityContext = null;
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', 'detached from ability');
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    void this.handleMethodCall(call, result);
  }

  private async handleMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onMethodCall: %{public}s', call.method);
    switch (call.method) {
      case 'getPlatformVersion':
        result.success(deviceInfo.osFullName);
        return;
      case 'initialize': {
        const initialized: boolean = await this.initSdk(call);
        if (!initialized) {
          result.error('init_failed', 'BDConvert init failed', null);
          return;
        }
        result.success(null);
        return;
      }
      case 'setOptionalData':
      case 'enableIdfa':
      case 'enableDelayUpload':
      case 'startSendingEvents':
      case 'analyzeDeeplinkClickid':
        // OHOS AppConvert 当前未提供与 iOS/Android 完全等价的这些控制 API，先兼容空实现。
        result.success(null);
        return;
      case 'trackEvent':
        this.handleTrackEvent(call);
        result.success(null);
        return;
      case 'trackRegisterEvent':
        this.handleTrackRegisterEvent(call);
        result.success(null);
        return;
      case 'trackPurchaseEvent':
        this.handleTrackPurchaseEvent(call);
        result.success(null);
        return;
      case 'trackLoginEvent':
        this.handleTrackLoginEvent(call);
        result.success(null);
        return;
      case 'trackGameAddictionEvent':
        this.handleTrackGameAddictionEvent(call);
        result.success(null);
        return;
      case 'enablePurchaseEvent':
      case 'sendLaunchEvent':
        // OHOS AppConvert 当前未提供对应接口，兼容空实现。
        result.success(null);
        return;
      default:
        result.notImplemented();
        return;
    }
  }

  private async initSdk(call: MethodCall): Promise<boolean> {
    if (this.abilityContext == null) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '%{public}s', 'initSdk failed: ability context is null');
      return false;
    }

    const permissionGranted: boolean = await this.requestTrackingPermission(
      'ohos.permission.APP_TRACKING_CONSENT',
      this.abilityContext
    );
    hilog.info(LOG_DOMAIN, LOG_TAG, 'tracking permission granted: %{public}s', String(permissionGranted));

    try {
      const config: BDConvertConfig = this.buildInitConfig(call);
      // 无论是否已授权 APP_TRACKING_CONSENT，SDK 内部都会再做权限判断。
      BDConvert.getInstance().init(this.abilityContext, config);
      hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', 'BDConvert init success');
      return true;
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'BDConvert init failed: %{public}s', message);
      return false;
    }
  }

  private async requestTrackingPermission(
    permission: Permissions,
    context: common.Context
  ): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const data: abilityAccessCtrl.PermissionRequestResult = await atManager.requestPermissionsFromUser(
        context,
        [permission]
      );
      const grantStatus: Array<number> = data.authResults;
      for (let i: number = 0; i < grantStatus.length; i++) {
        if (grantStatus[i] !== 0) {
          return false;
        }
      }
      return true;
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      hilog.error(
        LOG_DOMAIN,
        LOG_TAG,
        'request APP_TRACKING_CONSENT failed, code=%{public}d, message=%{public}s',
        err.code ?? -1,
        err.message ?? ''
      );
      return false;
    }
  }

  private buildInitConfig(call: MethodCall): BDConvertConfig {
    const config: BDConvertConfig = new BDConvertConfig();
    config.autoSendLaunchEvent = this.readBoolArg(call, 'autoSendLaunchEvent', true);
    config.enableLog = this.readBoolArg(call, 'enableLog', false);
    config.enablePlaySessionEvent = this.readBoolArg(call, 'playSessionEnable', true);
    config.enableOAIDTrack = this.readBoolArg(call, 'enableOAID', true);
    const customOaid: string = this.readStringArg(call, 'customOaid', '');
    if (customOaid.length > 0) {
      config.customOaidCallback = () => {
        return customOaid;
      };
    }
    return config;
  }

  private handleTrackRegisterEvent(call: MethodCall): void {
    const registerMethod: string = this.readStringArg(call, 'registerMethod', '');
    const isSuccess: boolean = this.readBoolArg(call, 'isSuccess', false);
    ConvertReportHelper.onEventRegister(registerMethod, isSuccess);
  }

  private handleTrackPurchaseEvent(call: MethodCall): void {
    const contentType: string = this.readStringArg(call, 'contentType', '');
    const contentName: string = this.readStringArg(call, 'contentName', '');
    const contentId: string = this.readStringArg(call, 'contentId', '');
    const contentNumber: number = this.readIntArg(call, 'contentNumber', 1);
    const paymentChannel: string = this.readStringArg(call, 'paymentChannel', '');
    const currency: string = this.readStringArg(call, 'currency', '');
    const isSuccess: boolean = this.readBoolArg(call, 'isSuccess', false);
    const currencyAmount: number = this.readNumberArg(call, 'currencyAmount', 0);
    ConvertReportHelper.onEventPurchase(
      contentType,
      contentName,
      contentId,
      contentNumber,
      paymentChannel,
      currency,
      isSuccess,
      currencyAmount
    );
  }

  private handleTrackEvent(call: MethodCall): void {
    const eventName: string = this.readStringArg(call, 'name', '');
    const params: Object = this.readObjectArg(call, 'params');
    ConvertReportHelper.onEventV3(eventName, params);
  }

  private handleTrackGameAddictionEvent(call: MethodCall): void {
    const params: Object = this.readObjectArg(call, 'params');
    ConvertReportHelper.onEventV3('game_addiction', params);
  }

  private handleTrackLoginEvent(call: MethodCall): void {
    const method: string = this.readStringArg(call, 'method', '');
    const isSuccess: boolean = this.readBoolArg(call, 'isSuccess', false);
    ConvertReportHelper.onEventV3('login', {
      method: method,
      is_success: isSuccess,
    });
  }

  private readArg(call: MethodCall, key: string): Any {
    const args = call.args;
    if (args instanceof Map) {
      return args.get(key);
    }
    return undefined;
  }

  private readStringArg(call: MethodCall, key: string, fallback: string): string {
    const value: Any = this.readArg(call, key);
    if (typeof value === 'string') {
      return value;
    }
    return fallback;
  }

  private readBoolArg(call: MethodCall, key: string, fallback: boolean): boolean {
    const value: Any = this.readArg(call, key);
    if (typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'string') {
      return value.toLowerCase() === 'true';
    }
    return fallback;
  }

  private readNumberArg(call: MethodCall, key: string, fallback: number): number {
    const value: Any = this.readArg(call, key);
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string' && value.length > 0) {
      const parsed: number = Number(value);
      return Number.isNaN(parsed) ? fallback : parsed;
    }
    return fallback;
  }

  private readIntArg(call: MethodCall, key: string, fallback: number): number {
    return Math.trunc(this.readNumberArg(call, key, fallback));
  }

  private readObjectArg(call: MethodCall, key: string): Object {
    const value: Any = this.readArg(call, key);
    if (value instanceof Map) {
      const obj: Record<string, Any> = {};
      value.forEach((mapValue: Any, mapKey: string) => {
        obj[mapKey] = mapValue;
      });
      return obj as Object;
    }
    if (typeof value === 'object' && value != null) {
      return value as Object;
    }
    return {};
  }
}
