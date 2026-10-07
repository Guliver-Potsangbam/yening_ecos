package com.yeningtechnology.yeningecos

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PatternMatcher
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors

/** Owns one local-only network. Cloud SDKs continue using the default network. */
class WifiProvisioningManager(private val activity: Activity) {
    private class InvalidResponse : IOException()
    companion object {
        private const val PERMISSION_REQUEST = 4101
        private const val SETUP_GATEWAY = "192.168.4.1"
        private const val MAX_RESPONSE_CHARS = 16_384
    }
    private val connectivity = activity.getSystemService(ConnectivityManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var network: Network? = null
    private var pendingConnect: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var permissionConfig: Pair<String, String>? = null
    private var internetCallback: ConnectivityManager.NetworkCallback? = null
    private var pendingInternet: MethodChannel.Result? = null
    private var internetTimeout: Runnable? = null
    @Volatile private var session = 0
    @Volatile private var disposed = false
    @Volatile private var activeConnection: HttpURLConnection? = null

    private fun wifiPermission() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Manifest.permission.NEARBY_WIFI_DEVICES
        else Manifest.permission.ACCESS_FINE_LOCATION

    fun connectToSetupNetwork(ssidPrefix: String, password: String, gatewayFallback: String, result: MethodChannel.Result) {
        if (disposed) {
            result.error("WIFI_SETUP_CANCELLED", "Device setup was closed.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("UNSUPPORTED_ANDROID_VERSION", "Device setup requires Android 10 or newer.", null)
            return
        }
        if (ssidPrefix.isBlank() || gatewayFallback != SETUP_GATEWAY) {
            result.error("WIFI_CONFIGURATION_INVALID", "The setup network configuration is invalid.", null)
            return
        }
        if (pendingPermission != null || pendingConnect != null) {
            result.error("WIFI_SETUP_PENDING", "A device connection is already in progress.", null)
            return
        }
        if (!activity.getSystemService(WifiManager::class.java).isWifiEnabled) {
            result.error("WIFI_DISABLED", "Turn on Wi-Fi and try again.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU &&
            !activity.getSystemService(LocationManager::class.java).isLocationEnabled) {
            result.error("LOCATION_DISABLED", "Turn on Location to discover setup Wi-Fi on this Android version.", null)
            return
        }
        if (ContextCompat.checkSelfPermission(activity, wifiPermission()) != PackageManager.PERMISSION_GRANTED) {
            pendingPermission = result
            permissionConfig = ssidPrefix to password
            ActivityCompat.requestPermissions(activity, arrayOf(wifiPermission()), PERMISSION_REQUEST)
            return
        }
        startRequest(ssidPrefix, password, result)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        val result = pendingPermission ?: return
        val config = permissionConfig
        pendingPermission = null
        permissionConfig = null
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            result.error("WIFI_PERMISSION_DENIED", "Allow nearby Wi-Fi access in app settings, then try again.", null)
            return
        }
        if (config == null || disposed) {
            result.error("WIFI_SETUP_CANCELLED", "Device setup was closed.", null)
            return
        }
        startRequest(config.first, config.second, result)
    }

    private fun startRequest(ssidPrefix: String, password: String, result: MethodChannel.Result) {
        releaseNetwork()
        val requestSession = session
        pendingConnect = result
        try {
            val specifier = WifiNetworkSpecifier.Builder()
                .setSsidPattern(PatternMatcher(ssidPrefix, PatternMatcher.PATTERN_PREFIX))
                .apply { if (password.isNotEmpty()) setWpa2Passphrase(password) }
                .build()
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .setNetworkSpecifier(specifier).build()
            val requestCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(available: Network) {
                    if (disposed || session != requestSession) return
                    network = available
                    val info = connectivity.getNetworkCapabilities(available)?.transportInfo as? WifiInfo
                    val ssid = info?.ssid?.trim('"')?.takeUnless { it == WifiManager.UNKNOWN_SSID }
                    pendingConnect?.success(mapOf("ssid" to (ssid ?: ssidPrefix), "gateway" to SETUP_GATEWAY))
                    pendingConnect = null
                }
                override fun onUnavailable() {
                    if (session != requestSession) return
                    pendingConnect?.error("WIFI_SETUP_UNAVAILABLE",
                        "Could not join setup Wi-Fi. Power on the device, keep it nearby, and accept the Wi-Fi prompt.", null)
                    pendingConnect = null
                    releaseNetwork()
                }
                override fun onLost(lost: Network) {
                    if (session == requestSession && network == lost) {
                        network = null
                        activeConnection?.disconnect()
                    }
                }
            }
            callback = requestCallback
            // Serialize callbacks and MethodChannel replies on the main thread.
            connectivity.requestNetwork(request, requestCallback, main, 30_000)
        } catch (_: SecurityException) {
            failConnect("WIFI_PERMISSION_DENIED", "Android denied Wi-Fi access. Check app permissions.")
        } catch (_: IllegalArgumentException) {
            failConnect("WIFI_REQUEST_INVALID", "The device setup Wi-Fi configuration is invalid.")
        }
    }

    private fun failConnect(code: String, message: String) {
        pendingConnect?.error(code, message, null)
        pendingConnect = null
        releaseNetwork()
    }
    fun disconnectFromSetupNetwork(result: MethodChannel.Result) {
        releaseNetwork()
        result.success(null)
    }

    /** Releasing a local-only request does not mean default routing is ready. */
    fun waitForInternet(result: MethodChannel.Result) {
        if (disposed) {
            result.error("WIFI_SETUP_CANCELLED", "Device setup was closed.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("UNSUPPORTED_ANDROID_VERSION", "Device setup requires Android 10 or newer.", null)
            return
        }
        if (pendingInternet != null) {
            result.error("INTERNET_WAIT_PENDING", "Already waiting for your phone's internet connection.", null)
            return
        }
        pendingInternet = result
        val defaultCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(available: Network, capabilities: NetworkCapabilities) {
                if (internetCallback !== this) return
                if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) {
                    finishInternetWait()
                }
            }
        }
        internetCallback = defaultCallback
        val timeout = Runnable {
            finishInternetWait("PHONE_INTERNET_UNAVAILABLE",
                "Your phone has not returned to an internet connection. Connect it to your normal Wi-Fi or enable mobile data, then retry verification.")
        }
        internetTimeout = timeout
        try {
            connectivity.registerDefaultNetworkCallback(defaultCallback, main)
            main.postDelayed(timeout, 20_000)
        } catch (_: SecurityException) {
            finishInternetWait("INTERNET_CHECK_DENIED", "Android denied access to the phone's network status.")
        }
    }

