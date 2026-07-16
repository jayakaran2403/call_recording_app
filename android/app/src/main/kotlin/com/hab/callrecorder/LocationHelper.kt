package com.hab.callrecorder

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.util.Log
import androidx.core.app.ActivityCompat
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

data class NativeLocationResult(
    val latitude: Double,
    val longitude: Double,
    val address: String?,
)

/**
 * Captures a GPS fix and resolves it to a readable address using the
 * platform Geocoder. Used by [CallRecordingService] so location is tagged
 * even if the Flutter UI is not currently in the foreground.
 *
 * This runs synchronously with a short timeout since it's invoked from a
 * background service thread, not the main thread.
 */
object LocationHelper {

    private const val TAG = "LocationHelper"
    private const val FIX_TIMEOUT_SECONDS = 10L

    fun captureLocation(context: Context): NativeLocationResult? {
        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Location permission not granted — skipping GPS capture.")
            return null
        }

        val locationManager =
            context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                ?: return null

        val location = getCurrentFixBlocking(locationManager) ?: run {
            Log.w(TAG, "Unable to obtain a GPS fix in time.")
            return null
        }

        val address = try {
            reverseGeocode(context, location.latitude, location.longitude)
        } catch (e: Exception) {
            Log.w(TAG, "Geocoder unavailable: ${e.message}")
            null
        }

        return NativeLocationResult(location.latitude, location.longitude, address)
    }

    @Suppress("DEPRECATION")
    private fun getCurrentFixBlocking(manager: LocationManager): Location? {
        val provider = when {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> return null
        }

        // Fast path: use the last known location if it's recent enough.
        val last = try {
            manager.getLastKnownLocation(provider)
        } catch (e: SecurityException) {
            null
        }
        if (last != null && System.currentTimeMillis() - last.time < 60_000) {
            return last
        }

        val latch = CountDownLatch(1)
        var result: Location? = null

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val executor = Executors.newSingleThreadExecutor()
                manager.getCurrentLocation(
                    provider,
                    CancellationSignal(),
                    executor
                ) { location ->
                    result = location
                    latch.countDown()
                }
            } else {
                manager.requestSingleUpdate(provider, { location ->
                    result = location
                    latch.countDown()
                }, null)
            }
        } catch (e: SecurityException) {
            return null
        }

        latch.await(FIX_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        return result ?: last
    }

    private fun reverseGeocode(context: Context, lat: Double, lng: Double): String? {
        if (!Geocoder.isPresent()) return null
        val geocoder = Geocoder(context, Locale.getDefault())

        val addresses = try {
            @Suppress("DEPRECATION")
            geocoder.getFromLocation(lat, lng, 1)
        } catch (e: Exception) {
            null
        } ?: return null

        if (addresses.isEmpty()) return null
        val a = addresses[0]
        val parts = listOfNotNull(a.locality, a.adminArea).filter { it.isNotBlank() }
        return if (parts.isNotEmpty()) parts.joinToString(", ") else a.getAddressLine(0)
    }
}
