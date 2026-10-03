import '../data/mock_device_registry.dart';

abstract interface class DeviceProvisioningService {
  Future<bool> connectToDevice(MockPhysicalDevice device);

  Future<List<String>> scanWifiNetworks();

  Future<bool> provisionWifi({
    required MockPhysicalDevice device,
    required String ssid,
    required String password,
  });

  Future<bool> waitForWifiConnection(MockPhysicalDevice device);

  Future<bool> waitForFirebaseConnection(MockPhysicalDevice device);
}