    private fun finishInternetWait(code: String? = null, message: String? = null) {
        internetTimeout?.let { main.removeCallbacks(it) }
        internetTimeout = null
        internetCallback?.let {
            try { connectivity.unregisterNetworkCallback(it) }
            catch (_: IllegalArgumentException) { /* Already released. */ }
        }
        internetCallback = null
        val result = pendingInternet
        pendingInternet = null
        if (code == null) result?.success(null)
        else result?.error(code, message, null)
    }
    fun getDeviceInfo(result: MethodChannel.Result) = executeHttp("GET", "/api/device/info", null, result)
    fun getProvisionStatus(result: MethodChannel.Result) = executeHttp("GET", "/api/wifi/status", null, result)
    fun scanNetworks(result: MethodChannel.Result) = executeHttp("GET", "/api/wifi/networks", null, result)

    fun provisionWifi(ssid: String, password: String, result: MethodChannel.Result) {
        if (ssid.toByteArray(StandardCharsets.UTF_8).size !in 1..32 || ssid.contains('\u0000')) {
            result.error("WIFI_CONFIGURATION_INVALID", "Wi-Fi network name must be 1–32 UTF-8 bytes.", null)
            return
        }
        val validPassword = password.isEmpty() || password.matches(Regex("[0-9a-fA-F]{64}")) ||
            (password.length in 8..63 && password.all { it.code in 32..126 })
        if (!validPassword) {
            result.error("WIFI_CONFIGURATION_INVALID", "The Wi-Fi password is invalid.", null)
            return
        }
        val encodedSsid = URLEncoder.encode(ssid, StandardCharsets.UTF_8.name())
        val encodedPassword = URLEncoder.encode(password, StandardCharsets.UTF_8.name())
        executeHttp("POST", "/save", "ssid=$encodedSsid&password=$encodedPassword", result)
    }

