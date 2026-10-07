import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/devices/models/device_details.dart';

void main() {
  test(
    'maps customer-visible device and model metadata without private fields',
    () {
      final details = DeviceDetails.fromMaps(
        documentId: 'device-1',
        deviceData: {
          'deviceId': 'untrusted-field-id',
          'deviceName': 'Living room',
          'serialNumber': 'SN-001',
          'deviceTypeId': 'model-1',
          'status': 'claimed',
          'provisioningStatus': 'provisioned',
          'active': true,
          'claimedByUid': 'private-owner-uid',
          'writerUid': 'private-writer-uid',
          'wifiPassword': 'private-password',
          'apiKey': 'private-api-key',
          'schemaVersion': 1,
          'firmware': {
            'version': '1.0.0',
            'channel': 'stable',
            'token': 'private-token',
          },
          'service': {'serviceCount': 0},
        },
        typeData: {
          'deviceTypeName': 'EnviroSense Basic',
          'version': '1.0.0',
          'description': 'Temperature, humidity and light monitoring.',
          'hardware': {
            'controller': 'ESP32',
            'board': 'ESP32 Dev Module',
            'hardwareRevision': 'Rev A',
            'connectivity': ['wifi'],
            'privateKey': 'private-hardware-key',
          },
          'firmwareCompatibility': {
            'minimumVersion': '1.0.0',
            'recommendedVersion': '1.1.0',
          },
          'telemetry': {
            'temperature': {
              'name': 'Temperature',
              'dataType': 'double',
              'source': {
                'sensorId': 'dht22_1',
                'sensorType': 'dht22',
                'interface': 'digital',
              },
              'canonicalUnit': 'celsius',
              'supportedUnits': ['celsius', 'fahrenheit'],
              'defaultUnit': 'celsius',
              'decimalPlaces': 1,
              'readOnly': true,
            },
          },
          'controls': {
            'relay1': {
              'name': 'Relay 1',
              'type': 'relay',
              'stateDataType': 'boolean',
              'supportedModes': ['manual', 'automation'],
              'defaultMode': 'manual',
              'defaultState': false,
              'safeState': false,
              'active': true,
              'token': 'private-control-token',
            },
          },
        },
      );
      expect(details.device.deviceId, 'device-1');
      expect(details.device.deviceName, 'Living room');
      final fields = details.sections
          .expand((section) => section.fields)
          .toList();
      final values = fields
          .map((field) => field.value)
          .whereType<String>()
          .join('|');
      expect(values, contains('ESP32 Dev Module'));
      expect(values, contains('Wi-Fi'));
      expect(values, contains('DHT22'));
      expect(values, contains('Celsius (°C) · Fahrenheit (°F)'));
      expect(values, contains('Manual · Automation'));
      expect(values, contains('Off'));
      expect(values, isNot(contains('private-')));
      expect(values, isNot(contains('untrusted-field-id')));
      expect(
        details.sections.map((section) => section.id),
        containsAll([
          'overview',
          'firmware',
          'hardware',
          'sensor-temperature',
          'control-relay1',
          'lifecycle',
          'reference',
        ]),
      );
    },
  );

  test('dates retain their instant and omit unresolved timestamps', () {
    final created = DateTime.utc(2026, 10, 7, 18, 30);
    final details = DeviceDetails.fromMaps(
      documentId: 'device-1',
      deviceData: {
        'createdAt': Timestamp.fromDate(created),
        'claimedAt': created,
        'updatedAt': '<Timestamp>',
        'lifecycle': {'manufacturedAt': Timestamp.fromDate(created)},
      },
    );
    final fields = details.sections
        .expand((section) => section.fields)
        .toList();
    expect(fields.where((field) => field.timestamp != null), hasLength(3));
    expect(
      fields
          .firstWhere((field) => field.label == 'Device registered')
          .timestamp,
      created,
    );
    expect(
      fields.where((field) => field.label == 'Device record updated'),
      isEmpty,
    );
  });

  test('malformed optional maps and types do not become invented metadata', () {
    final details = DeviceDetails.fromMaps(
      documentId: 'device-1',
      deviceData: {
        'deviceName': 42,
        'active': 'yes',
        'schemaVersion': -1,
        'firmware': ['wrong shape'],
        'lifecycle': {'manufacturedAt': false},
        'service': {'serviceCount': 1.5},
      },
      typeData: {
        'hardware': {
          'hardwareRevision': '<actual revision>',
          'connectivity': [false, 3, {}, 'wifi', 'wifi'],
        },
        'telemetry': {
          'temperature': false,
          'humidity': {'source': 99, 'readOnly': 'yes'},
        },
        'controls': {
          'relay1': {'name': 42, 'type': []},
        },
      },
    );
    expect(details.device.deviceName, 'device-1');
    expect(details.description, isNull);
    final fields = details.sections
        .expand((section) => section.fields)
        .toList();
    expect(fields.map((field) => field.value), ['Wi-Fi', 'device-1']);
    expect(fields.any((field) => field.timestamp != null), isFalse);
  });

  test(
    'a missing model still provides device identity and installed firmware',
    () {
      final details = DeviceDetails.fromMaps(
        documentId: 'device-1',
        deviceData: {
          'deviceName': 'Bedroom',
          'firmware': {'version': '1.0.0'},
        },
      );
      expect(details.device.deviceName, 'Bedroom');
      expect(details.sections.map((section) => section.id), [
        'firmware',
        'reference',
      ]);
      expect(
        details.sections.any((section) => section.id == 'hardware'),
        isFalse,
      );
    },
  );
}
