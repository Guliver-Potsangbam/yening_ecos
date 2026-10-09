import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_device.dart';

/// Customer-visible registry metadata. Only these known fields reach the UI;
/// account identifiers, authentication secrets and arbitrary maps are excluded.
class DeviceDetails {
  const DeviceDetails({
    required this.device,
    required this.sections,
    this.description,
  });

  final UserDevice device;
  final String? description;
  final List<DeviceMetadataSection> sections;

  factory DeviceDetails.fromMaps({
    required String documentId,
    required Map<String, dynamic> deviceData,
    Map<String, dynamic>? typeData,
  }) {
    final type = typeData ?? const <String, dynamic>{};
    final firmware = _map(deviceData['firmware']);
    final hardware = _map(type['hardware']);
    final compatibility = _map(type['firmwareCompatibility']);
    final lifecycle = _map(deviceData['lifecycle']);
    final typeLifecycle = _map(type['lifecycle']);
    final service = _map(deviceData['service']);
    final sections = <DeviceMetadataSection>[];

    void section(
      String id,
      String title,
      List<DeviceMetadataField> fields, {
      bool expanded = false,
    }) {
      final supplied = fields.where((field) => field.hasValue).toList();
      if (supplied.isNotEmpty) {
        sections.add(
          DeviceMetadataSection(
            id: id,
            title: title,
            fields: List.unmodifiable(supplied),
            initiallyExpanded: expanded,
          ),
        );
      }
    }

    section('overview', 'About this device', [
      DeviceMetadataField('Model', _text(type['deviceTypeName'])),
      DeviceMetadataField('Model version', _text(type['version'])),
      DeviceMetadataField('Device status', _humanText(deviceData['status'])),
      DeviceMetadataField(
        'Wi-Fi setup',
        _humanText(deviceData['provisioningStatus']),
      ),
      DeviceMetadataField('Availability', _enabled(deviceData['active'])),
      DeviceMetadataField('Model status', _humanText(type['status'])),
      DeviceMetadataField('Model availability', _enabled(type['active'])),
    ], expanded: true);

    section('firmware', 'Firmware', [
      DeviceMetadataField('Installed version', _text(firmware['version'])),
      DeviceMetadataField('Release channel', _humanText(firmware['channel'])),
      DeviceMetadataField.date(
        'Firmware updated',
        _date(firmware['updatedAt']),
      ),
      DeviceMetadataField(
        'Minimum supported version',
        _text(compatibility['minimumVersion']),
      ),
      DeviceMetadataField(
        'Recommended version',
        _text(compatibility['recommendedVersion']),
      ),
    ], expanded: false);

    section('hardware', 'Hardware & connectivity', [
      DeviceMetadataField('Controller', _text(hardware['controller'])),
      DeviceMetadataField('Board', _text(hardware['board'])),
      DeviceMetadataField(
        'Hardware revision',
        _text(hardware['hardwareRevision']),
      ),
      DeviceMetadataField(
        'Connectivity',
        _list(hardware['connectivity'], format: _connectivity),
      ),
    ]);

    final telemetry = _map(type['telemetry']);
    for (final key in const ['temperature', 'humidity', 'light']) {
      final metric = _map(telemetry[key]);
      final source = _map(metric['source']);
      if (metric.isEmpty) continue;
      final title = _text(metric['name']) ?? _humanText(key)!;
      section('sensor-$key', '$title capability', [
        DeviceMetadataField('Sensor', _sensor(_text(source['sensorType']))),
        DeviceMetadataField('Sensor ID', _text(source['sensorId'])),
        DeviceMetadataField('Interface', _humanText(source['interface'])),
        DeviceMetadataField(
          'Stored unit',
          _unit(_text(metric['canonicalUnit'])),
        ),
        DeviceMetadataField(
          'Display units',
          _list(metric['supportedUnits'], format: _unit),
        ),
        DeviceMetadataField(
          'Default unit',
          _unit(_text(metric['defaultUnit'])),
        ),
        DeviceMetadataField('Value type', _humanText(metric['dataType'])),
        DeviceMetadataField('Decimal places', _count(metric['decimalPlaces'])),
        DeviceMetadataField('Read only', _yesNo(metric['readOnly'])),
      ]);
    }

    final controls = _map(type['controls']);
    final controlKeys = controls.keys.toList()..sort();
    for (final key in controlKeys) {
      final control = _map(controls[key]);
      final name = _text(control['name']);
      // A named, typed definition is a capability, never an arbitrary payload.
      final controlType = _text(control['type']);
      if (name == null || controlType == null) continue;
      section('control-$key', '$name capability', [
        DeviceMetadataField('Control type', _humanText(controlType)),
        DeviceMetadataField('Availability', _enabled(control['active'])),
        DeviceMetadataField('State type', _humanText(control['stateDataType'])),
        DeviceMetadataField(
          'Supported modes',
          _list(control['supportedModes'], format: _humanText),
        ),
        DeviceMetadataField('Default mode', _humanText(control['defaultMode'])),
        DeviceMetadataField(
          'Default state',
          _relayState(control['defaultState']),
        ),
        DeviceMetadataField('Safe state', _relayState(control['safeState'])),
      ]);
    }

    section('lifecycle', 'Lifecycle & service', [
      DeviceMetadataField.date(
        'Manufactured',
        _date(lifecycle['manufacturedAt']),
      ),
      DeviceMetadataField.date(
        'Device released',
        _date(lifecycle['releasedAt']),
      ),
      DeviceMetadataField.date(
        'Model released',
        _date(typeLifecycle['releasedAt']),
      ),
      DeviceMetadataField.date(
        'Added to your account',
        _date(deviceData['claimedAt']),
      ),
      DeviceMetadataField.date(
        'Provisioned',
        _date(deviceData['provisionedAt']),
      ),
      DeviceMetadataField('Service visits', _count(service['serviceCount'])),
      DeviceMetadataField.date(
        'Last service',
        _date(service['lastServicedAt']),
      ),
      DeviceMetadataField.date(
        'Device registered',
        _date(deviceData['createdAt']),
      ),
      DeviceMetadataField.date(
        'Device record updated',
        _date(deviceData['updatedAt']),
      ),
      DeviceMetadataField.date(
        'Model record created',
        _date(type['createdAt']),
      ),
      DeviceMetadataField.date(
        'Model record updated',
        _date(type['updatedAt']),
      ),
    ]);

    section('reference', 'Device reference', [
      DeviceMetadataField('Device ID', documentId, copyable: true),
      DeviceMetadataField(
        'Serial number',
        _text(deviceData['serialNumber']),
        copyable: true,
      ),
      DeviceMetadataField('Model ID', _text(deviceData['deviceTypeId'])),
      DeviceMetadataField(
        'Device schema version',
        _count(deviceData['schemaVersion']),
      ),
      DeviceMetadataField(
        'Model schema version',
        _count(type['schemaVersion']),
      ),
    ]);

    return DeviceDetails(
      device: UserDevice.fromMap(documentId, deviceData),
      description: _text(type['description'], maximumLength: 4096),
      sections: List.unmodifiable(sections),
    );
  }
}

