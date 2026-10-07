import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/device_setup/services/wifi_provisioning_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/wifi_scan');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = WifiProvisioningService(channel: channel);
  final timeout = const Duration(milliseconds: 100);

  Future<dynamic> scan({bool Function()? cancelled}) => service.scanNetworks(
    expectedDeviceId: 'YEC-DEV-000001',
    timeout: timeout,
    pollInterval: const Duration(milliseconds: 1),
    isCancelled: cancelled,
  );

  Map<String, dynamic> network(
    String ssid,
    int rssi, {
    bool open = false,
    bool supported = true,
  }) => {
    'ssid': ssid,
    'rssi': rssi,
    'isOpen': open,
    'isSupported': supported,
    'security': open
        ? 'Open'
        : supported
        ? 'WPA2'
        : 'Enterprise',
  };
  String response(List<Map<String, dynamic>> networks) => jsonEncode({
    'deviceId': 'YEC-DEV-000001',
    'status': 'complete',
    'networks': networks,
  });
  Matcher errorCode(String code) => isA<WifiProvisioningException>().having(
    (error) => error.code,
    'code',
    code,
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'polls an asynchronous ESP32 scan and returns strongest networks first',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'scanNetworks');
        if (++calls == 1) {
          return '{"deviceId":"YEC-DEV-000001","status":"scanning"}';
        }
        return response([network('Weak', -85), network('Strong', -42)]);
      });
      final networks = await scan();
      expect(networks.map((network) => network.ssid), ['Strong', 'Weak']);
      expect(calls, 2);
    },
  );

  test('deduplicates APs by exact SSID and excludes hidden names', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => response([
        network('Home', -80),
        network('', -20),
        network('Home', -40),
        network(' Home ', -50),
        network('é "Home" \\', -60),
      ]),
    );
    final networks = await scan();
    expect(networks.map((network) => network.ssid), [
      'Home',
      ' Home ',
      'é "Home" \\',
    ]);
    expect(networks.first.rssi, -40);
  });

  test('preserves open and unsupported security metadata', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => response([
        network('Guest', -40, open: true),
        network('Office', -50, supported: false),
      ]),
    );
    final networks = await scan();
    expect(networks.first.isOpen, isTrue);
    expect(networks.last.isSupported, isFalse);
  });

  test('an empty scan is valid and permits manual entry', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => response([]));
    expect(await scan(), isEmpty);
  });

  test(
    'returns an unsupported error for the original captive portal',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'WIFI_SCAN_UNSUPPORTED');
      });
      await expectLater(scan(), throwsA(errorCode('WIFI_SCAN_UNSUPPORTED')));
    },
  );

  test('rejects scan results from a different board', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => '{"deviceId":"OTHER","status":"complete","networks":[]}',
    );
    await expectLater(scan(), throwsA(errorCode('DEVICE_IDENTITY_MISMATCH')));
  });

  test('rejects malformed network fields', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => response([
        {...network('Home', -40), 'rssi': 'strong'},
      ]),
    );
    await expectLater(scan(), throwsA(errorCode('INVALID_DEVICE_RESPONSE')));
  });

  test('rejects oversized SSIDs and response lists', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => response([network(List.filled(17, 'é').join(), -40)]),
    );
    await expectLater(scan(), throwsA(errorCode('INVALID_DEVICE_RESPONSE')));
    messenger.setMockMethodCallHandler(
      channel,
      (_) async =>
          response(List.generate(41, (index) => network('Home$index', -40))),
    );
    await expectLater(scan(), throwsA(errorCode('INVALID_DEVICE_RESPONSE')));
  });

  test('retries radio channel interruptions during scanning', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      if (++calls == 1) throw PlatformException(code: 'DEVICE_HTTP_ERROR');
      return response([network('Home', -40)]);
    });
    expect((await scan()).single.ssid, 'Home');
    expect(calls, 2);
  });

  test('bounds a hanging scan request', () async {
    final pending = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    await expectLater(scan(), throwsA(errorCode('WIFI_SCAN_TIMEOUT')));
    pending.complete(response([]));
  });

  test('stops polling when the setup page closes', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return '{"deviceId":"YEC-DEV-000001","status":"scanning"}';
    });
    await expectLater(
      scan(cancelled: () => calls > 0),
      throwsA(errorCode('WIFI_SETUP_CANCELLED')),
    );
    expect(calls, 1);
  });
}
