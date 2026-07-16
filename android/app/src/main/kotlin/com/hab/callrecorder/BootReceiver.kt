package com.hab.callrecorder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restores the call-recording foreground service after a device reboot,
 * but only if the employee had recording turned on before the restart
 * (per the "Phone reboot" error-handling requirement).
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        if (CallRecordingService.wasEnabled(context)) {
            Log.i("BootReceiver", "Recording was enabled before reboot — restarting service.")
            CallRecordingService.start(context, folderPath = null)
        }
    }
}
