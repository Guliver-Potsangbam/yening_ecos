package com.yeningtechnology.yeningecos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "com.yeningtechnology.yeningecos/device_setup"
    }

    private val wifiProvisioningManager by lazy { WifiProvisioningManager(this) }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(
            flutterEngine,
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "connectToSetupNetwork" -> {
                    val ssidPrefix =
                        call.argument<String>(
                            "ssidPrefix",
                        )

                    val password =
                        call.argument<String>(
                            "password",
                        )

                    val gatewayFallback =
                        call.argument<String>(
                            "gatewayFallback",
                        )

                    if (
                        ssidPrefix.isNullOrBlank() ||
                        gatewayFallback.isNullOrBlank()
                    ) {
                        result.error(
                            "WIFI_CONFIGURATION_INVALID",
                            "SSID prefix and gateway fallback are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    wifiProvisioningManager
                        .connectToSetupNetwork(
                            ssidPrefix = ssidPrefix,
                            password = password.orEmpty(),
                            gatewayFallback =
                                gatewayFallback,
                            result = result,
                        )
                }

                "disconnectFromSetupNetwork" -> {
                    wifiProvisioningManager
                        .disconnectFromSetupNetwork(
                            result,
                        )
                }

                "getDeviceInfo" -> {
                    wifiProvisioningManager
                        .getDeviceInfo(
                            result,
                        )
                }

                "waitForInternet" -> {
                    wifiProvisioningManager.waitForInternet(result)
                }

                "scanNetworks" -> {
                    wifiProvisioningManager.scanNetworks(result)
                }

                "getProvisionStatus" -> {
                    wifiProvisioningManager
                        .getProvisionStatus(
                            result,
                        )
                }

                "provisionWifi" -> {
                    val ssid =
                        call.argument<String>(
                            "ssid",
                        )

                    val password =
                        call.argument<String>(
                            "password",
                        )

                    if (ssid.isNullOrEmpty()) {
                        result.error(
                            "WIFI_CONFIGURATION_INVALID",
                            "Wi-Fi SSID is required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    wifiProvisioningManager
                        .provisionWifi(
                            ssid = ssid,
                            password =
                                password.orEmpty(),
                            result = result,
                        )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults,
        )

        wifiProvisioningManager
            .onRequestPermissionsResult(
                requestCode,
                grantResults,
            )
    }

    override fun onDestroy() {
        wifiProvisioningManager.dispose()

        super.onDestroy()
    }
}
