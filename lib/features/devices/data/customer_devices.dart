import 'package:flutter/material.dart';
import 'package:yening_ecos/features/devices/models/device_models.dart';

class CustomerDevices {
  CustomerDevices._();

  static final ValueNotifier<List<CustomerDevice>> devices =
      ValueNotifier<List<CustomerDevice>>([
        const CustomerDevice(
          deviceTypeId: 'envirosense',
          variantId: 'envirosense_basic',
          deviceId: 'device-env-001',
          deviceName: 'EnviroSense-01',
          serialNumber: 'ES-BASIC-2026-000001',
        ),
        const CustomerDevice(
          deviceTypeId: 'watersense',
          variantId: 'watersense_premium',
          deviceId: 'device-water-001',
          deviceName: 'WaterSense-01',
          serialNumber: 'WS-PREMIUM-2026-000001',
        ),
        const CustomerDevice(
          deviceTypeId: 'gaschecker',
          variantId: 'gaschecker_industrial',
          deviceId: 'device-gas-001',
          deviceName: 'GasChecker-01',
          serialNumber: 'GC-IND-2026-000001',
        ),
      ]);

  static List<CustomerDevice> get currentCustomer => devices.value;

  static List<CustomerDevice> get activeDevices =>
      devices.value.where((device) => device.isActive).toList(growable: false);

  static List<CustomerDevice> get inactiveDevices => devices.value
      .where((device) => device.isInactive)
      .toList(growable: false);

  static CustomerDevice? findByDeviceId(String deviceId) {
    for (final device in devices.value) {
      if (device.deviceId == deviceId) {
        return device;
      }
    }

    return null;
  }

  static bool addDevice(CustomerDevice device) {
    final existing = findByDeviceId(device.deviceId);

    if (existing != null) {
      return false;
    }

    devices.value = [...devices.value, device];

    return true;
  }

  static bool renameDevice({
    required String deviceId,
    required String deviceName,
  }) {
    final index = devices.value.indexWhere(
      (device) => device.deviceId == deviceId,
    );

    if (index == -1) {
      return false;
    }

    final updatedDevices = List<CustomerDevice>.from(devices.value);

    final existing = updatedDevices[index];

    updatedDevices[index] = CustomerDevice(
      deviceTypeId: existing.deviceTypeId,
      variantId: existing.variantId,
      deviceId: existing.deviceId,
      deviceName: deviceName,
      serialNumber: existing.serialNumber,
      accessStatus: existing.accessStatus,
    );

    devices.value = updatedDevices;

    return true;
  }

  static bool removeDevice(String deviceId) {
    final index = devices.value.indexWhere(
      (device) => device.deviceId == deviceId,
    );

    if (index == -1) {
      return false;
    }

    final updatedDevices = List<CustomerDevice>.from(devices.value);

    final existing = updatedDevices[index];

    updatedDevices[index] = CustomerDevice(
      deviceTypeId: existing.deviceTypeId,
      variantId: existing.variantId,
      deviceId: existing.deviceId,
      deviceName: existing.deviceName,
      serialNumber: existing.serialNumber,
      accessStatus: DeviceAccessStatus.inactive,
    );

    devices.value = updatedDevices;

    return true;
  }

  static bool restoreDevice(String deviceId) {
    final index = devices.value.indexWhere(
      (device) => device.deviceId == deviceId,
    );

    if (index == -1) {
      return false;
    }

    final updatedDevices = List<CustomerDevice>.from(devices.value);

    final existing = updatedDevices[index];

    updatedDevices[index] = CustomerDevice(
      deviceTypeId: existing.deviceTypeId,
      variantId: existing.variantId,
      deviceId: existing.deviceId,
      deviceName: existing.deviceName,
      serialNumber: existing.serialNumber,
      accessStatus: DeviceAccessStatus.active,
    );

    devices.value = updatedDevices;

    return true;
  }
}
