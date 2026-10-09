import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/device_setup_config.dart';
import '../models/local_device_info.dart';
import '../models/wifi_network.dart';
import '../models/wifi_provision_status.dart';

class WifiProvisioningException implements Exception {
  const WifiProvisioningException({required this.message, this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    if (code == null || code!.isEmpty) {
      return message;
    }

    return '$code: $message';
  }
}

class WifiSetupConnection {
  const WifiSetupConnection({required this.ssid, required this.gateway});

  final String ssid;
  final String gateway;
}

class WifiProvisioningService {
  WifiProvisioningService({
    this.channel = const MethodChannel(
      'com.yeningtechnology.yeningecos/device_setup',
    ),
  });

  static final WifiProvisioningService instance = WifiProvisioningService();

  final MethodChannel channel;

  Future<WifiSetupConnection> connectToSetupNetwork({
    required DeviceSetupConfig config,
  }) async {
    try {
      final result = await channel.invokeMethod<Map<Object?, Object?>>(
        'connectToSetupNetwork',
        {
          'ssidPrefix': config.setupSsidPrefix,
          'password': config.setupPassword,
          'gatewayFallback': config.gatewayFallback,
        },
      );

      if (result == null) {
        throw const WifiProvisioningException(
          message: 'Android did not return the setup network details.',
        );
      }

      final ssid = result['ssid'] as String? ?? '';

      final gateway = result['gateway'] as String? ?? '';

      if (ssid.isEmpty || gateway.isEmpty) {
        throw const WifiProvisioningException(
          message:
              'The setup Wi-Fi connection was established, '
              'but the device network information was incomplete.',
        );
      }

      return WifiSetupConnection(ssid: ssid, gateway: gateway);
    } on MissingPluginException {
      throw const WifiProvisioningException(
        code: 'UNSUPPORTED_PLATFORM',
        message: 'Device setup is available on Android 10 or newer.',
      );
    } on PlatformException catch (error) {
      throw WifiProvisioningException(
        code: error.code,
        message:
            error.message ?? 'Unable to connect to the device setup network.',
      );
    }
  }

  Future<void> disconnectFromSetupNetwork() async {
    try {
      await channel.invokeMethod<void>('disconnectFromSetupNetwork');
    } on MissingPluginException {
      // There is no setup network to release on unsupported platforms.
    } on PlatformException catch (error) {
      throw WifiProvisioningException(
        code: error.code,
        message:
            error.message ??
            'Unable to disconnect from the device setup network.',
      );
    }
  }

  Future<LocalDeviceInfo> getDeviceInfo() async {
    try {
      final raw = await channel.invokeMethod<String>('getDeviceInfo');

      if (raw == null || raw.isEmpty) {
        throw const WifiProvisioningException(
          message: 'The device returned an empty identity response.',
        );
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        throw const WifiProvisioningException(
          message: 'The device identity response is invalid.',
        );
      }

      final info = LocalDeviceInfo.fromJson(Map<String, dynamic>.from(decoded));

      if (!info.isValid) {
        throw const WifiProvisioningException(
          message: 'The device identity is incomplete.',
        );
      }

      return info;
    } on TypeError {
      throw const WifiProvisioningException(
        code: 'INVALID_DEVICE_RESPONSE',
        message: 'The device identity response contains invalid fields.',
      );
    } on FormatException {
      throw const WifiProvisioningException(
        message: 'The device returned malformed JSON.',
      );
    } on PlatformException catch (error) {
      throw WifiProvisioningException(
        code: error.code,
        message: error.message ?? 'Unable to read device information.',
      );
    }
  }

  Future<void> waitForInternet() async {
    try {
      await channel
          .invokeMethod<void>('waitForInternet')
          .timeout(const Duration(seconds: 22));
    } on TimeoutException {
      throw const WifiProvisioningException(
        code: 'PHONE_INTERNET_UNAVAILABLE',
        message: 'Connect your phone to your normal Wi-Fi or enable mobile data, then retry.',
      );
    } on PlatformException catch (error) {
      throw WifiProvisioningException(
        code: error.code,
        message:
            error.message ?? 'Your phone’s internet connection is unavailable.',
      );
    }
  }

