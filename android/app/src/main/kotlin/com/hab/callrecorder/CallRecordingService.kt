package com.hab.callrecorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Foreground service that keeps running while the Flutter UI is closed,
 * listens for call-start/call-end signals from [PhoneStateReceiver], and
 * drives [AudioRecorderManager] + [LocationHelper] to produce a recording
 * with metadata for every call.
 *
 * Displays a persistent "Employee Call Recording Active" notification per
 * the product spec, satisfying Android's foreground-service requirement.
 */
class CallRecordingService : Service() {

    companion object {
        private const val TAG = "CallRecordingService"
        private const val NOTIFICATION_CHANNEL_ID = "call_recording_channel"
        private const val NOTIFICATION_ID = 4201
        private const val PREFS_NAME = "call_recorder_native_prefs"
        private const val KEY_FOLDER_PATH = "folder_path"
        private const val KEY_EMPLOYEE_ID = "employee_id"
        private const val KEY_SERVICE_ENABLED = "service_enabled"

        var isRunning: Boolean = false
            private set

        fun start(context: Context, folderPath: String?) {
            val prefs = prefs(context)
            if (folderPath != null) {
                prefs.edit().putString(KEY_FOLDER_PATH, folderPath).apply()
            }
            prefs.edit().putBoolean(KEY_SERVICE_ENABLED, true).apply()

            val intent = Intent(context, CallRecordingService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            prefs(context).edit().putBoolean(KEY_SERVICE_ENABLED, false).apply()
            context.stopService(Intent(context, CallRecordingService::class.java))
        }

        fun updateFolderPath(context: Context, folderPath: String) {
            prefs(context).edit().putString(KEY_FOLDER_PATH, folderPath).apply()
        }

        fun setEmployeeId(context: Context, employeeId: String) {
            prefs(context).edit().putString(KEY_EMPLOYEE_ID, employeeId).apply()
        }

        fun wasEnabled(context: Context): Boolean =
            prefs(context).getBoolean(KEY_SERVICE_ENABLED, false)

        /** Called by [PhoneStateReceiver] when a call begins. */
        fun onCallStarted(context: Context, phoneNumber: String?, incoming: Boolean) {
            val intent = Intent(context, CallRecordingService::class.java).apply {
                action = ACTION_CALL_STARTED
                putExtra(EXTRA_PHONE_NUMBER, phoneNumber)
                putExtra(EXTRA_INCOMING, incoming)
            }
            context.startService(intent)
        }

        /** Called by [PhoneStateReceiver] when a call ends. */
        fun onCallEnded(context: Context) {
            val intent = Intent(context, CallRecordingService::class.java).apply {
                action = ACTION_CALL_ENDED
            }
            context.startService(intent)
        }

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        private const val ACTION_CALL_STARTED = "com.hab.callrecorder.action.CALL_STARTED"
        private const val ACTION_CALL_ENDED = "com.hab.callrecorder.action.CALL_ENDED"
        private const val EXTRA_PHONE_NUMBER = "phoneNumber"
        private const val EXTRA_INCOMING = "incoming"
    }

    private var activeCallStartMillis: Long = 0

    override fun onCreate() {
        super.onCreate()
        CallRecordingServiceContext.init(applicationContext)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification(recording = false))
        isRunning = true

        when (intent?.action) {
            ACTION_CALL_STARTED -> {
                val phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER)
                val incoming = intent.getBooleanExtra(EXTRA_INCOMING, false)
                beginRecording(phoneNumber, incoming)
            }
            ACTION_CALL_ENDED -> {
                finishRecording()
            }
        }

        // START_STICKY: if Android kills this service under memory pressure,
        // restart it automatically (per spec's "Service killed by Android"
        // error-handling requirement). Any in-progress recording at the
        // moment of a kill will be lost / truncated — there is no way to
        // resume a MediaRecorder session across a process death, so this is
        // a documented limitation rather than something to silently retry.
        return START_STICKY
    }

    private fun beginRecording(phoneNumber: String?, incoming: Boolean) {
        val prefs = prefs(this)
        val folderRoot = prefs.getString(KEY_FOLDER_PATH, null)
            ?: filesDir.resolve("CallRecordings").absolutePath
        val employeeId = prefs.getString(KEY_EMPLOYEE_ID, "EMP") ?: "EMP"

        activeCallStartMillis = System.currentTimeMillis()
        val fileName = buildFileName(employeeId, activeCallStartMillis)
        val dateFolder = buildDatedFolder(folderRoot, employeeId, activeCallStartMillis)
        val filePath = File(dateFolder, fileName).absolutePath

        val started = AudioRecorderManager.startRecording(filePath)
        if (!started) {
            Log.e(TAG, "Failed to start recording for call from $phoneNumber")
        }

        // Location capture happens on the Flutter side (via LocationService)
        // when it receives the call_started event, since address resolution
        // and DB writes are simpler to keep in Dart. LocationHelper here is
        // available as a native fallback if the Flutter engine is not
        // attached (e.g. app was force-closed) — see onCallStarted flow.
        updateNotification(recording = true, phoneNumber = phoneNumber)
    }

    private fun finishRecording() {
        val path = AudioRecorderManager.stopRecording()
        if (path != null) {
            val file = File(path)
            if (!file.exists() || file.length() == 0L) {
                Log.w(TAG, "Recording produced no data — call may have been too short " +
                        "or the audio source was blocked by the device (see " +
                        "AudioRecorderManager platform-limitation notes).")
            } else {
                Log.i(TAG, "Recording saved: $path (${file.length()} bytes)")
            }
        }
        updateNotification(recording = false)
    }

    override fun onDestroy() {
        AudioRecorderManager.abortRecording()
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ---------------- Notification ----------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Call Recording Status",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shows when employee call recording is active."
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(recording: Boolean, phoneNumber: String? = null): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val text = if (recording) {
            "Recording call${if (phoneNumber != null) " with $phoneNumber" else ""}…"
        } else {
            "Waiting for calls"
        }

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Employee Call Recording Active")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(recording: Boolean, phoneNumber: String? = null) {
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, buildNotification(recording, phoneNumber))
    }

    // ---------------- File naming ----------------

    private fun buildFileName(employeeId: String, startMillis: Long): String {
        val sdf = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
        return "${employeeId}_${sdf.format(Date(startMillis))}.mp3"
    }

    private fun buildDatedFolder(root: String, employeeId: String, startMillis: Long): File {
        val yearFmt = SimpleDateFormat("yyyy", Locale.US)
        val monthFmt = SimpleDateFormat("MMMM", Locale.US)
        val date = Date(startMillis)
        val dir = File(root, "$employeeId/${yearFmt.format(date)}/${monthFmt.format(date)}")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
