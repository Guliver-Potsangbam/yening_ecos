class DeviceSetupConfig {
  const DeviceSetupConfig({
    required this.setupSsidPrefix,
    required this.setupPassword,
    required this.gatewayFallback,
    this.provisioningTimeout = const Duration(seconds: 30),
    this.statusPollInterval = const Duration(seconds: 1),
  });

  final String setupSsidPrefix;
  final String setupPassword;
  final String gatewayFallback;

  final Duration provisioningTimeout;
  final Duration statusPollInterval;

  /// Development configuration used by the current
  /// Yening Ecos ESP32 provisioning firmware.
  ///
  /// The password is development-only and must not become
  /// a universal production device password.
  static const development = DeviceSetupConfig(
    setupSsidPrefix: 'Yening-Eco-Setup',
    setupPassword: '12345678',
    gatewayFallback: '192.168.4.1',
  );
}
