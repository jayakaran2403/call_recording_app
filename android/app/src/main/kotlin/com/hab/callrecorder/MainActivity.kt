package com.hab.callrecorder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Registers the three channels used to bridge Flutter and native Android:
 *  - SERVICE_CHANNEL:   start/stop the foreground service, query state
 *  - RECORDING_CHANNEL: query in-progress recording status
 *  - CALL_EVENT_CHANNEL: event stream of call start/end events, forwarded
 *    from PhoneStateReceiver via a local broadcast so Flutter can react
 *    (e.g. to update the "active recording" UI) even though native owns
 *    the actual recording lifecycle.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val SERVICE_CHANNEL = "com.hab.callrecorder/service"
        private const val RECORDING_CHANNEL = "com.hab.callrecorder/recording"
        private const val CALL_EVENT_CHANNEL = "com.hab.callrecorder/call_events"
    }

    private var eventSink: EventChannel.EventSink? = null

    private val callEventReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val map = HashMap<String, Any?>()
            map["type"] = intent.getStringExtra("type")
            map["phoneNumber"] = intent.getStringExtra("phoneNumber")
            map["direction"] = intent.getStringExtra("direction")
            map["timestamp"] = intent.getLongExtra("timestamp", System.currentTimeMillis())
            eventSink?.success(map)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val folderPath = call.argument<String>("folderPath")
                        CallRecordingService.start(applicationContext, folderPath)
                        result.success(true)
                    }
                    "stopService" -> {
                        CallRecordingService.stop(applicationContext)
                        result.success(true)
                    }
                    "isServiceRunning" -> {
                        result.success(CallRecordingService.isRunning)
                    }
                    "updateFolderPath" -> {
                        val folderPath = call.argument<String>("folderPath")
                        if (folderPath != null) {
                            CallRecordingService.updateFolderPath(applicationContext, folderPath)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRecording" -> result.success(AudioRecorderManager.isRecording)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    val filter = IntentFilter(PhoneStateReceiver.ACTION_CALL_EVENT)
                    registerReceiver(callEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    try {
                        unregisterReceiver(callEventReceiver)
                    } catch (_: IllegalArgumentException) {
                        // Already unregistered — safe to ignore.
                    }
                }
            })
    }
}
