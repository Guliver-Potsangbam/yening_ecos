import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/devices/services/device_details_service.dart';

class _Documents {
  final feeds = <String, StreamController<Map<String, dynamic>?>>{};
  final watched = <String>[];

  StreamController<Map<String, dynamic>?> feed(String path) =>
      feeds.putIfAbsent(
        path,
        () => StreamController<Map<String, dynamic>?>.broadcast(),
      );

  Stream<Map<String, dynamic>?> watch(String collection, String id) {
    final path = '$collection/$id';
    watched.add(path);
    return feed(path).stream;
  }

  void emit(String path, Map<String, dynamic>? value) => feed(path).add(value);
  Future<void> close() async {
    for (final controller in feeds.values) {
      await controller.close();
    }
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

Map<String, dynamic> _device({
  String owner = 'owner-1',
  String type = 'model-1',
  String version = '1.0.0',
}) => {
  'deviceName': 'Living room',
  'claimedByUid': owner,
  'status': 'claimed',
  'deviceTypeId': type,
  'firmware': {'version': version},
};

void main() {
  late _Documents documents;
  late StreamController<String?> accounts;
  late List<DeviceDetailsState> states;
  late StreamSubscription<DeviceDetailsState> subscription;

  setUp(() {
    documents = _Documents();
    accounts = StreamController<String?>.broadcast();
    states = [];
    subscription = DeviceDetailsService(
      documentSource: documents.watch,
      accountChanges: accounts.stream,
    ).watchDevice('device-1').listen(states.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await accounts.close();
    await documents.close();
  });

  Future<void> openDevice() async {
    accounts.add('owner-1');
    await _flush();
    documents.emit('devices/device-1', _device());
    await _flush();
  }

  test(
    'publishes registry first then enriches it with live model specifications',
    () async {
      await openDevice();
      expect(states.first.isLoading, isTrue);
      expect(states.last.details?.device.deviceName, 'Living room');
      expect(states.last.typeLoading, isTrue);
      documents.emit('deviceTypes/model-1', {
        'description': 'Environmental monitoring.',
        'hardware': {'controller': 'ESP32'},
      });
      await _flush();
      expect(states.last.details?.description, 'Environmental monitoring.');
      expect(states.last.typeLoading, isFalse);
      documents.emit('devices/device-1', _device(version: '1.1.0'));
      await _flush();
      expect(states.last.details?.description, 'Environmental monitoring.');
      expect(documents.watched, ['devices/device-1', 'deviceTypes/model-1']);
      final version = states.last.details!.sections
          .expand((section) => section.fields)
          .firstWhere((field) => field.label == 'Installed version');
      expect(version.value, '1.1.0');
    },
  );

  test(
    'a model change clears old specifications and cancels the old listener',
    () async {
      await openDevice();
      documents.emit('deviceTypes/model-1', {'description': 'Old model.'});
      await _flush();
      documents.emit('devices/device-1', _device(type: 'model-2'));
      await _flush();
      expect(states.last.details?.description, isNull);
      expect(states.last.typeLoading, isTrue);
      expect(documents.feed('deviceTypes/model-1').hasListener, isFalse);
      documents.emit('deviceTypes/model-1', {'description': 'Late old event.'});
      documents.emit('deviceTypes/model-2', {'description': 'New model.'});
      await _flush();
      expect(states.last.details?.description, 'New model.');
    },
  );

  test('model failures preserve device metadata and expose a safe unavailable state', () async {
    await openDevice();
    documents.emit('deviceTypes/model-1', {
      'description': 'Old specifications.',
    });
    await _flush();
    documents
        .feed('deviceTypes/model-1')
        .addError(StateError('secret diagnostic'));
    await _flush();
    expect(states.last.details?.device.deviceName, 'Living room');
    expect(states.last.details?.description, isNull);
    expect(states.last.typeUnavailable, isTrue);
    expect(states.last.message, isNull);
    documents.emit('deviceTypes/model-1', {
      'description': 'Recovered specifications.',
    });
    await _flush();
    expect(states.last.details?.description, 'Recovered specifications.');
    expect(states.last.typeUnavailable, isFalse);
  });

  test(
    'missing or malformed model identifiers do not request invalid documents',
    () async {
      await openDevice();
      documents.emit('deviceTypes/model-1', null);
      await _flush();
      expect(states.last.typeUnavailable, isTrue);
      expect(states.last.details, isNotNull);
      documents.emit('devices/device-1', _device(type: 'invalid/model'));
      await _flush();
      expect(states.last.typeUnavailable, isTrue);
      expect(documents.watched, isNot(contains('deviceTypes/invalid/model')));
    },
  );

  test(
    'ownership removal clears all metadata and model subscriptions',
    () async {
      await openDevice();
      documents.emit('deviceTypes/model-1', {
        'description': 'Private model details.',
      });
      await _flush();
      documents.emit('devices/device-1', _device(owner: 'owner-2'));
      await _flush();
      expect(states.last.details, isNull);
      expect(documents.feed('deviceTypes/model-1').hasListener, isFalse);
      expect(states.last.message, contains('this account'));
    },
  );

  test('deleted and unclaimed records clear metadata even when the old owner matches', () async {
    await openDevice();
    for (final record in <Map<String, dynamic>?>[
      null,
      {..._device(), 'status': 'unclaimed'},
    ]) {
      documents.emit('devices/device-1', record);
      await _flush();
      expect(states.last.details, isNull);
      expect(documents.feed('deviceTypes/model-1').hasListener, isFalse);
      documents.emit('devices/device-1', _device());
      await _flush();
      expect(states.last.details, isNotNull);
    }
  });

  test(
    'sign-out and account switches cannot retain previous account metadata',
    () async {
      await openDevice();
      accounts.add(null);
      await _flush();
      expect(states.last.details, isNull);
      expect(documents.feed('devices/device-1').hasListener, isFalse);
      accounts.add('owner-2');
      await _flush();
      expect(states.last.isLoading, isTrue);
      documents.emit('devices/device-1', _device());
      await _flush();
      expect(states.last.details, isNull);
    },
  );

  test(
    'registry errors remove cached metadata without leaking diagnostic text',
    () async {
      await openDevice();
      documents
          .feed('devices/device-1')
          .addError(StateError('private uid and token'));
      await _flush();
      expect(states.last.details, isNull);
      expect(states.last.message, isNot(contains('private')));
      expect(documents.feed('deviceTypes/model-1').hasListener, isFalse);
    },
  );

  test('cancellation releases both registry and model listeners', () async {
    await openDevice();
    await subscription.cancel();
    expect(accounts.hasListener, isFalse);
    expect(documents.feed('devices/device-1').hasListener, isFalse);
    expect(documents.feed('deviceTypes/model-1').hasListener, isFalse);
  });
}
