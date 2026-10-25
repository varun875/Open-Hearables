package com.openhearables.open_hearables

/**
 * Pure JieLi RCSP frame construction.
 *
 * Deliberately free of Android and Flutter types so the wire format can be
 * pinned by plain JVM unit tests.
 *
 * The app sends exactly one frame layout — the 12-byte `SET_ADV_INFO` command
 * reconstructed from the decompiled `TwsOpImpl` / `CommandBuilder`:
 *
 * ```
 * [0xFE, 0xDC, 0xBA]   preamble
 * [0xC0, 0xC0]         type/flags (command + response) and opcode (SET_ADV_INFO)
 * [0x00, 0x04]         payload length, big-endian
 * [0x01]               sequence id
 * [0x02, 0x05, mode]   LTV: length, ADV_TYPE_WORK_MODE, 0x02 gaming/beast / 0x01 normal
 * [0xEF]               terminator
 * ```
 *
 * A second, incompatible "generic frame" builder (`0xBA 0xDC` preamble plus a
 * CRC16 trailer) used to live alongside this one. It was never wired up from
 * Dart and disagreed with the frame above, so it was removed rather than left
 * as unverifiable protocol code.
 */
object RcspFrame {
    const val PREAMBLE_0: Byte = 0xFE.toByte()
    const val PREAMBLE_1: Byte = 0xDC.toByte()
    const val PREAMBLE_2: Byte = 0xBA.toByte()
    const val TYPE_COMMAND_WITH_RESPONSE: Byte = 0xC0.toByte()
    const val OPCODE_SET_ADV_INFO: Byte = 0xC0.toByte()
    const val TERMINATOR: Byte = 0xEF.toByte()

    const val SEQUENCE_ID: Byte = 0x01
    const val LTV_LENGTH: Byte = 0x02
    const val ADV_TYPE_WORK_MODE: Byte = 0x05
    const val LOW_LATENCY_ON: Byte = 0x02
    const val LOW_LATENCY_OFF: Byte = 0x01

    /** Sequence id plus the LTV triple. */
    const val PAYLOAD_LENGTH: Int = 4

    /** Full frame size. */
    const val FRAME_LENGTH: Int = 12

    /** Index of the mode byte, the only byte that changes between on and off. */
    const val MODE_BYTE_INDEX: Int = 10

    /**
     * Builds the `SET_ADV_INFO` frame that switches the earbuds between the
     * standard music buffer and the reduced low-latency buffer.
     */
    fun lowLatencyCommand(enable: Boolean): ByteArray {
        return byteArrayOf(
            PREAMBLE_0,
            PREAMBLE_1,
            PREAMBLE_2,
            TYPE_COMMAND_WITH_RESPONSE,
            OPCODE_SET_ADV_INFO,
            (PAYLOAD_LENGTH shr 8).toByte(),
            PAYLOAD_LENGTH.toByte(),
            SEQUENCE_ID,
            LTV_LENGTH,
            ADV_TYPE_WORK_MODE,
            if (enable) LOW_LATENCY_ON else LOW_LATENCY_OFF,
            TERMINATOR
        )
    }
}
