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
            'telemetry': {'temperature': 24, 'humidity': 50, 'light': 37.5},
          }),
        );
    await Future<void>.delayed(Duration.zero);
    expect(readings.last.temperatureCelsius, 24);
    expect(readings.last.lightPercent, 37.5);
    expect(readings.last.isCloudConnected, isTrue);
    database.feed('.info/connected').add(_Event(false));
    await Future<void>.delayed(Duration.zero);
    expect(readings.last.isCloudConnected, isFalse);
    expect(readings.last.lightPercent, 37.5);
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

  test('each two-second heartbeat is forwarded even when sensor values stay the same', () async {
    final database = _Database();
    final readings = <DeviceTelemetry>[];
    final subscription = DeviceTelemetryService(database: database)
        .watchDevice('device-1')
        .listen(readings.add);
    database.feed('.info/connected').add(_Event(true));
    const startedAt = 1700000000000;
    for (var tick = 0; tick < 3; tick++) {
      database
          .feed('deviceLive/device-1')
          .add(
            _Event({
              'telemetry': {'temperature': 24, 'humidity': 50, 'light': 37.5},
              'connectivity': {
                'isOnline': true,
                'lastSeen': startedAt + tick * 2000,
              },
            }),
          );
      await Future<void>.delayed(Duration.zero);
      expect(readings.length, tick + 1);
      expect(
        readings.last.lastSeen!.millisecondsSinceEpoch,
        startedAt + tick * 2000,
      );
      expect(readings.last.temperatureCelsius, 24);
      expect(readings.last.humidity, 50);
      expect(readings.last.lightPercent, 37.5);
      expect(readings.last.temperatureUpdatedAt, readings.last.lastSeen);
      expect(readings.last.humidityUpdatedAt, readings.last.lastSeen);
      expect(readings.last.lightUpdatedAt, readings.last.lastSeen);
    }
    expect(database.paths, ['.info/connected', 'deviceLive/device-1']);
    await subscription.cancel();
    for (final feed in database.events.values) {
      expect(feed.hasListener, isFalse);
      await feed.close();
    }
  });

  test('independent updates preserve sibling values and timestamps on every event', () async {
    final database = _Database();
    final readings = <DeviceTelemetry>[];
    final subscription = DeviceTelemetryService(database: database)
        .watchDevice('device-1')
        .listen(readings.add);
    database.feed('.info/connected').add(_Event(true));
    const startedAt = 1700000000000;
    final records = <String, Object>{
      'temperature': {'value': 24, 'updatedAt': startedAt},
      'humidity': {'value': 50, 'updatedAt': startedAt + 100},
      'light': {'value': 37.5, 'updatedAt': startedAt + 200},
    };
    void emit(int heartbeat) {
      database
          .feed('deviceLive/device-1')
          .add(
            _Event({
              'telemetry': Map<String, Object>.of(records),
              'connectivity': {'isOnline': true, 'lastSeen': heartbeat},
            }),
          );
    }

    emit(startedAt + 200);
    await Future<void>.delayed(Duration.zero);
    expect(readings, hasLength(1));

    records['light'] = {'value': 90, 'updatedAt': startedAt + 2200};
    emit(startedAt + 2200);
    await Future<void>.delayed(Duration.zero);
    expect(readings, hasLength(2));
    expect(readings.last.temperatureCelsius, 24);
    expect(readings.last.humidity, 50);
    expect(readings.last.lightPercent, 90);
    expect(
      readings.last.temperatureUpdatedAt!.millisecondsSinceEpoch,
      startedAt,
    );
    expect(
      readings.last.humidityUpdatedAt!.millisecondsSinceEpoch,
      startedAt + 100,
    );
    expect(
      readings.last.lightUpdatedAt!.millisecondsSinceEpoch,
      startedAt + 2200,
    );

    // An unchanged value is still a new sensor reading when its time advances.
    records['temperature'] = {'value': 24, 'updatedAt': startedAt + 4000};
    emit(startedAt + 4000);
    await Future<void>.delayed(Duration.zero);
    expect(readings, hasLength(3));
    expect(readings.last.temperatureCelsius, 24);
    expect(
      readings.last.temperatureUpdatedAt!.millisecondsSinceEpoch,
      startedAt + 4000,
    );
    expect(
      readings.last.humidityUpdatedAt!.millisecondsSinceEpoch,
      startedAt + 100,
    );
    expect(
      readings.last.lightUpdatedAt!.millisecondsSinceEpoch,
      startedAt + 2200,
    );

    // A connectivity-only update retains all independent sensor update times.
    database.feed('.info/connected').add(_Event(false));
    await Future<void>.delayed(Duration.zero);
    expect(readings.last.isCloudConnected, isFalse);
    expect(
      readings.last.temperatureUpdatedAt!.millisecondsSinceEpoch,
      startedAt + 4000,
    );
    expect(
      readings.last.humidityUpdatedAt!.millisecondsSinceEpoch,
      startedAt + 100,
    );
    expect(
      readings.last.lightUpdatedAt!.millisecondsSinceEpoch,
      startedAt + 2200,
    );
    expect(readings.last.lastSeen!.millisecondsSinceEpoch, startedAt + 4000);
    await subscription.cancel();
    for (final feed in database.events.values) {
      expect(feed.hasListener, isFalse);
      await feed.close();
    }
  });

  test(
    'heartbeat-only updates cannot renew a stale independent sensor',
    () async {
      final database = _Database();
      final readings = <DeviceTelemetry>[];
      final subscription = DeviceTelemetryService(database: database)
          .watchDevice('device-1')
          .listen(readings.add);
      database.feed('.info/connected').add(_Event(true));
      final now = DateTime.utc(2026, 10, 7, 12);
      final sensorTime = now.subtract(const Duration(seconds: 61));
      for (var tick = 0; tick < 2; tick++) {
        final heartbeat = now.add(Duration(seconds: tick * 2));
        database
            .feed('deviceLive/device-1')
            .add(
              _Event({
                'telemetry': {
                  'temperature': {
                    'value': 24,
                    'updatedAt': sensorTime.millisecondsSinceEpoch,
                  },
                  'humidity': {
                    'value': 50,
                    'updatedAt': heartbeat.millisecondsSinceEpoch,
                  },
                  'light': {
                    'value': 37.5,
                    'updatedAt': heartbeat.millisecondsSinceEpoch,
                  },
                },
                'connectivity': {
                  'isOnline': true,
                  'lastSeen': heartbeat.millisecondsSinceEpoch,
                },
              }),
            );
        await Future<void>.delayed(Duration.zero);
        expect(readings.last.isFreshAt(heartbeat), isTrue);
        expect(readings.last.isTemperatureFreshAt(heartbeat), isFalse);
        expect(readings.last.temperatureUpdatedAt, sensorTime);
        expect(readings.last.isHumidityFreshAt(heartbeat), isTrue);
        expect(readings.last.isLightFreshAt(heartbeat), isTrue);
      }
      await subscription.cancel();
      for (final feed in database.events.values) {
        await feed.close();
      }
    },
  );

  test(
    'mixed rollout light updates cannot freshen unchanged scalar siblings',
    () async {
      final database = _Database();
      final readings = <DeviceTelemetry>[];
      final subscription = DeviceTelemetryService(database: database)
          .watchDevice('device-1')
          .listen(readings.add);
      database.feed('.info/connected').add(_Event(true));
      final startedAt = DateTime.utc(2026, 10, 7, 12);
      for (var tick = 0; tick < 3; tick++) {
        final updatedAt = startedAt.add(Duration(seconds: tick * 2));
        database
            .feed('deviceLive/device-1')
            .add(
              _Event({
                'telemetry': {
                  'temperature': 24,
                  'humidity': 50,
                  'light': {
                    'value': 37.5 + tick,
                    'updatedAt': updatedAt.millisecondsSinceEpoch,
                  },
                },
                'connectivity': {
                  'isOnline': true,
                  'lastSeen': updatedAt.millisecondsSinceEpoch,
                },
              }),
            );
        await Future<void>.delayed(Duration.zero);
        expect(readings, hasLength(tick + 1));
        expect(readings.last.temperatureCelsius, 24);
        expect(readings.last.humidity, 50);
        expect(readings.last.temperatureUpdatedAt, isNull);
        expect(readings.last.humidityUpdatedAt, isNull);
        expect(readings.last.isTemperatureFreshAt(updatedAt), isFalse);
        expect(readings.last.isHumidityFreshAt(updatedAt), isFalse);
        expect(readings.last.lightUpdatedAt, updatedAt);
        expect(readings.last.isLightFreshAt(updatedAt), isTrue);
        expect(readings.last.isFreshAt(updatedAt), isTrue);
      }
      await subscription.cancel();
      for (final feed in database.events.values) {
        await feed.close();
      }
    },
  );
}
