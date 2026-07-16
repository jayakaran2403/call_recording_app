package com.hab.callrecorder

import android.content.Context

/**
 * Lightweight holder for the application [Context], set once from
 * [CallRecordingApplication] (or the Service's onCreate) so components like
 * [AudioRecorderManager] can access a Context without needing it passed
 * through every call — required for the Context-based MediaRecorder
 * constructor introduced in Android 12 (API 31).
 */
object CallRecordingServiceContext {
    lateinit var appContext: Context
        private set

    fun init(context: Context) {
        if (!::appContext.isInitialized) {
            appContext = context.applicationContext
        }
    }
}
