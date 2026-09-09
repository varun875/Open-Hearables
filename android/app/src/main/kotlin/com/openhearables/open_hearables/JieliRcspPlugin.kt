package com.openhearables.open_hearables

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream

class JieliRcspPlugin : MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.openhearables.app/rcsp"

        // JieLi RCSP Frame Constants
        const val RCSP_MAGIC_0: Byte = 0xBA.toByte()
        const val RCSP_MAGIC_1: Byte = 0xDC.toByte()

        // RCSP Command IDs
        const val CMD_GET_DEV_INFO: Byte = 0x01
        const val CMD_SET_LOW_LATENCY: Byte = 0x0C
        const val CMD_SET_EQ_PRESET: Byte = 0x05
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "buildLowLatencyPacket" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val packet = buildLowLatencyCommand(enabled)
                result.success(packet)
            }
            "buildGetDeviceInfoPacket" -> {
                val packet = buildGetDeviceInfoCommand()
                result.success(packet)
            }
            "parseRcspBattery" -> {
                val data = call.argument<ByteArray>("data")
                if (data != null) {
                    val batteryInfo = parseBatteryResponse(data)
                    result.success(batteryInfo)
                } else {
                    result.error("NULL_DATA", "Data array was null", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Builds an authentic JieLi RCSP packet for toggling Low Latency (Beast Mode)
     * Format per decompiled TwsOpImpl / ParseHelper / CommandBuilder:
     * Header: [0xFE, 0xDC, 0xBA]
     * Type/Flags: 0xC0 (Command with Response)
     * OpCode: 0xC0 (CMD_SET_ADV_INFO)
     * Length: [0x00, 0x04]
     * Seq: 0x01
     * LTV: [0x02, 0x05 (ADV_TYPE_WORK_MODE), 0x01/0x00]
     * Tail: 0xEF
     */
    fun buildLowLatencyCommand(enable: Boolean): ByteArray {
        val modeVal: Byte = if (enable) 0x01 else 0x00
        return byteArrayOf(
            0xFE.toByte(), 0xDC.toByte(), 0xBA.toByte(),
            0xC0.toByte(), 0xC0.toByte(),
            0x00, 0x04,
            0x01,
            0x02, 0x05, modeVal,
            0xEF.toByte()
        )
    }

    /**
     * Builds an RCSP packet to query device info and battery status
     */
    fun buildGetDeviceInfoCommand(): ByteArray {
        val payload = byteArrayOf(0x00) // Query all basic attributes
        return packFrame(CMD_GET_DEV_INFO, payload)
    }

    private fun packFrame(commandId: Byte, payload: ByteArray): ByteArray {
        val baos = ByteArrayOutputStream()
        baos.write(RCSP_MAGIC_0.toInt())
        baos.write(RCSP_MAGIC_1.toInt())

        val dataLength = 1 + payload.size // Cmd ID + payload
        baos.write((dataLength shr 8) and 0xFF)
        baos.write(dataLength and 0xFF)

        baos.write(commandId.toInt())
        baos.write(payload)

        val crc = calculateCrc16(payload)
        baos.write((crc shr 8) and 0xFF)
        baos.write(crc and 0xFF)

        return baos.toByteArray()
    }

    private fun calculateCrc16(bytes: ByteArray): Int {
        var crc = 0xFFFF
        for (b in bytes) {
            crc = crc xor (b.toInt() and 0xFF)
            for (i in 0 until 8) {
                crc = if ((crc and 1) != 0) {
                    (crc ushr 1) xor 0xA001
                } else {
                    crc ushr 1
                }
            }
        }
        return crc and 0xFFFF
    }

    /**
     * Extracts Left/Right earbud and case battery levels from an RCSP info response
     */
    fun parseBatteryResponse(data: ByteArray): Map<String, Any> {
        // Typical JieLi response payload: [Left %, Right %, Case %]
        if (data.size < 5) {
            return mapOf("left" to -1, "right" to -1, "case" to -1)
        }

        // Offset search for battery bytes after magic headers
        var offset = 4
        val left = if (offset < data.size) (data[offset++].toInt() and 0x7F) else -1
        val right = if (offset < data.size) (data[offset++].toInt() and 0x7F) else -1
        val chargingCase = if (offset < data.size) (data[offset].toInt() and 0x7F) else -1

        return mapOf(
            "left" to left.coerceIn(0, 100),
            "right" to right.coerceIn(0, 100),
            "case" to chargingCase.coerceIn(0, 100)
        )
    }
}
