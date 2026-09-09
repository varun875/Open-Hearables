package com.openhearables.open_hearables

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var equalizerPlugin: SystemEqualizerPlugin? = null
    private var rcspPlugin: JieliRcspPlugin? = null
    private var bluetoothAudioPlugin: BluetoothAudioPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        equalizerPlugin = SystemEqualizerPlugin(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SystemEqualizerPlugin.CHANNEL_NAME)
            .setMethodCallHandler(equalizerPlugin)

        rcspPlugin = JieliRcspPlugin()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, JieliRcspPlugin.CHANNEL_NAME)
            .setMethodCallHandler(rcspPlugin)

        bluetoothAudioPlugin = BluetoothAudioPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        equalizerPlugin?.release()
        bluetoothAudioPlugin?.release()
        super.onDestroy()
    }
}
