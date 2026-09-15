package com.openhearables.open_hearables

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class RcspFrameTest {

    @Test
    fun `low latency on matches the documented wire format`() {
        val expected = byteArrayOf(
            0xFE.toByte(), 0xDC.toByte(), 0xBA.toByte(), // preamble
            0xC0.toByte(), 0xC0.toByte(),                // type/flags + opcode
            0x00, 0x04,                                  // payload length, big-endian
            0x01,                                        // sequence id
            0x02, 0x05,                                  // LTV length + ADV_TYPE_WORK_MODE
            0x01,                                        // low latency ON
            0xEF.toByte()                                // terminator
        )

        assertArrayEquals(expected, RcspFrame.lowLatencyCommand(true))
    }

    @Test
    fun `low latency off only flips the mode byte`() {
        val enabled = RcspFrame.lowLatencyCommand(true)
        val disabled = RcspFrame.lowLatencyCommand(false)

        assertEquals(RcspFrame.FRAME_LENGTH, enabled.size)
        assertEquals(RcspFrame.FRAME_LENGTH, disabled.size)
        assertEquals(RcspFrame.LOW_LATENCY_ON, enabled[RcspFrame.MODE_BYTE_INDEX])
        assertEquals(RcspFrame.LOW_LATENCY_OFF, disabled[RcspFrame.MODE_BYTE_INDEX])

        for (index in enabled.indices) {
            if (index == RcspFrame.MODE_BYTE_INDEX) continue
            assertEquals("byte $index must be identical", enabled[index], disabled[index])
        }
    }

    @Test
    fun `payload length field matches the declared payload size`() {
        val frame = RcspFrame.lowLatencyCommand(true)
        val declared = ((frame[5].toInt() and 0xFF) shl 8) or (frame[6].toInt() and 0xFF)

        assertEquals(RcspFrame.PAYLOAD_LENGTH, declared)
    }
}
