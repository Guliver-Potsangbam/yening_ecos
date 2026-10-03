import 'package:flutter/material.dart';

enum SensorStatus { normal, good, optimal, warning, critical }

enum ControlType { switchControl, button }

class SensorDefinition {
  const SensorDefinition({
    required this.id,
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.trend,
    required this.icon,
  });

  final String id;
  final String name;
  final String value;
  final String unit;
  final SensorStatus status;
  final String trend;
  final IconData icon;
}

class ControlDefinition {
  const ControlDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.type = ControlType.switchControl,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final ControlType type;
}

class DeviceVariant {
  const DeviceVariant({
    required this.id,
    required this.name,
    required this.description,
    required this.sensors,
    required this.controls,
  });

  final String id;
  final String name;
  final String description;
  final List<SensorDefinition> sensors;
  final List<ControlDefinition> controls;
}

class DeviceDefinition {
  const DeviceDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.variants,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<DeviceVariant> variants;

  DeviceVariant? variantById(String variantId) {
    for (final variant in variants) {
      if (variant.id == variantId) {
        return variant;
      }
    }

    return null;
  }
}

enum DeviceAccessStatus { active, inactive }

class CustomerDevice {
  const CustomerDevice({
    required this.deviceTypeId,
    required this.variantId,
    required this.deviceId,
    required this.deviceName,
    required this.serialNumber,
    this.accessStatus = DeviceAccessStatus.active,
  });

  final String deviceTypeId;
  final String variantId;
  final String deviceId;
  final String deviceName;
  final String serialNumber;
  final DeviceAccessStatus accessStatus;

  bool get isActive => accessStatus == DeviceAccessStatus.active;

  bool get isInactive => accessStatus == DeviceAccessStatus.inactive;
}
