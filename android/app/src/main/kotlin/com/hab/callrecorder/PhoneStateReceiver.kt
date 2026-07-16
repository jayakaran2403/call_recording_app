package com.hab.callrecorder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Listens for PHONE_STATE and NEW_OUTGOING_CALL broadcasts to detect call
 * start/end, then:
 *  1. Broadcasts a local intent so MainActivity's EventChannel can forward
 *     the event to Flutter for UI/metadata purposes.
 *  2. Tells [CallRecordingService] to start/stop native audio recording,
 *     which must happen regardless of whether the Flutter UI is alive.
 *
 * Call state transitions used:
 *   IDLE -> RINGING        : incoming call ringing (not yet answered)
 *   RINGING -> OFFHOOK     : incoming call answered -> call started
 *   IDLE -> OFFHOOK        : outgoing call dialed -> call started
 *   OFFHOOK/RINGING -> IDLE: call ended
 */
class PhoneStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneStateReceiver"
        const val ACTION_CALL_EVENT = "com.hab.callrecorder.CALL_EVENT"

        private var lastState = TelephonyManager.CALL_STATE_IDLE
        private var callStartTime = 0L
        private var isIncoming = false
        private var savedOutgoingNumber: String? = null
        private var savedIncomingNumber: String? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_NEW_OUTGOING_CALL -> {
                savedOutgoingNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
            }
            TelephonyManager.ACTION_PHONE_STATE_CHANGED -> {
                val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
                if (!incomingNumber.isNullOrEmpty()) {
                    savedIncomingNumber = incomingNumber
                }
                handleStateChange(context, stateStr)
            }
        }
    }

    private fun handleStateChange(context: Context, stateStr: String?) {
        val state = when (stateStr) {
            TelephonyManager.EXTRA_STATE_RINGING -> TelephonyManager.CALL_STATE_RINGING
            TelephonyManager.EXTRA_STATE_OFFHOOK -> TelephonyManager.CALL_STATE_OFFHOOK
            TelephonyManager.EXTRA_STATE_IDLE -> TelephonyManager.CALL_STATE_IDLE
            else -> return
        }

        if (state == lastState) return

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                isIncoming = true
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                // Call answered (incoming) or dialed (outgoing) -> starts now.
                if (lastState != TelephonyManager.CALL_STATE_RINGING) {
                    isIncoming = false
                }
                callStartTime = System.currentTimeMillis()
                val number = if (isIncoming) savedIncomingNumber else savedOutgoingNumber
                Log.i(TAG, "Call started. incoming=$isIncoming number=$number")

                CallRecordingService.onCallStarted(context, number, isIncoming)
                broadcastEvent(
                    context,
                    type = "call_started",
                    phoneNumber = number,
                    direction = if (isIncoming) "incoming" else "outgoing",
                    timestamp = callStartTime,
                )
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (lastState == TelephonyManager.CALL_STATE_OFFHOOK ||
                    lastState == TelephonyManager.CALL_STATE_RINGING
                ) {
                    val endTime = System.currentTimeMillis()
                    val number = if (isIncoming) savedIncomingNumber else savedOutgoingNumber
                    Log.i(TAG, "Call ended. incoming=$isIncoming number=$number")

                    CallRecordingService.onCallEnded(context)
                    broadcastEvent(
                        context,
                        type = "call_ended",
                        phoneNumber = number,
                        direction = if (isIncoming) "incoming" else "outgoing",
                        timestamp = endTime,
                    )
                }
                savedOutgoingNumber = null
                savedIncomingNumber = null
            }
        }

        lastState = state
    }

    private fun broadcastEvent(
        context: Context,
        type: String,
        phoneNumber: String?,
        direction: String,
        timestamp: Long,
    ) {
        val intent = Intent(ACTION_CALL_EVENT).apply {
            setPackage(context.packageName)
            putExtra("type", type)
            putExtra("phoneNumber", phoneNumber)
            putExtra("direction", direction)
            putExtra("timestamp", timestamp)
        }
        context.sendBroadcast(intent)
    }
}
