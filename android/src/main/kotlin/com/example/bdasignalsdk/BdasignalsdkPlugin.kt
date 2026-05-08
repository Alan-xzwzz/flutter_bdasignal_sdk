package com.example.bdasignalsdk

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.bytedance.ads.convert.BDConvert
import com.bytedance.ads.convert.callback.BDConvertLifecycleCallback
import com.bytedance.ads.convert.config.BDConvertConfig
import com.bytedance.ads.convert.event.ConvertReportHelper
import org.json.JSONArray
import org.json.JSONObject
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/**
 * Flutter 到 Android 的 AppConvert 桥接层。
 *
 * 设计目标：
 * 1) Flutter API 对业务保持稳定，底层可兼容 SDK 包名/类名变化。
 * 2) Android 端缺失的能力尽量优雅降级，不影响主流程。
 * 3) 通过反射减少对具体 SDK 类路径的硬编码依赖。
 */
class BdasignalsdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var applicationContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // applicationContext 在插件生命周期内持有是安全的。
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "bdasignalsdk")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        // 统一在此处维护 Flutter 方法名到 Android 能力的映射关系。
        when (call.method) {
            "initialize" -> {
                val args = call.arguments as? Map<*, *>
                val autoSendLaunchEvent = (args?.get("autoSendLaunchEvent") as? Boolean) ?: true
                val enableLog = (args?.get("enableLog") as? Boolean) ?: false
                val playSessionEnable = (args?.get("playSessionEnable") as? Boolean) ?: true
                val enableOAID = (args?.get("enableOAID") as? Boolean) ?: true
                val enableLifecycleCallback = (args?.get("enableLifecycleCallback") as? Boolean) ?: false
                val initError = initializeAndroid(
                    autoSendLaunchEvent = autoSendLaunchEvent,
                    enableLog = enableLog,
                    playSessionEnable = playSessionEnable,
                    enableOAID = enableOAID,
                    enableLifecycleCallback = enableLifecycleCallback
                )
                if (initError == null) {
                    result.success(null)
                } else {
                    result.error("init_failed", initError, null)
                }
            }
            "sendLaunchEvent" -> {
                val sendError = sendLaunchEvent()
                if (sendError == null) {
                    result.success(null)
                } else {
                    result.error("send_launch_failed", sendError, null)
                }
            }
            "trackEvent" -> {
                val args = call.arguments as? Map<*, *>
                val name = args?.get("name") as? String
                val params = args?.get("params") as? Map<*, *>
                if (name.isNullOrBlank()) {
                    result.error("bad_args", "name required", null)
                    return
                }
                val eventError = trackEvent(name, params)
                if (eventError == null) {
                    result.success(null)
                } else {
                    result.error("track_event_failed", eventError, null)
                }
            }
            "trackRegisterEvent" -> {
                val args = call.arguments as? Map<*, *>
                val registerMethod = args?.get("registerMethod") as? String
                val isSuccess = args?.get("isSuccess") as? Boolean
                if (registerMethod.isNullOrBlank() || isSuccess == null) {
                    result.error("bad_args", "registerMethod/isSuccess required", null)
                    return
                }
                val eventError = trackRegisterEvent(registerMethod, isSuccess)
                if (eventError == null) {
                    result.success(null)
                } else {
                    result.error("track_register_failed", eventError, null)
                }
            }
            "trackPurchaseEvent" -> {
                val args = call.arguments as? Map<*, *>
                val isSuccess = args?.get("isSuccess") as? Boolean
                if (isSuccess == null) {
                    result.error("bad_args", "isSuccess required", null)
                    return
                }
                val eventError = trackPurchaseEvent(args, isSuccess)
                if (eventError == null) {
                    result.success(null)
                } else {
                    result.error("track_purchase_failed", eventError, null)
                }
            }
            "trackLoginEvent" -> {
                val args = call.arguments as? Map<*, *>
                val method = args?.get("method") as? String
                val isSuccess = args?.get("isSuccess") as? Boolean
                if (method.isNullOrBlank() || isSuccess == null) {
                    result.error("bad_args", "method/isSuccess required", null)
                    return
                }
                val eventError = trackLoginEvent(method, isSuccess)
                if (eventError == null) {
                    result.success(null)
                } else {
                    result.error("track_login_failed", eventError, null)
                }
            }
            "trackGameAddictionEvent" -> {
                val args = call.arguments as? Map<*, *>
                val params = args?.get("params") as? Map<*, *>
                val eventError = trackGameAddictionEvent(params)
                if (eventError == null) {
                    result.success(null)
                } else {
                    result.error("track_game_addiction_failed", eventError, null)
                }
            }
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "enableIdfa",
            "enableDelayUpload",
            "startSendingEvents",
            "analyzeDeeplinkClickid",
            "enablePurchaseEvent",
            "setOptionalData" -> {
                // 这些接口当前是 iOS 主能力。
                // Android 侧返回 success 作为兼容空实现，避免 Dart 端分支报错。
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
        activity = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        // 预留：后续如需增强，可在插件内直接扩展 intent/deeplink 处理。
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onNewIntent(intent: android.content.Intent): Boolean {
        // 当前不消费 intent，返回 false 让宿主继续按默认链路处理。
        return false
    }

    private fun initializeAndroid(
        autoSendLaunchEvent: Boolean,
        enableLog: Boolean,
        playSessionEnable: Boolean,
        enableOAID: Boolean,
        enableLifecycleCallback: Boolean
    ): String? {
        // 优先使用 applicationContext；若绑定较晚则回退到 activity。
        val ctx = applicationContext ?: activity ?: return "context not available"
        val act = activity
        val config = BDConvertConfig().apply {
            this.autoSendLaunchEvent = autoSendLaunchEvent
            this.enableLog = enableLog
            this.playSessionEnable = playSessionEnable
            this.enableOAID = enableOAID
        }
        if (enableLifecycleCallback) {
            attachLifecycleCallback(config)
        }

        if (autoSendLaunchEvent && act != null) {
            // 方案 A：传入前台 Activity 进行 init，初始化后自动上报启动事件。
            return try {
                BDConvert.init(ctx, config, act)
                null
            } catch (t: Throwable) {
                t.message ?: "init(Context, Config, Activity) invoke failed"
            }
        } else {
            // 方案 B：先以 Application 初始化，启动事件由 sendLaunchEvent 另行触发。
            val app = (act?.application) ?: (ctx.applicationContext as? Application)
            if (app != null) {
                return try {
                    BDConvert.init(app, config)
                    null
                } catch (t: Throwable) {
                    t.message ?: "init(Application, Config) invoke failed"
                }
            } else {
                return "application not available for init"
            }
        }
    }

    private fun sendLaunchEvent(): String? {
        val ctx = applicationContext ?: activity ?: return "context not available"
        // sendLaunchEvent 可能涉及网络和设备标识采集，放子线程执行更稳妥。
        return try {
            BDConvert.sendLaunchEvent(ctx)
            null
        } catch (t: Throwable) {
            t.message ?: "sendLaunchEvent(Context) invoke failed"
        }
    }

    private fun trackEvent(name: String, params: Map<*, *>?): String? {
        val json = mapToJson(params)
        try {
            ConvertReportHelper.onEventV3(name, json)
            return null
        } catch (t: Throwable) {
            // 调用失败时回传给 Flutter，避免“静默失败”。
            return t.message ?: "unknown sdk error"
        }
    }

    private fun trackRegisterEvent(registerMethod: String, isSuccess: Boolean): String? {
        try {
            ConvertReportHelper.onEventRegister(registerMethod, isSuccess)
            return null
        } catch (_: Throwable) {
            // 若类型化接口不可用，降级为通用事件上报。
        }
        return trackEvent("register", mapOf("register_method" to registerMethod, "is_success" to isSuccess))
    }

    private fun trackPurchaseEvent(args: Map<*, *>?, isSuccess: Boolean): String? {
        val contentType = args?.get("contentType")?.toString() ?: ""
        val contentName = args?.get("contentName")?.toString() ?: ""
        val contentId = args?.get("contentId")?.toString() ?: ""
        val contentNumber = (args?.get("contentNumber") as? Number)?.toInt() ?: 1
        val paymentChannel = args?.get("paymentChannel")?.toString() ?: ""
        val currency = args?.get("currency")?.toString() ?: ""
        val currencyAmount = (args?.get("currencyAmount") as? Number)?.toInt() ?: 0 
        try {
            ConvertReportHelper.onEventPurchase(
                contentType,
                contentName,
                contentId,
                contentNumber,
                paymentChannel,
                currency,
                isSuccess,
                currencyAmount
            )
            return null
        } catch (_: Throwable) {
            // 即使 purchase 专用接口缺失，也通过通用事件保留业务信号。
        }
        return trackEvent(
            "purchase",
            mapOf(
                "content_type" to contentType,
                "content_name" to contentName,
                "content_id" to contentId,
                "content_number" to contentNumber,
                "payment_channel" to paymentChannel,
                "currency" to currency,
                "is_success" to isSuccess,
                "currency_amount" to currencyAmount
            )
        )
    }

    private fun trackLoginEvent(methodName: String, isSuccess: Boolean): String? {
        try {
            ConvertReportHelper.onLoginEvent(methodName, isSuccess)
            return null
        } catch (_: Throwable) {
            // 登录专用接口不可用时，降级为通用事件以兼容不同 SDK 版本。
        }
        return trackEvent("login", mapOf("method" to methodName, "is_success" to isSuccess))
    }

    private fun trackGameAddictionEvent(params: Map<*, *>?): String? {
        return trackEvent("game_addiction", params ?: emptyMap<String, Any>())
    }

    private fun attachLifecycleCallback(config: BDConvertConfig) {
        config.lifecycleCallback = object : BDConvertLifecycleCallback {
            override fun onInitSuccess() {
                emitLifecycleEvent("onInitSuccess", listOf())
            }

            override fun onInitFailure(reason: Int, throwable: Throwable?) {
                emitLifecycleEvent(
                    "onInitFailure",
                    listOf(reason.toString(), throwable?.message)
                )
            }

            override fun onEventSendSuccess(eventName: String, requestId: String) {
                emitLifecycleEvent(
                    "onEventSendSuccess",
                    listOf(eventName, requestId)
                )
            }

            override fun onEventSendFailure(
                eventName: String,
                reason: Int,
                requestId: String,
                throwable: Throwable?
            ) {
                emitLifecycleEvent(
                    "onEventSendFailure",
                    listOf(eventName, reason.toString(), requestId, throwable?.message)
                )
            }

            override fun onOtherError(reason: Int, throwable: Throwable?) {
                emitLifecycleEvent(
                    "onOtherError",
                    listOf(reason.toString(), throwable?.message)
                )
            }
        }
    }

    private fun emitLifecycleEvent(callback: String, args: List<String?>) {
        val payload = HashMap<String, Any?>()
        payload["callback"] = callback
        payload["args"] = args
        mainHandler.post {
            channel.invokeMethod("androidLifecycleCallback", payload)
        }
    }

    private fun mapToJson(map: Map<*, *>?): JSONObject {
        val json = JSONObject()
        if (map == null) return json
        for ((k, v) in map) {
            val key = k?.toString() ?: continue
            when (v) {
                null -> json.put(key, JSONObject.NULL)
                is Boolean, is Int, is Long, is Double, is Float, is String -> json.put(key, v)
                is Map<*, *> -> json.put(key, mapToJson(v))
                is List<*> -> json.put(key, listToJsonArray(v))
                else -> json.put(key, v.toString())
            }
        }
        return json
    }

    private fun listToJsonArray(list: List<*>): JSONArray {
        val arr = JSONArray()
        for (item in list) {
            when (item) {
                null -> arr.put(JSONObject.NULL)
                is Boolean, is Int, is Long, is Double, is Float, is String -> arr.put(item)
                is Map<*, *> -> arr.put(mapToJson(item))
                is List<*> -> arr.put(listToJsonArray(item))
                else -> arr.put(item.toString())
            }
        }
        return arr
    }
}
