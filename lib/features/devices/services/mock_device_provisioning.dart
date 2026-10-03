import '../data/customer_devices.dart';
import '../data/mock_device_registry.dart';
import '../models/device_models.dart';

class MockDeviceProvisioning {
  MockDeviceProvisioning._();

  static const String currentCustomerId = 'customer-001';

  static MockPhysicalDevice? findDevice(String setupCode) {
    return MockDeviceRegistry.findBySetupCode(setupCode);
  }

  static CustomerDevice? findCustomerDevice(String deviceId) {
    return CustomerDevices.findByDeviceId(deviceId);
  }

  static bool isOwnedByCurrentCustomer(String deviceId) {
    final device = MockDeviceRegistry.findByDeviceId(deviceId);

    return device?.ownerId == currentCustomerId;
  }

  static Future<MockPhysicalDevice?> claimDevice(String setupCode) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final device = MockDeviceRegistry.findBySetupCode(setupCode);

    if (device == null) {
      return null;
    }

    if (device.isClaimed) {
      return null;
    }

    final claimed = MockDeviceRegistry.claimDevice(
      deviceId: device.deviceId,
      ownerId: currentCustomerId,
    );

    if (!claimed) {
      return null;
    }

    return MockDeviceRegistry.findByDeviceId(device.deviceId);
  }

  static bool renameDevice({
    required String deviceId,
    required String deviceName,
  }) {
    final renamed = CustomerDevices.renameDevice(
      deviceId: deviceId,
      deviceName: deviceName,
    );

    if (!renamed) {
      return false;
    }

    MockDeviceRegistry.setDeviceName(
      deviceId: deviceId,
      deviceName: deviceName,
    );

    return true;
  }

  static bool removeDevice(String deviceId) {
    return CustomerDevices.removeDevice(deviceId);
  }

  static bool restoreDevice(String deviceId) {
    return CustomerDevices.restoreDevice(deviceId);
  }

  static bool addToCustomerDevices({
    required MockPhysicalDevice device,
    required String deviceName,
  }) {
    final existing = CustomerDevices.findByDeviceId(device.deviceId);

    if (existing != null) {
      return false;
    }

    final customerDevice = CustomerDevice(
      deviceTypeId: device.deviceTypeId,
      variantId: device.variantId,
      deviceId: device.deviceId,
      deviceName: deviceName,
      serialNumber: device.serialNumber,
    );

    final added = CustomerDevices.addDevice(customerDevice);

    if (added) {
      MockDeviceRegistry.setDeviceName(
        deviceId: device.deviceId,
        deviceName: deviceName,
      );
    }

    return added;
  }
}
