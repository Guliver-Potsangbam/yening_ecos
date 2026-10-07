import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/devices/models/user_device.dart';
import 'package:yening_ecos/features/devices/services/user_devices_service.dart';

import 'support/firebase_fakes.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'loads owned registry devices even without an account-list entry',
    () async {
      final auth = TestAuth();
      final firestore = TestFirestore();
      final states = <UserDevicesState>[];
      final subscription = UserDevicesService(
        auth: auth,
        firestore: firestore,
      ).watchCurrentUserDevices().listen(states.add);
      auth.changes.add(TestUser('owner'));
      await flush();
      expect(states.single.isLoading, isTrue);
      expect(firestore.queries, ['owner']);
      firestore.emit('owner', {
        'device-b': {'deviceName': 'Bedroom'},
        'device-a': {'deviceName': 'Attic', 'serialNumber': 'SN-A'},
      });
      await flush();
      expect(states.last.devices.map((d) => d.deviceId), [
        'device-a',
        'device-b',
      ]);
      expect(states.last.devices.first.serialNumber, 'SN-A');
      firestore.emit('owner', {
        'device-a': {'deviceName': 'Attic'},
      });
      await flush();
      expect(
        states.last.devices.length,
        1,
        reason: 'registry changes update the list',
      );
      await subscription.cancel();
      expect(auth.changes.hasListener, isFalse);
      expect(firestore.feed('owner').hasListener, isFalse);
      await auth.changes.close();
      await firestore.feed('owner').close();
    },
  );

  test(
    'switches account listeners and clears prior devices on sign-out',
    () async {
      final auth = TestAuth();
      final firestore = TestFirestore();
      final states = <UserDevicesState>[];
      final errors = <Object>[];
      final subscription = UserDevicesService(
        auth: auth,
        firestore: firestore,
      ).watchCurrentUserDevices().listen(states.add, onError: errors.add);
      auth.changes.add(TestUser('first'));
      await flush();
      firestore.emit('first', {
        'first-device': {'deviceName': 'First'},
      });
      await flush();
      auth.changes.add(TestUser('second'));
      await flush();
      expect(states.last.isLoading, isTrue);
      expect(states.last.devices, isEmpty);
      expect(firestore.feed('first').hasListener, isFalse);
      firestore.emit('first', {
        'stale': {'deviceName': 'Stale'},
      });
      firestore.emit('second', {
        'second-device': {'deviceName': 'Second'},
      });
      await flush();
      expect(states.last.devices.single.deviceId, 'second-device');
      firestore.feed('second').addError(StateError('offline'));
      await flush();
      expect(errors, hasLength(1));
      auth.changes.add(null);
      await flush();
      expect(states.last.isLoading, isFalse);
      expect(states.last.devices, isEmpty);
      expect(firestore.feed('second').hasListener, isFalse);
      await subscription.cancel();
      await auth.changes.close();
      for (final feed in firestore.feeds.values) {
        await feed.close();
      }
    },
  );

  test(
    'signed-out accounts resolve to an empty list without querying Firestore',
    () async {
      final auth = TestAuth();
      final firestore = TestFirestore();
      final result = UserDevicesService(
        auth: auth,
        firestore: firestore,
      ).watchCurrentUserDevices().first;
      auth.changes.add(null);
      expect((await result).devices, isEmpty);
      expect(firestore.queries, isEmpty);
      await auth.changes.close();
    },
  );

  test(
    'device names fall back to the document ID and tolerate absent metadata',
    () {
      final device = UserDevice.fromMap('registry-id', {
        'deviceId': 'incorrect',
        'deviceName': 123,
      });
      expect(device.deviceId, 'registry-id');
      expect(device.deviceName, 'registry-id');
      expect(device.serialNumber, isEmpty);
    },
  );
}
