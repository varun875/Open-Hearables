package com.openhearables.open_hearables

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import java.util.UUID

class OpenHearablesTileService : TileService() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_KEY = "flutter.is_beast_mode"

        val UUID_JIELI_SERVICE: UUID = UUID.fromString("0000ae00-0000-1000-8000-00805f9b34fb")
        val UUID_JIELI_WRITE: UUID = UUID.fromString("0000ae01-0000-1000-8000-00805f9b34fb")
        val UUID_JIELI_SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")
    }

    private val prefs: SharedPreferences by lazy {
        applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTileState(isBeastModeActive())
    }

    override fun onClick() {
        super.onClick()
        val nextState = !isBeastModeActive()
        setBeastModeActive(nextState)
        updateTileState(nextState)
        dispatchBeastModePacket(nextState)
    }

    private fun isBeastModeActive(): Boolean {
        return prefs.getBoolean(PREF_KEY, false)
    }

    private fun setBeastModeActive(active: Boolean) {
        prefs.edit().putBoolean(PREF_KEY, active).apply()
    }

    private fun updateTileState(active: Boolean) {
        val tile = qsTile ?: return
        tile.icon = Icon.createWithResource(this, R.drawable.ic_tile_beast_mode)
        tile.label = "Beast Mode"
        tile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (active) "Active (65ms)" else "Off"
        }
        tile.updateTile()
    }

    private fun hasConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun dispatchBeastModePacket(enabled: Boolean) {
        if (!hasConnectPermission()) return

        val packet = RcspFrame.lowLatencyCommand(enabled)

        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val btAdapter = btManager?.adapter ?: BluetoothAdapter.getDefaultAdapter() ?: return
        if (!btAdapter.isEnabled) return

        try {
            val bonded = btAdapter.bondedDevices ?: emptySet()
            val targetDevice = bonded.firstOrNull { dev ->
                val name = dev.name ?: ""
                name.contains("airdopes", ignoreCase = true) || name.contains("boat", ignoreCase = true)
            } ?: bonded.firstOrNull() ?: return

            // 1. Dual delivery: Send via SPP RFCOMM in worker thread
            Thread {
                try {
                    val socket = targetDevice.createRfcommSocketToServiceRecord(UUID_JIELI_SPP)
                    socket.connect()
                    socket.outputStream.write(packet)
                    socket.outputStream.flush()
                    Thread.sleep(50)
                    socket.close()
                } catch (_: Exception) {}
            }.start()

            // 2. Dual delivery: Send via BLE GATT
            targetDevice.connectGatt(this, false, object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED && gatt != null) {
                        try {
                            gatt.discoverServices()
                        } catch (_: SecurityException) {}
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        gatt?.close()
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                    gatt ?: return
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val svc = gatt.getService(UUID_JIELI_SERVICE)
                        val chr = svc?.getCharacteristic(UUID_JIELI_WRITE)
                        if (chr != null) {
                            chr.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    gatt.writeCharacteristic(chr, packet, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE)
                                } else {
                                    @Suppress("DEPRECATION")
                                    chr.value = packet
                                    @Suppress("DEPRECATION")
                                    gatt.writeCharacteristic(chr)
                                }
                            } catch (_: SecurityException) {}
                        }
                    }
                    gatt.disconnect()
                }
            }, BluetoothDevice.TRANSPORT_LE)
        } catch (_: Exception) {}
    }
}
