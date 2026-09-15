package com.openhearables.open_hearables

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** Exposes [RcspFrame] packet construction to Dart. */
class JieliRcspPlugin : MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.openhearables.app/rcsp"
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "buildLowLatencyPacket" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                result.success(RcspFrame.lowLatencyCommand(enabled))
            }
            else -> result.notImplemented()
        }
    }
}