  Future<List<WifiNetwork>> scanNetworks({
    required String expectedDeviceId,
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 25),
    Duration pollInterval = const Duration(milliseconds: 700),
  }) async {
    final timer = Stopwatch()..start();
    while (timer.elapsed < timeout) {
      if (isCancelled?.call() == true) {
        throw const WifiProvisioningException(
          code: 'WIFI_SETUP_CANCELLED',
          message: 'Device setup was closed.',
        );
      }
      try {
        final raw = await channel
            .invokeMethod<String>('scanNetworks')
            .timeout(timeout - timer.elapsed);
        if (isCancelled?.call() == true) {
          throw const WifiProvisioningException(
            code: 'WIFI_SETUP_CANCELLED',
            message: 'Device setup was closed.',
          );
        }
        final decoded = jsonDecode(raw ?? '');
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        if (decoded['deviceId'] is! String) throw const FormatException();
        if (decoded['deviceId'] != expectedDeviceId) {
          throw const WifiProvisioningException(
            code: 'DEVICE_IDENTITY_MISMATCH',
            message: 'A different device returned the network list. Start setup again.',
          );
        }
        if (decoded['status'] == 'complete') {
          final items = decoded['networks'];
          if (items is! List || items.length > 40) {
            throw const FormatException();
          }
          final strongest = <String, WifiNetwork>{};
          for (final item in items) {
            if (item is! Map<String, dynamic>) throw const FormatException();
            final network = WifiNetwork.fromJson(item);
            // Hidden networks require manual entry. Duplicate APs for a
            // single SSID are shown once, using the strongest signal.
            if (network.ssid.isEmpty) continue;
            final previous = strongest[network.ssid];
            if (previous == null || network.rssi > previous.rssi) {
              strongest[network.ssid] = network;
            }
          }
          return strongest.values.toList()..sort((a, b) {
            final signal = b.rssi.compareTo(a.rssi);
            return signal != 0 ? signal : a.ssid.compareTo(b.ssid);
          });
        }
        if (decoded['status'] != 'scanning') throw const FormatException();
      } on TimeoutException {
        break;
      } on MissingPluginException {
        throw const WifiProvisioningException(
          code: 'WIFI_SCAN_UNSUPPORTED',
          message: 'Nearby networks could not be loaded. Enter the Wi-Fi name.',
        );
      } on TypeError {
        throw const WifiProvisioningException(
          code: 'INVALID_DEVICE_RESPONSE',
          message: 'The device returned an invalid network list.',
        );
      } on FormatException {
        throw const WifiProvisioningException(
          code: 'INVALID_DEVICE_RESPONSE',
          message: 'The device returned an invalid network list.',
        );
      } on PlatformException catch (error) {
        // A scan temporarily visits other channels; short AP interruptions
        // can be retried while the device completes its asynchronous scan.
        if (error.code != 'DEVICE_HTTP_ERROR') {
          throw WifiProvisioningException(
            code: error.code,
            message: error.message ?? 'Nearby networks could not be loaded.',
          );
        }
      }
      final remaining = timeout - timer.elapsed;
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        pollInterval < remaining ? pollInterval : remaining,
      );
    }
    throw const WifiProvisioningException(
      code: 'WIFI_SCAN_TIMEOUT',
      message:
          'The Wi-Fi scan timed out. Scan again or enter the network name.',
    );
  }

  Future<void> provisionWifi({
    required String ssid,
    required String password,
  }) async {
    final validationError = validateSsid(ssid) ?? validatePassword(password);
    if (validationError != null) {
      throw WifiProvisioningException(message: validationError);
    }

    try {
      await channel.invokeMethod<String>('provisionWifi', {
        'ssid': ssid,
        'password': password,
      });
    } on PlatformException catch (error) {
      throw WifiProvisioningException(
        code: error.code,
        message:
            error.message ??
            'Unable to send the Wi-Fi configuration to the device.',
      );
    }
  }

  Future<WifiProvisionStatus> getProvisionStatus() async {
    try {
      final raw = await channel.invokeMethod<String>('getProvisionStatus');

      if (raw == null || raw.isEmpty) {
        throw const WifiProvisioningException(
          message: 'The device returned an empty provisioning status.',
        );
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        throw const WifiProvisioningException(
          message: 'The provisioning status response is invalid.',
        );
      }

      return WifiProvisionStatus.fromJson(Map<String, dynamic>.from(decoded));
    } on TypeError {
      throw const WifiProvisioningException(
        code: 'INVALID_DEVICE_RESPONSE',
        message: 'The device provisioning response contains invalid fields.',
      );
    } on FormatException {
      throw const WifiProvisioningException(
        message: 'The device returned malformed provisioning status JSON.',
      );
    } on PlatformException catch (error) {
      throw WifiProvisioningException(
        code: error.code,
        message: error.message ?? 'Unable to read device provisioning status.',
      );
    }
  }

  static String? validateSsid(String value) {
    if (value.isEmpty) return 'Enter your Wi-Fi network name.';
    if (utf8.encode(value).length > 32 || value.contains('\u0000')) {
      return 'Wi-Fi network names must be at most 32 UTF-8 bytes.';
    }
    return null;
  }

  static String? validatePassword(String value) {
    if (value.isEmpty || RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) {
      return null;
    }
    if (value.length < 8 ||
        value.length > 63 ||
        value.codeUnits.any((unit) => unit < 32 || unit > 126)) {
      return 'Use 8–63 ASCII characters, or leave blank for an open network.';
    }
    return null;
  }

  Future<WifiProvisionStatus> waitForProvisioning({
    required String expectedDeviceId,
    required String expectedSsid,
    required DeviceSetupConfig config,
    bool Function()? isCancelled,
  }) async {
    final timer = Stopwatch()..start();
    while (timer.elapsed < config.provisioningTimeout) {
      if (isCancelled?.call() == true) {
        throw const WifiProvisioningException(
          code: 'WIFI_SETUP_CANCELLED',
          message: 'Device setup was closed.',
        );
      }
      try {
        final status = await getProvisionStatus().timeout(
          config.provisioningTimeout - timer.elapsed,
        );
        if (isCancelled?.call() == true) {
          throw const WifiProvisioningException(
            code: 'WIFI_SETUP_CANCELLED',
            message: 'Device setup was closed.',
          );
        }
        if (status.deviceId.isNotEmpty && status.deviceId != expectedDeviceId) {
          throw const WifiProvisioningException(
            code: 'DEVICE_IDENTITY_MISMATCH',
            message: 'The connected device changed. Start setup again.',
          );
        }
        if (status.isFailed) {
          throw const WifiProvisioningException(
            code: 'WIFI_CONNECTION_FAILED',
            message: 'The device could not connect. Check the Wi-Fi name and password.',
          );
        }
        if (status.isConnected &&
            status.deviceId == expectedDeviceId &&
            status.ssid == expectedSsid &&
            status.ipAddress?.isNotEmpty == true &&
            status.ipAddress != '0.0.0.0') {
          return status;
        }
      } on TimeoutException {
        break;
      } on WifiProvisioningException catch (error) {
        // The ESP32 AP may briefly become unreachable when its radio changes
        // channel to join the router. Never interpret that loss as success.
        if (error.code != 'DEVICE_HTTP_ERROR' &&
            error.code != 'WIFI_SETUP_NOT_CONNECTED') {
          rethrow;
        }
      }
      final remaining = config.provisioningTimeout - timer.elapsed;
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        config.statusPollInterval < remaining
            ? config.statusPollInterval
            : remaining,
      );
    }
    throw const WifiProvisioningException(
      code: 'WIFI_CONFIRMATION_TIMEOUT',
      message:
          'Wi-Fi connection could not be confirmed. Check the network name '
          'and password and use a 2.4 GHz network. If the setup network has '
          'closed, restart the device before trying again.',
    );
  }
}