class DeviceMetadataSection {
  const DeviceMetadataSection({
    required this.id,
    required this.title,
    required this.fields,
    this.initiallyExpanded = false,
  });

  final String id;
  final String title;
  final List<DeviceMetadataField> fields;
  final bool initiallyExpanded;
}

class DeviceMetadataField {
  const DeviceMetadataField(this.label, this.value, {this.copyable = false})
    : timestamp = null;
  const DeviceMetadataField.date(this.label, this.timestamp)
    : value = null,
      copyable = false;

  final String label;
  final String? value;
  final DateTime? timestamp;
  final bool copyable;
  bool get hasValue => value != null || timestamp != null;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String? _text(Object? value, {int maximumLength = 256}) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty || text.length > maximumLength) return null;
  // Schema examples and unresolved placeholders are not installed hardware data.
  if (text.startsWith('<') && text.endsWith('>')) return null;
  return text;
}

String? _humanText(Object? value) {
  final text = _text(value);
  if (text == null) return null;
  final words = text.replaceAll(RegExp('[_-]+'), ' ');
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

String? _count(Object? value) => value is int && value >= 0 ? '$value' : null;
String? _enabled(Object? value) =>
    value is bool ? (value ? 'Enabled' : 'Disabled') : null;
String? _yesNo(Object? value) => value is bool ? (value ? 'Yes' : 'No') : null;
String? _relayState(Object? value) =>
    value is bool ? (value ? 'On' : 'Off') : null;

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  return null;
}

String? _list(Object? value, {required String? Function(String?) format}) {
  if (value is! List) return null;
  final items = value
      .map(_text)
      .whereType<String>()
      .map(format)
      .whereType<String>()
      .toSet();
  return items.isEmpty ? null : items.join(' · ');
}

String? _sensor(String? value) => switch (value?.toLowerCase()) {
  'dht22' => 'DHT22',
  'ldr' => 'LDR',
  _ => value,
};

String? _connectivity(String? value) => switch (value?.toLowerCase()) {
  'wifi' => 'Wi-Fi',
  'ble' => 'Bluetooth LE',
  'ethernet' => 'Ethernet',
  _ => _humanText(value),
};

String? _unit(String? value) => switch (value?.toLowerCase()) {
  'celsius' => 'Celsius (°C)',
  'fahrenheit' => 'Fahrenheit (°F)',
  'percent' => 'Percent (%)',
  _ => _humanText(value),
};
