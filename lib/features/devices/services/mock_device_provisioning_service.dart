import '../data/mock_device_registry.dart';
import 'device_provisioning_service.dart';

class MockDeviceProvisioningService implements DeviceProvisioningService {
  const MockDeviceProvisioningService();

  @override
  Future<bool> connectToDevice(MockPhysicalDevice device) async {
    await Future<void>.delayed(const Duration(seconds: 1));

    return true;
  }

  @override
  Future<List<String>> scanWifiNetworks() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    return const ['Home Wi-Fi', 'Office Wi-Fi', 'UDM Guest'];
  }

  @override
  Future<bool> provisionWifi({
    required MockPhysicalDevice device,
    required String ssid,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));

    return true;
  }

  @override
  Future<bool> waitForWifiConnection(MockPhysicalDevice device) async {
    await Future<void>.delayed(const Duration(seconds: 2));

    return true;
  }

  @override
  Future<bool> waitForFirebaseConnection(MockPhysicalDevice device) async {
    await Future<void>.delayed(const Duration(seconds: 2));

    return true;
  }
}