    private fun executeHttp(method: String, path: String, body: String?, result: MethodChannel.Result) {
        val setupNetwork = network
        val requestSession = session
        if (setupNetwork == null || disposed) {
            result.error("WIFI_SETUP_NOT_CONNECTED", "The device setup network is not connected.", null)
            return
        }
        executor.execute {
            var connection: HttpURLConnection? = null
            try {
                if (session != requestSession || disposed) throw IOException("Cancelled")
                connection = setupNetwork.openConnection(URL("http://$SETUP_GATEWAY$path")) as HttpURLConnection
                activeConnection = connection
                connection.connectTimeout = 3_000
                connection.readTimeout = 3_000
                connection.requestMethod = method
                connection.useCaches = false
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("Accept", if (path == "/save") "text/html" else "application/json")
                if (body != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
                    connection.outputStream.use { it.write(body.toByteArray(StandardCharsets.UTF_8)) }
                }
                val status = connection.responseCode
                // Never return device error bodies: /save can echo submitted data.
                if (status !in 200..299) {
                    main.post {
                        val unsupportedScan = path == "/api/wifi/networks" && (status == 302 || status == 404)
                        result.error(
                            if (unsupportedScan) "WIFI_SCAN_UNSUPPORTED" else "DEVICE_HTTP_STATUS",
                            if (unsupportedScan) "Network scanning is not available on this device yet. Enter the Wi-Fi name."
                            else "Device returned HTTP $status. Check its firmware and retry.", null)
                    }
                } else {
                    if (path != "/save" &&
                        connection.contentType?.substringBefore(';')?.trim() != "application/json") {
                        throw InvalidResponse()
                    }
                    val response = connection.inputStream.bufferedReader(StandardCharsets.UTF_8).use {
                        val chars = CharArray(MAX_RESPONSE_CHARS + 1)
                        var length = 0
                        while (length < chars.size) {
                            val count = it.read(chars, length, chars.size - length)
                            if (count < 0) break
                            length += count
                        }
                        if (length > MAX_RESPONSE_CHARS) throw InvalidResponse()
                        String(chars, 0, length)
                    }
                    main.post {
                        if (session != requestSession || disposed) {
                            result.error("WIFI_SETUP_CANCELLED", "Device setup was closed.", null)
                        } else result.success(response)
                    }
                }
            } catch (error: Exception) {
                main.post {
                    val cancelled = session != requestSession || disposed
                    val invalid = error is InvalidResponse
                    result.error(
                        when {
                            cancelled -> "WIFI_SETUP_CANCELLED"
                            invalid -> "INVALID_DEVICE_RESPONSE"
                            else -> "DEVICE_HTTP_ERROR"
                        },
                        when {
                            cancelled -> "Device setup was closed."
                            invalid -> "The device returned an invalid API response. Check its firmware."
                            else -> "The device did not respond. Keep it nearby and retry."
                        }, null)
                }
            } finally {
                connection?.disconnect()
                if (activeConnection === connection) activeConnection = null
            }
        }
    }

    private fun releaseNetwork() {
        finishInternetWait("WIFI_SETUP_CANCELLED", "Device setup was closed.")
        session++
        pendingConnect?.error("WIFI_SETUP_CANCELLED", "Device connection was cancelled.", null)
        pendingConnect = null
        pendingPermission?.error("WIFI_SETUP_CANCELLED", "Device connection was cancelled.", null)
        pendingPermission = null
        permissionConfig = null
        callback?.let {
            try { connectivity.unregisterNetworkCallback(it) }
            catch (_: IllegalArgumentException) { /* Android already released it. */ }
        }
        callback = null
        network = null
        activeConnection?.disconnect()
        activeConnection = null
    }

    fun dispose() {
        disposed = true
        releaseNetwork()
        // Let queued calls settle their MethodChannel result as cancelled.
        executor.shutdown()
    }
}
