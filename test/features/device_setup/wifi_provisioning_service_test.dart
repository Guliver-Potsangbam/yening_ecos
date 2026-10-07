import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/device_setup/models/device_setup_config.dart';
import 'package:yening_ecos/features/device_setup/services/wifi_provisioning_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/device_setup');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = WifiProvisioningService(channel: channel);
  const config = DeviceSetupConfig(
    setupSsidPrefix: 'Yening-Eco-Setup',
    setupPassword: '12345678',
    gatewayFallback: '192.168.4.1',
    provisioningTimeout: Duration(milliseconds: 100),
    statusPollInterval: Duration(milliseconds: 1),
  );

  Future<dynamic> wait({bool Function()? isCancelled}) =>
      service.waitForProvisioning(
        expectedDeviceId: 'YEC-DEV-000001',
        expectedSsid: 'Home',
        config: config,
        isCancelled: isCancelled,
      );

  Matcher errorCode(String code) => isA<WifiProvisioningException>().having(
    (error) => error.code,
    'code',
    code,
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('waits for the native default-network readiness check', () async {
    MethodCall? received;
    final ready = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) {
      received = call;
      return ready.future;
    });
    var completed = false;
    final waiting = service.waitForInternet().then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(received?.method, 'waitForInternet');
    expect(completed, isFalse);
    ready.complete();
    await waiting;
    expect(completed, isTrue);
  });

  test('surfaces phone internet recovery timeout without proceeding', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'PHONE_INTERNET_UNAVAILABLE',
        message: 'Connect your phone to your normal Wi-Fi.',
      );
    });
    await expectLater(
      service.waitForInternet(),
      throwsA(errorCode('PHONE_INTERNET_UNAVAILABLE')),
    );
  });

  test('reads the exact identity response from the attached sketch', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => jsonEncode({
        'deviceType': 'envirosense_basic_v1',
        'deviceId': 'YEC-DEV-000001',
        'apSsid': 'Yening-Eco-Setup',
        'apIp': '192.168.4.1',
      }),
    );
    final info = await service.getDeviceInfo();
    expect(info.isValid, isTrue);
    expect(info.deviceTypeId, 'envirosense_basic_v1');
    expect(info.serialNumber, isEmpty);
  });

  test('retains identity fields supplied by newer firmware', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => jsonEncode({
        'deviceTypeId': 'envirosense_basic_v1',
        'deviceId': 'YEC-DEV-000001',
        'apiVersion': '1',
        'deviceName': 'EnviroSense',
        'serialNumber': 'SERIAL-01',
      }),
    );
    final info = await service.getDeviceInfo();
    expect(info.isValid, isTrue);
    expect(info.serialNumber, 'SERIAL-01');
  });

  test(
    'rejects identity that could address a different registry path',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async =>
            '{"deviceId":"../other","deviceType":"envirosense_basic_v1"}',
      );
      await expectLater(
        service.getDeviceInfo(),
        throwsA(isA<WifiProvisioningException>()),
      );
    },
  );

  test('maps incorrectly typed identity to a useful error', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => '{"deviceId":42,"deviceType":"envirosense_basic_v1"}',
    );
    await expectLater(
      service.getDeviceInfo(),
      throwsA(errorCode('INVALID_DEVICE_RESPONSE')),
    );
  });

  test(
    'passes SSID spaces and password characters without modifying them',
    () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return '<html>Wi-Fi Saved</html>';
      });
      await service.provisionWifi(ssid: ' Home ', password: 'p&ss+word');
      expect(received?.method, 'provisionWifi');
      expect(received?.arguments, {'ssid': ' Home ', 'password': 'p&ss+word'});
    },
  );

  test('validates SSID UTF-8 bytes and WPA credentials', () {
    expect(
      WifiProvisioningService.validateSsid(List.filled(16, 'é').join()),
      isNull,
    );
    expect(
      WifiProvisioningService.validateSsid(List.filled(17, 'é').join()),
      isNotNull,
    );
    expect(WifiProvisioningService.validateSsid(''), isNotNull);
    expect(WifiProvisioningService.validatePassword(''), isNull);
    expect(WifiProvisioningService.validatePassword('short'), isNotNull);
    expect(WifiProvisioningService.validatePassword('password'), isNull);
    expect(
      WifiProvisioningService.validatePassword(List.filled(64, 'a').join()),
      isNull,
    );
    expect(
      WifiProvisioningService.validatePassword(List.filled(64, 'z').join()),
      isNotNull,
    );
  });

  test('accepts a confirmed connection from the legacy status API', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => '{"connected":true,"ssid":"Home","ip":"192.168.1.20","apIp":"192.168.4.1"}',
    );
    final status = await wait();
    expect(status.isConnected, isTrue);
    expect(status.ipAddress, '192.168.1.20');
  });

  test(
    'retries transport interruption while the ESP32 changes radio channel',
    () async {
      var count = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        if (++count == 1) throw PlatformException(code: 'DEVICE_HTTP_ERROR');
        return '{"connected":true,"ssid":"Home","ip":"192.168.1.20"}';
      });
      expect((await wait()).isConnected, isTrue);
      expect(count, 2);
    },
  );

  test('fails immediately for an explicit firmware failure', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => '{"status":"failed","deviceId":"YEC-DEV-000001"}',
    );
    await expectLater(wait(), throwsA(errorCode('WIFI_CONNECTION_FAILED')));
  });

  test('fails immediately for a different device identity', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => '{"status":"connected","deviceId":"OTHER","ssid":"Home","ip":"192.168.1.20"}',
    );
    await expectLater(wait(), throwsA(errorCode('DEVICE_IDENTITY_MISMATCH')));
  });

  test('does not silently retry an incompatible endpoint', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'DEVICE_HTTP_STATUS', message: 'HTTP 302');
    });
    await expectLater(wait(), throwsA(errorCode('DEVICE_HTTP_STATUS')));
  });

  test('does not turn a malformed status response into success', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => '{"connected":"true"}',
    );
    await expectLater(wait(), throwsA(isA<WifiProvisioningException>()));
  });

  test('times out instead of accepting an old Wi-Fi connection', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => '{"connected":true,"ssid":"OldHome","ip":"192.168.1.20"}',
    );
    await expectLater(wait(), throwsA(errorCode('WIFI_CONFIRMATION_TIMEOUT')));
  });

  test('a closed portal does not count as success', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'WIFI_SETUP_NOT_CONNECTED');
    });
    await expectLater(wait(), throwsA(errorCode('WIFI_CONFIRMATION_TIMEOUT')));
  });

  test('stops polling after cancellation', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return '{"connected":false,"ssid":"Home","ip":""}';
    });
    await expectLater(
      wait(isCancelled: () => calls > 0),
      throwsA(errorCode('WIFI_SETUP_CANCELLED')),
    );
    expect(calls, 1);
  });

  test(
    'a request that never replies is bounded by the overall timeout',
    () async {
      final pending = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (_) => pending.future);
      await expectLater(
        wait(),
        throwsA(errorCode('WIFI_CONFIRMATION_TIMEOUT')),
      );
      pending.complete('{"connected":false}');
    },
  );

  test('does not accept success after cancellation during a request', () async {
    var cancelled = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      cancelled = true;
      return '{"connected":true,"ssid":"Home","ip":"192.168.1.20"}';
    });
    await expectLater(
      wait(isCancelled: () => cancelled),
      throwsA(errorCode('WIFI_SETUP_CANCELLED')),
    );
  });
}
