import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/device_setup/device_setup_page.dart';
import 'package:yening_ecos/features/device_setup/models/device_setup_config.dart';
import 'package:yening_ecos/features/device_setup/models/local_device_info.dart';
import 'package:yening_ecos/features/device_setup/models/wifi_network.dart';
import 'package:yening_ecos/features/device_setup/models/wifi_provision_status.dart';
import 'package:yening_ecos/features/device_setup/services/device_type_service.dart';
import 'package:yening_ecos/features/device_setup/services/wifi_provisioning_service.dart';
import 'package:yening_ecos/features/devices/data/device_claim_service.dart';
import 'package:yening_ecos/features/devices/data/device_registry_service.dart';
import 'package:yening_ecos/features/devices/models/user_device.dart';

import '../devices/support/firebase_fakes.dart';

class _Wifi extends WifiProvisioningService {
  String identity = 'device-1';
  var sends = 0;
  var connections = 0;
  bool failConnection = false;
  @override
  Future<WifiSetupConnection> connectToSetupNetwork({
    required DeviceSetupConfig config,
  }) async {
    connections++;
    return const WifiSetupConnection(
      ssid: 'Yening-Eco-Setup',
      gateway: '192.168.4.1',
    );
  }

  @override
  Future<void> disconnectFromSetupNetwork() async {}
  @override
  Future<void> waitForInternet() async {}
  @override
  Future<LocalDeviceInfo> getDeviceInfo() async => LocalDeviceInfo(
    apiVersion: '1',
    deviceId: identity,
    deviceName: 'EnviroSense',
    serialNumber: '',
    deviceTypeId: 'model-1',
    provisioningStatus: 'waiting',
  );
  @override
  Future<List<WifiNetwork>> scanNetworks({
    required String expectedDeviceId,
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 25),
    Duration pollInterval = const Duration(milliseconds: 700),
  }) async => [];
  @override
  Future<void> provisionWifi({
    required String ssid,
    required String password,
  }) async {
    sends++;
  }

  @override
  Future<WifiProvisionStatus> waitForProvisioning({
    required String expectedDeviceId,
    required String expectedSsid,
    required DeviceSetupConfig config,
    bool Function()? isCancelled,
  }) async {
    if (failConnection) {
      throw const WifiProvisioningException(
        code: 'WIFI_CONNECTION_FAILED',
        message: 'The device could not connect.',
      );
    }
    return WifiProvisionStatus(
      status: 'connected',
      deviceId: identity,
      ssid: expectedSsid,
      ipAddress: '192.168.1.5',
    );
  }
}

