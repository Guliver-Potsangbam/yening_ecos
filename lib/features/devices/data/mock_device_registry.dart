enum DeviceClaimStatus { unclaimed, claimed }

enum DeviceSetupStatus { pending, provisioning, online, failed }

class MockPhysicalDevice {
  MockPhysicalDevice({
    required this.deviceId,
    required this.deviceTypeId,
    required this.variantId,
    required this.serialNumber,
    required this.setupCode,
    this.claimStatus = DeviceClaimStatus.unclaimed,
    this.setupStatus = DeviceSetupStatus.pending,
    this.ownerId,
    this.deviceName,
  });

  final String deviceId;
  final String deviceTypeId;
  final String variantId;
  final String serialNumber;

  /// Code printed on the device or encoded in the QR code.
  final String setupCode;

  DeviceClaimStatus claimStatus;
  DeviceSetupStatus setupStatus;

  String? ownerId;
  String? deviceName;

  bool get isClaimed => claimStatus == DeviceClaimStatus.claimed;

  bool get isSetupComplete => setupStatus == DeviceSetupStatus.online;
}

class MockDeviceRegistry {
  MockDeviceRegistry._();

  static final List<MockPhysicalDevice> devices = [
    // ------------------------------------------------------------
    // Customer 001 - already claimed and completely configured
    // ------------------------------------------------------------

    MockPhysicalDevice(
      deviceId: 'device-env-001',
      deviceTypeId: 'envirosense',
      variantId: 'envirosense_basic',
      serialNumber: 'ES-BASIC-2026-000001',
      setupCode: 'ES-BASIC-001',
      claimStatus: DeviceClaimStatus.claimed,
      setupStatus: DeviceSetupStatus.online,
      ownerId: 'customer-001',
      deviceName: 'EnviroSense-01',
    ),

    MockPhysicalDevice(
      deviceId: 'device-water-001',
      deviceTypeId: 'watersense',
      variantId: 'watersense_premium',
      serialNumber: 'WS-PREMIUM-2026-000001',
      setupCode: 'WS-PREM-001',
      claimStatus: DeviceClaimStatus.claimed,
      setupStatus: DeviceSetupStatus.online,
      ownerId: 'customer-001',
      deviceName: 'WaterSense-01',
    ),

    MockPhysicalDevice(
      deviceId: 'device-gas-001',
      deviceTypeId: 'gaschecker',
      variantId: 'gaschecker_industrial',
      serialNumber: 'GC-IND-2026-000001',
      setupCode: 'GC-IND-001',
      claimStatus: DeviceClaimStatus.claimed,
      setupStatus: DeviceSetupStatus.online,
      ownerId: 'customer-001',
      deviceName: 'GasChecker-01',
    ),

    // ------------------------------------------------------------
    // Unclaimed devices for testing
    // ------------------------------------------------------------
    MockPhysicalDevice(
      deviceId: 'device-env-002',
      deviceTypeId: 'envirosense',
      variantId: 'envirosense_premium',
      serialNumber: 'ES-PREMIUM-2026-000002',
      setupCode: 'ES-PREM-002',
    ),

    MockPhysicalDevice(
      deviceId: 'device-water-002',
      deviceTypeId: 'watersense',
      variantId: 'watersense_basic',
      serialNumber: 'WS-BASIC-2026-000002',
      setupCode: 'WS-BASIC-002',
    ),

    MockPhysicalDevice(
      deviceId: 'device-gas-002',
      deviceTypeId: 'gaschecker',
      variantId: 'gaschecker_standard',
      serialNumber: 'GC-STD-2026-000002',
      setupCode: 'GC-STD-002',
    ),

    MockPhysicalDevice(
      deviceId: 'device-power-001',
      deviceTypeId: 'powersense',
      variantId: 'powersense_basic',
      serialNumber: 'PS-BASIC-2026-000001',
      setupCode: 'PS-BASIC-001',
    ),

    MockPhysicalDevice(
      deviceId: 'device-fire-001',
      deviceTypeId: 'firesense',
      variantId: 'firesense_industrial',
      serialNumber: 'FS-IND-2026-000001',
      setupCode: 'FS-IND-001',
    ),

    MockPhysicalDevice(
      deviceId: 'device-motion-001',
      deviceTypeId: 'motionsense',
      variantId: 'motionsense_pro',
      serialNumber: 'MS-PRO-2026-000001',
      setupCode: 'MS-PRO-001',
    ),
  ];

  static MockPhysicalDevice? findBySetupCode(String setupCode) {
    final normalizedCode = setupCode.trim().toUpperCase();

    for (final device in devices) {
      if (device.setupCode.toUpperCase() == normalizedCode) {
        return device;
      }
    }

    return null;
  }

  static MockPhysicalDevice? findByDeviceId(String deviceId) {
    for (final device in devices) {
      if (device.deviceId == deviceId) {
        return device;
      }
    }

    return null;
  }

  static MockPhysicalDevice? findBySerialNumber(String serialNumber) {
    final normalizedSerialNumber = serialNumber.trim().toUpperCase();

    for (final device in devices) {
      if (device.serialNumber.toUpperCase() == normalizedSerialNumber) {
        return device;
      }
    }

    return null;
  }

  static bool claimDevice({required String deviceId, required String ownerId}) {
    final device = findByDeviceId(deviceId);

    if (device == null) {
      return false;
    }

    if (device.isClaimed) {
      return false;
    }

    device.claimStatus = DeviceClaimStatus.claimed;
    device.setupStatus = DeviceSetupStatus.pending;
    device.ownerId = ownerId;

    return true;
  }

  static bool updateSetupStatus({
    required String deviceId,
    required DeviceSetupStatus status,
  }) {
    final device = findByDeviceId(deviceId);

    if (device == null) {
      return false;
    }

    device.setupStatus = status;

    return true;
  }

  static bool setDeviceName({
    required String deviceId,
    required String deviceName,
  }) {
    final device = findByDeviceId(deviceId);

    if (device == null) {
      return false;
    }

    device.deviceName = deviceName;

    return true;
  }
}
