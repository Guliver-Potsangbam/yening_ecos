import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/devices/models/device_telemetry.dart';
import 'package:yening_ecos/features/devices/services/device_telemetry_service.dart';

class _Database implements FirebaseDatabase {
  final paths = <String>[];
  final events = <String, StreamController<DatabaseEvent>>{};
  StreamController<DatabaseEvent> feed(String path) =>
      events.putIfAbsent(path, () => StreamController.broadcast());
  @override
  DatabaseReference ref([String? path]) {
    paths.add(path!);
    return _Reference(feed(path).stream);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DatabaseReference {
  _Reference(this.onValue);
  @override
  final Stream<DatabaseEvent> onValue;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Event implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('streams only the selected device, reacts to disconnects and releases listeners', () async {
    final database = _Database();
    final readings = <DeviceTelemetry>[];
    final errors = <Object>[];
    final subscription = DeviceTelemetryService(database: database)
        .watchDevice('device-1')
        .listen(readings.add, onError: errors.add);
    expect(database.paths, ['.info/connected', 'deviceLive/device-1']);
    database.feed('.info/connected').add(_Event(true));
    database
        .feed('deviceLive/device-1')
        .add(
          _Event({
            'telemetry': {'temperature': 24, 'humidity': 50},
          }),
        );
    await Future<void>.delayed(Duration.zero);
    expect(readings.last.temperatureCelsius, 24);
    expect(readings.last.isCloudConnected, isTrue);
    database.feed('.info/connected').add(_Event(false));
    await Future<void>.delayed(Duration.zero);
    expect(readings.last.isCloudConnected, isFalse);
    expect(
      readings.last.temperatureCelsius,
      24,
      reason: 'retain the last reading when disconnected',
    );
    database
        .feed('deviceLive/device-1')
        .addError(StateError('permission denied'));
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    await subscription.cancel();
    for (final feed in database.events.values) {
      expect(feed.hasListener, isFalse);
      await feed.close();
    }
  });

  test(
    'rejects invalid identities before creating a database subscription',
    () {
      final database = _Database();
      expect(
        () =>
            DeviceTelemetryService(database: database).watchDevice('../other'),
        throwsArgumentError,
      );
      expect(database.paths, isEmpty);
    },
  );
}
