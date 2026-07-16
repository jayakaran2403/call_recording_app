package com.hab.callrecorder

import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import java.io.File
import java.io.IOException

/**
 * Wraps [MediaRecorder] for call audio capture.
 *
 * IMPORTANT PLATFORM LIMITATION — documented per project requirements:
 * Since Android 10 (API 29), Google restricted [MediaRecorder.AudioSource.VOICE_CALL]
 * to system/privileged apps only. Most OEM devices (Samsung, Xiaomi, Pixel, etc.)
 * silently block or mute call-audio capture for third-party apps on Android 10+,
 * even when RECORD_AUDIO is granted. This is a platform/OEM restriction, not a
 * bug in this app, and there is no universal workaround available to a
 * standard (non-system, non-rooted) app.
 *
 * Effective behavior by Android version, given current OEM policies:
 *  - Android 9 and below: VOICE_CALL source generally works on stock/AOSP-based
 *    builds; some OEM skins (e.g. Samsung One UI even at this era) already began
 *    restricting it.
 *  - Android 10+: VOICE_CALL is blocked on almost all consumer devices for
 *    third-party apps. This manager falls back to [MediaRecorder.AudioSource.MIC]
 *    or [MediaRecorder.AudioSource.VOICE_COMMUNICATION], which captures the
 *    device microphone (i.e. the employee's own side of the call reliably, and
 *    the other party's voice only if it is audible through the speaker,
 *    e.g. when speakerphone is on).
 *  - Device/carrier-level call recording announcements ("This call is being
 *    recorded") should be added at the product/legal level for jurisdictions
 *    that require two-party consent.
 *
 * Given this, recording quality of the remote party's audio cannot be
 * guaranteed uniformly across devices. This should be communicated to
 * employees and, where full dual-channel call recording is a hard
 * requirement, a telephony-integrated backend (SIP/VoIP recording via
 * HAB Dialer's server side) should be used instead of on-device capture.
 */
object AudioRecorderManager {

    private const val TAG = "AudioRecorderManager"

    private var recorder: MediaRecorder? = null
    var isRecording: Boolean = false
        private set

    var currentFilePath: String? = null
        private set

    /**
     * Starts recording to [filePath]. Ensures the parent directory exists.
     * Returns true if recording started successfully.
     */
    fun startRecording(filePath: String): Boolean {
        if (isRecording) {
            Log.w(TAG, "startRecording called while already recording — ignoring.")
            return false
        }

        val file = File(filePath)
        file.parentFile?.let { parent ->
            if (!parent.exists()) parent.mkdirs()
        }

        return try {
            val mr = createRecorder()
            configureAudioSource(mr)
            mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mr.setAudioEncodingBitRate(128000)
            mr.setAudioSamplingRate(44100)
            mr.setOutputFile(filePath)
            mr.prepare()
            mr.start()

            recorder = mr
            currentFilePath = filePath
            isRecording = true
            Log.i(TAG, "Recording started: $filePath")
            true
        } catch (e: IOException) {
            Log.e(TAG, "Failed to start recording (IOException): ${e.message}")
            releaseRecorder()
            false
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Failed to start recording (IllegalStateException): ${e.message}")
            releaseRecorder()
            false
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to start recording — permission denied: ${e.message}")
            releaseRecorder()
            false
        }
    }

    /**
     * Stops the active recording. Returns the file path that was recorded to,
     * or null if nothing was recording or the stop failed.
     */
    fun stopRecording(): String? {
        if (!isRecording) return null
        val path = currentFilePath
        try {
            recorder?.apply {
                stop()
                release()
            }
        } catch (e: RuntimeException) {
            // stop() can throw if start() succeeded but no valid audio data was
            // captured (e.g. call ended within the same instant it began).
            Log.e(TAG, "Error stopping recorder: ${e.message}")
            // The resulting file may be invalid/zero-length; caller should
            // verify file size before trusting it as a valid recording.
        } finally {
            recorder = null
            isRecording = false
        }
        return path
    }

    /** Emergency cleanup, e.g. when the service is being killed by the OS. */
    fun abortRecording() {
        if (!isRecording) return
        releaseRecorder()
    }

    private fun releaseRecorder() {
        try {
            recorder?.release()
        } catch (_: Exception) {
            // Ignore — recorder already in a bad state.
        }
        recorder = null
        isRecording = false
    }

    private fun createRecorder(): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(CallRecordingServiceContext.appContext)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
    }

    /**
     * Picks the best available audio source. Attempts VOICE_CALL first for
     * older/AOSP-based devices where it may still work, then falls back to
     * VOICE_COMMUNICATION, then plain MIC. See class doc for the platform
     * limitation this addresses.
     */
    private fun configureAudioSource(mr: MediaRecorder) {
        val sourcesToTry = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            intArrayOf(
                MediaRecorder.AudioSource.VOICE_CALL,
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.MIC,
            )
        } else {
            // On Android 10+, VOICE_CALL is not usable by third-party apps on
            // virtually all consumer devices — skip straight to the sources
            // that are actually permitted.
            intArrayOf(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.MIC,
            )
        }

        for (source in sourcesToTry) {
            try {
                mr.setAudioSource(source)
                Log.i(TAG, "Using audio source: $source")
                return
            } catch (e: Exception) {
                Log.w(TAG, "Audio source $source unavailable: ${e.message}")
            }
        }
        // Last resort — MIC should always be settable.
        mr.setAudioSource(MediaRecorder.AudioSource.MIC)
    }
}