class _Store extends TestFirestore {
  bool failNext = false;
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    if (failNext) {
      failNext = false;
      return Future.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
    }
    return super.runTransaction(
      handler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

void main() {
  const device = UserDevice(
    deviceId: 'device-1',
    deviceName: 'Grow room',
    serialNumber: 'SN-1',
    deviceTypeId: 'model-1',
  );
  late _Store store;
  late TestAuth auth;
  late _Wifi wifi;
  setUp(() {
    store = _Store();
    auth = TestAuth()..currentUser = TestUser('owner');
    wifi = _Wifi();
    store.records['devices/device-1'] = {
      'deviceId': 'device-1',
      'deviceName': 'EnviroSense',
      'serialNumber': 'SN-1',
      'deviceTypeId': 'model-1',
      'status': 'claimed',
      'claimedByUid': 'owner',
      'claimedAt': Timestamp.fromMillisecondsSinceEpoch(1234),
      'provisioningStatus': 'unprovisioned',
    };
    store.records['users/owner/devices/device-1'] = {
      'deviceId': 'device-1',
      'deviceName': 'Grow room',
    };
    store.records['deviceTypes/model-1'] = {
      'deviceTypeId': 'model-1',
      'deviceTypeName': 'EnviroSense',
      'status': 'active',
      'active': true,
    };
  });
  tearDown(() => auth.changes.close());
  Widget page({bool reconnect = true}) => MaterialApp(
    home: DeviceSetupPage(
      deviceToReconnect: reconnect ? device : null,
      wifiService: wifi,
      deviceTypeService: DeviceTypeService(firestore: store),
      deviceRegistryService: DeviceRegistryService(firestore: store),
      deviceClaimService: DeviceClaimService(auth: auth, firestore: store),
      currentUserUid: () => auth.currentUser?.uid,
    ),
  );
  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(page());
    expect(find.text('Keep your device nearby'), findsOneWidget);
    expect(wifi.connections, 0);
    await tester.tap(find.text('Connect to device'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, 'New Wi-Fi');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.ensureVisible(find.text('Connect Device'));
    await tester.tap(find.text('Connect Device'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first setup updates registry provisioning only after a confirmed connection',
    (tester) async {
      store.records['devices/device-1']!['status'] = 'unclaimed';
      store.records['devices/device-1']!.remove('claimedByUid');
      store.records.remove('users/owner/devices/device-1');
      await tester.pumpWidget(page(reconnect: false));
      await tester.pumpAndSettle();
      expect(
        store.records['devices/device-1']!['provisioningStatus'],
        'unprovisioned',
      );
      await submit(tester);
      expect(find.text('Device setup complete'), findsOneWidget);
      expect(
        store.records['devices/device-1']!['provisioningStatus'],
        'provisioned',
      );
      expect(store.records['devices/device-1']!['claimedByUid'], 'owner');
      expect(wifi.sends, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'owned erased-settings recovery keeps original claim and custom name',
    (tester) async {
      final original = store.records['devices/device-1']!['claimedAt'];
      // A discontinued model remains reconnectable by its owner.
      store.records['deviceTypes/model-1']!['active'] = false;
      await start(tester);
      await submit(tester);
      expect(find.text('Wi-Fi updated'), findsOneWidget);
      expect(
        store.records['devices/device-1']!['provisioningStatus'],
        'provisioned',
      );
      expect(store.records['devices/device-1']!['claimedAt'], original);
      expect(
        store.records['users/owner/devices/device-1']!['deviceName'],
        'Grow room',
      );
      expect(store.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('wrong nearby device receives no Wi-Fi credentials', (
    tester,
  ) async {
    wifi.identity = 'device-other';
    await start(tester);
    expect(find.textContaining('This is a different device.'), findsOneWidget);
    expect(wifi.sends, 0);
    expect(store.updates, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'ownership changed while entering credentials stops before sending them',
    (tester) async {
      await start(tester);
      store.records['devices/device-1']!['claimedByUid'] = 'other';
      await submit(tester);
      expect(find.textContaining('Only the current owner'), findsOneWidget);
      expect(wifi.sends, 0);
      expect(store.updates, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed Wi-Fi confirmation leaves registry provisioning unchanged',
    (tester) async {
      wifi.failConnection = true;
      await start(tester);
      await submit(tester);
      expect(find.text('The device could not connect.'), findsOneWidget);
      expect(
        store.records['devices/device-1']!['provisioningStatus'],
        'unprovisioned',
      );
      expect(store.updates, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('retrying cloud registration does not resend Wi-Fi credentials', (
    tester,
  ) async {
    await start(tester);
    store.failNext = true;
    await submit(tester);
    expect(find.text('Retry update'), findsOneWidget);
    expect(wifi.sends, 1);
    expect(
      store.records['devices/device-1']!['provisioningStatus'],
      'unprovisioned',
    );
    await tester.ensureVisible(find.text('Retry update'));
    await tester.tap(find.text('Retry update'));
    await tester.pumpAndSettle();
    expect(find.text('Wi-Fi updated'), findsOneWidget);
    expect(wifi.sends, 1);
    expect(
      store.records['devices/device-1']!['provisioningStatus'],
      'provisioned',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
