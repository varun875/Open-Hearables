package com.openhearables.open_hearables

import android.Manifest
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID

class BluetoothAudioPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodCallHandler, BluetoothProfile.ServiceListener {

    companion object {
        const val CHANNEL_NAME = "com.openhearables.app/bluetooth_audio"
        private const val EXTRA_BATTERY_LEVEL = "android.bluetooth.device.extra.BATTERY_LEVEL"
        val UUID_JIELI_SERVICE: UUID = UUID.fromString("0000ae00-0000-1000-8000-00805f9b34fb")
        val UUID_JIELI_WRITE: UUID = UUID.fromString("0000ae01-0000-1000-8000-00805f9b34fb")
        val UUID_JIELI_NOTIFY: UUID = UUID.fromString("0000ae02-0000-1000-8000-00805f9b34fb")
        val UUID_CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        val UUID_JIELI_SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

    private var a2dpProfile: BluetoothA2dp? = null
    private var headsetProfile: BluetoothHeadset? = null
    private val batteryCache = mutableMapOf<String, Int>()
    private var isReceiverRegistered = false

    private var bluetoothGatt: BluetoothGatt? = null
    private var gattWriteChar: BluetoothGattCharacteristic? = null
    private var activeDevice: BluetoothDevice? = null

    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent ?: return
            when (intent.action) {
                BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED,
                BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED,
                BluetoothDevice.ACTION_ACL_CONNECTED,
                BluetoothDevice.ACTION_ACL_DISCONNECTED,
                BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED,
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    notifyDeviceChanged()
                }
                "android.bluetooth.device.action.BATTERY_LEVEL_CHANGED" -> {
                    val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    val level = intent.getIntExtra(EXTRA_BATTERY_LEVEL, -1)
                    if (device != null && level >= 0) {
                        if (hasConnectPermission()) {
                            try {
                                batteryCache[device.address] = level
                            } catch (_: SecurityException) {}
                        }
                        notifyDeviceChanged()
                    }
                }
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)
        registerReceiver()
        initProfiles()
    }

    private fun hasConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun registerReceiver() {
        if (isReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction("android.bluetooth.device.action.BATTERY_LEVEL_CHANGED")
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(bluetoothReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(bluetoothReceiver, filter)
            }
            isReceiverRegistered = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun initProfiles() {
        bluetoothAdapter?.let { adapter ->
            adapter.getProfileProxy(context, this, BluetoothProfile.A2DP)
            adapter.getProfileProxy(context, this, BluetoothProfile.HEADSET)
        }
    }

    override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
        when (profile) {
            BluetoothProfile.A2DP -> a2dpProfile = proxy as? BluetoothA2dp
            BluetoothProfile.HEADSET -> headsetProfile = proxy as? BluetoothHeadset
        }
        notifyDeviceChanged()
    }

    override fun onServiceDisconnected(profile: Int) {
        when (profile) {
            BluetoothProfile.A2DP -> a2dpProfile = null
            BluetoothProfile.HEADSET -> headsetProfile = null
        }
        notifyDeviceChanged()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getConnectedAudioDevice" -> {
                try {
                    val info = getConnectedAudioDeviceInfo()
                    result.success(info)
                } catch (e: Exception) {
                    result.error("DEVICE_FETCH_FAILED", e.localizedMessage, null)
                }
            }
            "sendRcspPacket" -> {
                val packet = call.argument<ByteArray>("packet")
                if (packet == null || packet.isEmpty()) {
                    result.error("INVALID_PACKET", "Packet was null or empty", null)
                    return
                }
                sendPacketToDevice(packet, result)
            }
            else -> result.notImplemented()
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                if (hasConnectPermission()) {
                    try {
                        gatt?.discoverServices()
                    } catch (_: SecurityException) {}
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                gattWriteChar = null
                if (gatt == bluetoothGatt) {
                    try { gatt?.close() } catch (_: Exception) {}
                    bluetoothGatt = null
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS && gatt != null) {
                val service = gatt.getService(UUID_JIELI_SERVICE)
                if (service != null) {
                    gattWriteChar = service.getCharacteristic(UUID_JIELI_WRITE)
                    val notifyChar = service.getCharacteristic(UUID_JIELI_NOTIFY)
                    if (notifyChar != null && hasConnectPermission()) {
                        try {
                            gatt.setCharacteristicNotification(notifyChar, true)
                            val cccd = notifyChar.getDescriptor(UUID_CCCD)
                            if (cccd != null) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    gatt.writeDescriptor(cccd, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                                } else {
                                    @Suppress("DEPRECATION")
                                    cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                    @Suppress("DEPRECATION")
                                    gatt.writeDescriptor(cccd)
                                }
                            }
                        } catch (_: SecurityException) {}
                    }
                }
            }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            handleIncomingRcspData(characteristic.value)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            handleIncomingRcspData(value)
        }
    }

    private fun handleIncomingRcspData(data: ByteArray?) {
        data ?: return
        mainHandler.post {
            try {
                channel.invokeMethod("onRcspData", data)
            } catch (_: Exception) {}
        }
    }

    private fun ensureGattConnection(device: BluetoothDevice) {
        if (!hasConnectPermission()) return
        if (bluetoothGatt != null && activeDevice?.address == device.address && gattWriteChar != null) {
            return
        }
        try {
            bluetoothGatt?.close()
            bluetoothGatt = null
            gattWriteChar = null
            activeDevice = device
            bluetoothGatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getPrimaryConnectedDevice(): BluetoothDevice? {
        if (!hasConnectPermission()) return null
        try {
            val a2dpDevices = a2dpProfile?.connectedDevices ?: emptyList()
            if (a2dpDevices.isNotEmpty()) return a2dpDevices.first()
            val headsetDevices = headsetProfile?.connectedDevices ?: emptyList()
            if (headsetDevices.isNotEmpty()) return headsetDevices.first()
            val bonded = bluetoothAdapter?.bondedDevices ?: emptySet()
            return bonded.firstOrNull { dev ->
                val name = dev.name ?: ""
                name.contains("airdopes", ignoreCase = true) || name.contains("boat", ignoreCase = true)
            }
        } catch (_: SecurityException) {}
        return null
    }

    private fun sendPacketToDevice(packet: ByteArray, result: Result) {
        val device = activeDevice ?: getPrimaryConnectedDevice()
        if (device != null) {
            ensureGattConnection(device)
        }

        var gattSent = false
        if (hasConnectPermission() && bluetoothGatt != null && gattWriteChar != null) {
            try {
                val writeChar = gattWriteChar!!
                writeChar.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                gattSent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    bluetoothGatt!!.writeCharacteristic(writeChar, packet, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) == 0
                } else {
                    @Suppress("DEPRECATION")
                    writeChar.value = packet
                    @Suppress("DEPRECATION")
                    bluetoothGatt!!.writeCharacteristic(writeChar)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Resilient dual delivery: Parallel SPP RFCOMM send
        if (device != null && hasConnectPermission()) {
            Thread {
                try {
                    val socket = device.createRfcommSocketToServiceRecord(UUID_JIELI_SPP)
                    socket.connect()
                    socket.outputStream.write(packet)
                    socket.outputStream.flush()
                    Thread.sleep(50)
                    socket.close()
                } catch (_: Exception) {}
            }.start()
        }

        result.success(gattSent || device != null)
    }

    private fun notifyDeviceChanged() {
        mainHandler.post {
            try {
                val info = getConnectedAudioDeviceInfo()
                channel.invokeMethod("onDeviceStateChanged", info)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun getBatteryLevel(device: BluetoothDevice): Int {
        if (!hasConnectPermission()) return -1
        try {
            val address = device.address
            val cached = batteryCache[address]
            if (cached != null && cached >= 0) {
                return cached
            }
        } catch (_: SecurityException) {}

        try {
            val method = device.javaClass.getMethod("getBatteryLevel")
            val level = method.invoke(device) as? Int
            if (level != null && level >= 0) {
                return level
            }
        } catch (_: Exception) {}

        return -1
    }

    private fun getConnectedAudioDeviceInfo(): Map<String, Any?> {
        // Priority 1: Check A2DP / Headset profile proxy connected devices
        if (hasConnectPermission()) {
            try {
                val a2dpDevices = a2dpProfile?.connectedDevices ?: emptyList()
                val headsetDevices = headsetProfile?.connectedDevices ?: emptyList()
                val devices = (a2dpDevices + headsetDevices).distinctBy { it.address }

                for (dev in devices) {
                    val name = dev.name?.takeIf { it.isNotBlank() } ?: "Connected Audio Device"
                    val address = dev.address ?: ""
                    val battery = getBatteryLevel(dev)

                    activeDevice = dev
                    ensureGattConnection(dev)

                    return mapOf(
                        "isConnected" to true,
                        "name" to name,
                        "address" to address,
                        "batteryLevel" to battery
                    )
                }
            } catch (e: SecurityException) {
                // Ignore and fall through to AudioManager
            }
        }

        // Priority 2: Check AudioManager connected output devices (does not require BLUETOOTH_CONNECT)
        val outputs = audioManager?.getDevices(AudioManager.GET_DEVICES_OUTPUTS) ?: emptyArray()
        for (info in outputs) {
            if (info.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                info.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && info.type == AudioDeviceInfo.TYPE_BLE_HEADSET)
            ) {
                val name = info.productName?.toString()?.takeIf { it.isNotBlank() } ?: "Connected Audio Device"
                val address = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && hasConnectPermission()) {
                    try { info.address ?: "" } catch (_: SecurityException) { "" }
                } else {
                    ""
                }
                var battery = -1
                if (address.isNotBlank()) {
                    battery = batteryCache[address] ?: -1
                }

                return mapOf(
                    "isConnected" to true,
                    "name" to name,
                    "address" to address,
                    "batteryLevel" to battery
                )
            }
        }

        // Priority 3: Fallback check bonded devices if adapter is connected
        if (hasConnectPermission() && bluetoothAdapter != null && bluetoothAdapter.isEnabled) {
            try {
                val bonded = bluetoothAdapter.bondedDevices ?: emptySet()
                for (dev in bonded) {
                    val name = dev.name ?: ""
                    if (name.contains("airdopes", ignoreCase = true) ||
                        name.contains("boat", ignoreCase = true)
                    ) {
                        val battery = getBatteryLevel(dev)
                        if (battery >= 0) {
                            return mapOf(
                                "isConnected" to true,
                                "name" to name,
                                "address" to dev.address,
                                "batteryLevel" to battery
                            )
                        }
                    }
                }
            } catch (_: SecurityException) {}
        }

        return mapOf(
            "isConnected" to false,
            "name" to "boAt Airdopes 311 Plus",
            "address" to "Scanning...",
            "batteryLevel" to -1
        )
    }

    fun release() {
        if (isReceiverRegistered) {
            try {
                context.unregisterReceiver(bluetoothReceiver)
                isReceiverRegistered = false
            } catch (_: Exception) {}
        }
        bluetoothAdapter?.let { adapter ->
            a2dpProfile?.let { adapter.closeProfileProxy(BluetoothProfile.A2DP, it) }
            headsetProfile?.let { adapter.closeProfileProxy(BluetoothProfile.HEADSET, it) }
        }
        a2dpProfile = null
        headsetProfile = null
    }
}
