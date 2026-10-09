import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../devices/data/device_claim_service.dart';
import '../devices/data/device_registry_service.dart';
import '../devices/models/user_device.dart';
import 'models/device_setup_config.dart';
import 'models/device_type_definition.dart';
import 'models/local_device_info.dart';
import 'models/wifi_provision_status.dart';
import 'models/wifi_network.dart';
import 'services/device_type_service.dart';
import 'services/setup_cloud_retry.dart';
import 'services/wifi_provisioning_service.dart';
import 'widgets/wifi_network_picker.dart';

enum DeviceSetupStage {
  preparingDevice,
  connectingToDevice,
  verifyingDevice,
  enteringWifi,
  provisioningWifi,
  claimingDevice,
  completed,
  error,
}

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({
    super.key,
    this.config = DeviceSetupConfig.development,
    this.deviceToReconnect,
    this.wifiService,
    this.deviceTypeService,
    this.deviceRegistryService,
    this.deviceClaimService,
    this.currentUserUid,
  });

  final DeviceSetupConfig config;
  final UserDevice? deviceToReconnect;
  final WifiProvisioningService? wifiService;
  final DeviceTypeService? deviceTypeService;
  final DeviceRegistryService? deviceRegistryService;
  final DeviceClaimService? deviceClaimService;
  final String? Function()? currentUserUid;

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  late final WifiProvisioningService _wifiService;
  late final DeviceTypeService _deviceTypeService;
  late final DeviceRegistryService _deviceRegistryService;
  late final DeviceClaimService _deviceClaimService;
  bool get _reconnecting => widget.deviceToReconnect != null;
  String? get _currentUid => widget.currentUserUid != null
      ? widget.currentUserUid!()
      : FirebaseAuth.instance.currentUser?.uid;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _ssidController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  DeviceSetupStage _stage = DeviceSetupStage.connectingToDevice;

  LocalDeviceInfo? _deviceInfo;
  LocalDeviceInfo? _localDeviceInfo;
  DeviceTypeDefinition? _deviceType;
  WifiProvisionStatus? _provisionStatus;

  String? _errorMessage;
  String _verificationMessage = 'Reading your device identity…';
  List<WifiNetwork> _networks = const [];
  WifiNetwork? _selectedNetwork;
  String? _scanMessage;
  bool _manualWifiEntry = true;
  bool _isScanning = false;

  bool _obscurePassword = true;
  bool _isBusy = false;

  String get _deviceDisplayName {
    final deviceTypeName = _deviceType?.deviceTypeName.trim();

    if (deviceTypeName != null && deviceTypeName.isNotEmpty) {
      return deviceTypeName;
    }

    final deviceName = _deviceInfo?.deviceName.trim();

    if (deviceName != null && deviceName.isNotEmpty) {
      return deviceName;
    }

    return 'Device';
  }

  @override
  void initState() {
    super.initState();

    _wifiService = widget.wifiService ?? WifiProvisioningService.instance;
    _deviceTypeService = widget.deviceTypeService ?? DeviceTypeService();
    _deviceRegistryService =
        widget.deviceRegistryService ?? DeviceRegistryService();
    _deviceClaimService = widget.deviceClaimService ?? DeviceClaimService();
    if (_reconnecting) {
      _stage = DeviceSetupStage.preparingDevice;
    } else {
      Future.microtask(_beginSetup);
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();

    unawaited(_releaseSetupNetwork());

    super.dispose();
  }

  Future<void> _beginSetup() async {
    if (!mounted || _isBusy) {
      return;
    }

    setState(() {
      _stage = _localDeviceInfo == null
          ? DeviceSetupStage.connectingToDevice
          : DeviceSetupStage.verifyingDevice;
      _errorMessage = null;
      _isBusy = true;
      _deviceInfo = null;
      _deviceType = null;
      _provisionStatus = null;
    });

    try {
      if (_localDeviceInfo == null) {
        await _wifiService.connectToSetupNetwork(config: widget.config);
        if (!mounted) return;
        setState(() {
          _stage = DeviceSetupStage.verifyingDevice;
          _verificationMessage = 'Reading your device identity…';
        });
        final info = await _wifiService.getDeviceInfo();
        if (!mounted) return;
        final expected = widget.deviceToReconnect;
        if (expected != null &&
            (info.deviceId != expected.deviceId ||
                info.deviceTypeId != expected.deviceTypeId ||
                (info.serialNumber.isNotEmpty &&
                    info.serialNumber != expected.serialNumber))) {
          throw const WifiProvisioningException(
            code: 'DEVICE_IDENTITY_MISMATCH',
            message: 'This is a different device. Connect to the setup network of the device you selected.',
          );
        }
        _localDeviceInfo = info;
        setState(() => _verificationMessage = 'Finding nearby Wi-Fi networks…');
        await _loadNearbyNetworks(info.deviceId);
        if (!mounted) return;
      }
      final deviceInfo = _localDeviceInfo!;

      // Unregistering the setup request is asynchronous from Android's
      // perspective. Wait for a validated default network before cloud reads.
      setState(
        () => _verificationMessage =
            'Restoring your phone’s internet connection…',
      );
      await _wifiService.disconnectFromSetupNetwork();
      if (!mounted) return;
      await _wifiService.waitForInternet();
      if (!mounted) return;
      setState(
        () => _verificationMessage = 'Checking your device registration…',
      );

      if (!deviceInfo.isValid) {
        throw const WifiProvisioningException(
          message: 'The device returned incomplete identity information.',
        );
      }

      final deviceType = await _readRegistry(
        () => _deviceTypeService.getDeviceType(deviceInfo.deviceTypeId),
      );
      if (!mounted) return;

      if (deviceType == null) {
        throw WifiProvisioningException(
          message:
              'Device type "${deviceInfo.deviceTypeId}" '
              'is not registered in Yening Ecos.',
        );
      }

      if (!deviceType.isAvailable && !_reconnecting) {
        throw WifiProvisioningException(
          message:
              '${deviceType.deviceTypeName} '
              'is not currently available for setup.',
        );
      }

      if (deviceType.deviceTypeId != deviceInfo.deviceTypeId) {
        throw const WifiProvisioningException(
          message: 'The device type registry record is mismatched.',
        );
      }

      final registryRecord = await _readRegistry(
        () => _deviceRegistryService.getDevice(deviceInfo.deviceId),
      );
      if (!mounted) return;

      if (registryRecord == null) {
        throw WifiProvisioningException(
          message:
              'Device ${deviceInfo.deviceId} '
              'is not registered in Yening Ecos.',
        );
      }

      if (registryRecord.deviceId != deviceInfo.deviceId ||
          registryRecord.serialNumber.isEmpty ||
          registryRecord.deviceName.isEmpty) {
        throw const WifiProvisioningException(
          message: 'The device registry record is incomplete or mismatched.',
        );
      }

      if (deviceInfo.serialNumber.isNotEmpty &&
          registryRecord.serialNumber != deviceInfo.serialNumber) {
        throw const WifiProvisioningException(
          message:
              'The physical device serial number '
              'does not match the Yening Ecos registry.',
        );
      }

      if (registryRecord.deviceTypeId != deviceInfo.deviceTypeId) {
        throw const WifiProvisioningException(
          message:
              'The physical device type '
              'does not match the Yening Ecos registry.',
        );
      }

      final currentUid = _currentUid;

      if (currentUid == null) {
        throw const WifiProvisioningException(
          message:
              'Your session has expired. '
              'Please sign in again.',
        );
      }

      if (registryRecord.status != 'unclaimed' &&
          registryRecord.claimedByUid != currentUid) {
        throw const WifiProvisioningException(
          message:
              'This device is already registered '
              'to another account.',
        );
      }

      if (_reconnecting &&
          (registryRecord.status != 'claimed' ||
              registryRecord.claimedByUid != currentUid)) {
        throw const DeviceClaimException(
          'Only the current owner can change this device’s Wi-Fi.',
        );
      }
      if (!mounted) return;

      setState(() {
        // The attached firmware only reports ID and type. Missing display
        // metadata comes from the registry, never from invented defaults.
        _deviceInfo = LocalDeviceInfo(
          apiVersion: deviceInfo.apiVersion,
          deviceId: deviceInfo.deviceId,
          deviceName: registryRecord.deviceName,
          serialNumber: registryRecord.serialNumber,
          deviceTypeId: deviceInfo.deviceTypeId,
          provisioningStatus: deviceInfo.provisioningStatus,
        );
        _deviceType = deviceType;
        _stage = DeviceSetupStage.enteringWifi;
      });
    } catch (error, stackTrace) {
      debugPrint('Device setup failed: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (error is WifiProvisioningException &&
          error.code == 'DEVICE_IDENTITY_MISMATCH') {
        _localDeviceInfo = null;
      }
      _showError(_friendlyError(error));
    } finally {
      await _releaseSetupNetwork();
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _submitWifi() async {
    if (_isBusy || _isScanning) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final deviceInfo = _deviceInfo;

    if (deviceInfo == null) {
      _showError(
        'The device identity is unavailable. '
        'Please start setup again.',
      );
      return;
    }

    final ssid = _ssidController.text;

    final password = _passwordController.text;

    setState(() {
      _stage = DeviceSetupStage.provisioningWifi;
      _errorMessage = null;
      _isBusy = true;
    });

    try {
      if (_reconnecting) {
        final registry = await _readRegistry(
          () => _deviceRegistryService.getDevice(deviceInfo.deviceId),
        );
        if (!mounted) return;
        if (_currentUid == null ||
            registry?.status != 'claimed' ||
            registry?.claimedByUid != _currentUid) {
          throw const DeviceClaimException(
            'Only the current owner can change this device’s Wi-Fi.',
          );
        }
      }
      await _wifiService.connectToSetupNetwork(config: widget.config);
      if (!mounted) return;
      final currentInfo = await _wifiService.getDeviceInfo();
      if (!mounted) return;
      if (currentInfo.deviceId != deviceInfo.deviceId ||
          currentInfo.deviceTypeId != deviceInfo.deviceTypeId ||
          (currentInfo.serialNumber.isNotEmpty &&
              currentInfo.serialNumber != deviceInfo.serialNumber)) {
        throw const WifiProvisioningException(
          code: 'DEVICE_IDENTITY_MISMATCH',
          message: 'A different device was selected. Start setup again.',
        );
      }
      await _wifiService.provisionWifi(ssid: ssid, password: password);
      if (!mounted) return;

      final provisioningStatus = await _wifiService.waitForProvisioning(
        expectedDeviceId: deviceInfo.deviceId,
        expectedSsid: ssid,
        config: widget.config,
        isCancelled: () => !mounted,
      );

      if (!provisioningStatus.isConnected) {
        throw const WifiProvisioningException(
          message: 'The device did not confirm a successful Wi-Fi connection.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _provisionStatus = provisioningStatus;
        _stage = DeviceSetupStage.claimingDevice;
      });

      _passwordController.clear();
      await _wifiService.disconnectFromSetupNetwork();
      if (!mounted) return;
      await _claimDevice();

      if (!mounted) {
        return;
      }

      setState(() {
        _stage = DeviceSetupStage.completed;
      });
    } catch (error, stackTrace) {
      debugPrint('Wi-Fi provisioning failed: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (error is WifiProvisioningException &&
          error.code == 'DEVICE_IDENTITY_MISMATCH') {
        _deviceInfo = null;
        _localDeviceInfo = null;
      }
      _showError(
        _provisionStatus?.isConnected == true
            ? 'Wi-Fi is configured. Restore your phone’s internet connection '
                  'and retry saving setup. ${_friendlyError(error)}'
            : _friendlyError(error),
      );
    } finally {
      await _releaseSetupNetwork();
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _loadNearbyNetworks(String deviceId) async {
    try {
      final networks = await _wifiService.scanNetworks(
        expectedDeviceId: deviceId,
        isCancelled: () => !mounted,
      );
      if (!mounted) return;
      setState(() {
        _networks = networks;
        _selectedNetwork = null;
        _ssidController.clear();
        _passwordController.clear();
        _manualWifiEntry = networks.every((network) => !network.isSupported);
        _scanMessage = networks.isEmpty
            ? 'No nearby networks found. Scan again or enter the network name.'
            : null;
      });
    } on WifiProvisioningException catch (error) {
      if (error.code == 'DEVICE_IDENTITY_MISMATCH' ||
          error.code == 'WIFI_SETUP_CANCELLED') {
        rethrow;
      }
      if (!mounted) return;
      setState(() {
        _scanMessage = error.code == 'WIFI_SCAN_UNSUPPORTED' ? error.message : 'Nearby networks could not be loaded. Scan again or enter the network name.';
      });
    }
  }

  Future<void> _scanNearbyNetworks() async {
    if (_isBusy || _isScanning || _deviceInfo == null) return;
    setState(() {
      _isScanning = true;
      _scanMessage = null;
    });
    try {
      await _wifiService.connectToSetupNetwork(config: widget.config);
      if (!mounted) return;
      final info = await _wifiService.getDeviceInfo();
      if (!mounted) return;
      if (info.deviceId != _deviceInfo!.deviceId ||
          info.deviceTypeId != _deviceInfo!.deviceTypeId ||
          (info.serialNumber.isNotEmpty &&
              info.serialNumber != _deviceInfo!.serialNumber)) {
        throw const WifiProvisioningException(
          code: 'DEVICE_IDENTITY_MISMATCH',
          message: 'A different device was selected. Start setup again.',
        );
      }
      await _loadNearbyNetworks(info.deviceId);
    } catch (error) {
      if (!mounted) return;
      if (error is WifiProvisioningException &&
          error.code == 'DEVICE_IDENTITY_MISMATCH') {
        _deviceInfo = null;
        _localDeviceInfo = null;
        _showError(error.message);
      } else {
        setState(() => _scanMessage = _friendlyError(error));
      }
    } finally {
      await _releaseSetupNetwork();
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _selectNetwork(WifiNetwork? network) {
    if (network == null || !network.isSupported) return;
    setState(() {
      _selectedNetwork = network;
      _ssidController.text = network.ssid;
      _passwordController.clear();
    });
  }

  void _toggleManualWifi() {
    setState(() {
      _manualWifiEntry = !_manualWifiEntry;
      _selectedNetwork = null;
      _ssidController.clear();
      _passwordController.clear();
    });
  }

  Future<void> _claimDevice() async {
    final deviceInfo = _deviceInfo;

    if (deviceInfo == null) {
      throw const DeviceClaimException('Device information is unavailable.');
    }

    if (_provisionStatus?.hasConfirmedConnection != true) {
      throw const DeviceClaimException(
        'The device has not confirmed its Wi-Fi connection.',
      );
    }
    await _wifiService.waitForInternet();
    if (!mounted) return;

    await _deviceClaimService
        .claimDevice(
          deviceInfo: deviceInfo,
          wifiConfirmation: _provisionStatus,
          requireExistingOwner: _reconnecting,
        )
        .timeout(const Duration(seconds: 30));
  }

  Future<T> _readRegistry<T>(Future<T> Function() read) {
    return retrySetupCloudRead(
      read,
      isCancelled: () => !mounted,
      isRetryable: (error) =>
          error is TimeoutException ||
          (error is FirebaseException &&
              (error.code == 'unavailable' ||
                  error.code == 'deadline-exceeded')),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _stage = DeviceSetupStage.error;
      _errorMessage = message;
    });
  }

  Future<void> _retry() async {
    if (_isBusy || _isScanning) return;
    if (_provisionStatus?.isConnected == true) {
      setState(() {
        _stage = DeviceSetupStage.claimingDevice;
        _errorMessage = null;
        _isBusy = true;
      });
      try {
        await _wifiService.disconnectFromSetupNetwork();
        if (!mounted) return;
        await _claimDevice();
        if (mounted) setState(() => _stage = DeviceSetupStage.completed);
      } catch (error) {
        _showError(
          'Wi-Fi is configured. Restore your phone’s internet '
          'connection and retry adding the device. ${_friendlyError(error)}',
        );
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
    } else if (_deviceInfo != null) {
      setState(() {
        _stage = DeviceSetupStage.enteringWifi;
        _errorMessage = null;
      });
    } else {
      await _beginSetup();
    }
  }

  Future<void> _releaseSetupNetwork() async {
    try {
      await _wifiService.disconnectFromSetupNetwork();
    } catch (error) {
      debugPrint('Could not release setup Wi-Fi: $error');
    }
  }

  String _friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'The account connection timed out. Check your phone’s internet connection and retry.';
    }

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Your account cannot access this device registry record. '
            'Check that the device belongs to your account and the current Firestore setup rules are deployed.';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'The device identity was read, but its cloud registration could not be checked. '
            'Connect your phone to your normal Wi-Fi or enable mobile data, then retry. '
            'You do not need to reconnect to the device for verification.';
      }
    }
    if (error is WifiProvisioningException) {
      return error.message;
    }

    if (error is DeviceClaimException) {
      return error.message;
    }

    return 'Device setup could not be completed. '
        'Please check that the device is powered on '
        'and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_reconnecting ? 'Change Wi-Fi' : 'Device Setup'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      _buildStepIndicator(),
                      const SizedBox(height: 28),
                      _buildBody(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _reconnecting ? 'Change device Wi-Fi' : 'Set up your device',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _reconnecting
              ? 'Reconnect ${widget.deviceToReconnect!.deviceName} while keeping it on your account.'
              : _deviceInfo == null
              ? 'Connect the device to Yening Ecos.'
              : 'Configure $_deviceDisplayName '
                    'and add it to your account.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final steps = <_SetupStep>[
      _SetupStep(number: 1, label: 'Connect'),
      _SetupStep(number: 2, label: 'Verify'),
      _SetupStep(number: 3, label: 'Wi-Fi'),
      _SetupStep(number: 4, label: _reconnecting ? 'Save' : 'Claim'),
      _SetupStep(number: 5, label: 'Done'),
    ];

    final currentNumber = switch (_stage) {
      DeviceSetupStage.preparingDevice => 1,
      DeviceSetupStage.connectingToDevice => 1,
      DeviceSetupStage.verifyingDevice => 2,
      DeviceSetupStage.enteringWifi => 3,
      DeviceSetupStage.provisioningWifi => 3,
      DeviceSetupStage.claimingDevice => 4,
      DeviceSetupStage.completed => 5,
      DeviceSetupStage.error => 1,
    };

    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(
            child: _SetupStepIndicator(
              step: steps[index],
              state: steps[index].number < currentNumber
                  ? _SetupStepState.completed
                  : steps[index].number == currentNumber
                  ? _SetupStepState.current
                  : _SetupStepState.upcoming,
            ),
          ),
          if (index != steps.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case DeviceSetupStage.preparingDevice:
        return _SetupCard(
          icon: Icons.wifi_rounded,
          title: 'Keep your device nearby',
          description: 'Power on the device. If its setup Wi-Fi is not visible, hold its BOOT/setup button for 5 seconds while it is running. This opens setup without removing your device from your account. After Wi-Fi settings are erased, setup opens automatically.',
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _beginSetup,
                icon: const Icon(Icons.wifi_find_rounded),
                label: const Text('Connect to device'),
              ),
            ),
          ),
        );

      case DeviceSetupStage.connectingToDevice:
        return _buildConnectingState(context);

      case DeviceSetupStage.verifyingDevice:
        return _buildVerifyingState(context);

      case DeviceSetupStage.enteringWifi:
      case DeviceSetupStage.provisioningWifi:
        return _buildWifiState(context);

      case DeviceSetupStage.claimingDevice:
        return _buildClaimingState(context);

      case DeviceSetupStage.completed:
        return _buildCompletedState(context);

      case DeviceSetupStage.error:
        return _buildErrorState(context);
    }
  }

  Widget _buildConnectingState(BuildContext context) {
    return _SetupCard(
      icon: Icons.wifi_find_rounded,
      title: 'Connecting to your device',
      description: 'Yening Ecos is connecting to the device setup network.',
      child: const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Expanded(child: Text('A system Wi-Fi confirmation may appear.')),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyingState(BuildContext context) {
    return _SetupCard(
      icon: Icons.verified_rounded,
      title: 'Verifying device',
      description: _verificationMessage,
      child: const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Text('Please wait…'),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiState(BuildContext context) {
    final info = _deviceInfo;
    final openNetwork = !_manualWifiEntry && _selectedNetwork?.isOpen == true;

    if (info == null) {
      return const SizedBox.shrink();
    }

    return _SetupCard(
      icon: Icons.router_rounded,
      title: 'Connect $_deviceDisplayName to Wi-Fi',
      description:
          'Choose your 2.4 GHz Wi-Fi network and enter its password. '
          'Your phone will reconnect to the device to send them.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _DeviceIdentitySummary(deviceInfo: info, deviceType: _deviceType),
            const SizedBox(height: 20),
            WifiNetworkPicker(
              networks: _networks,
              selected: _selectedNetwork,
              manualEntry: _manualWifiEntry,
              scanning: _isScanning,
              enabled: !_isBusy,
              ssidController: _ssidController,
              scanMessage: _scanMessage,
              onSelected: _selectNetwork,
              onScan: _scanNearbyNetworks,
              onToggleManual: _toggleManualWifi,
            ),
            const SizedBox(height: 16),
            if (openNetwork)
              const Text('This is an open network. No password is required.')
            else
              TextFormField(
                controller: _passwordController,
                enabled: !_isBusy && !_isScanning,
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) {
                  if (!_manualWifiEntry && (value == null || value.isEmpty)) {
                    return 'Enter the password for this network.';
                  }
                  return WifiProvisioningService.validatePassword(value ?? '');
                },
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: _isBusy || _isScanning
                    ? null
                    : (_) => _submitWifi(),
                decoration: InputDecoration(
                  labelText: 'Wi-Fi password',
                  hintText: 'Leave blank for an open network',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isBusy || _isScanning ? null : _submitWifi,
                icon: _isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_rounded),
                label: Text(_isBusy ? 'Connecting device…' : 'Connect Device'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimingState(BuildContext context) {
    return _SetupCard(
      icon: Icons.person_add_alt_1_rounded,
      title: _reconnecting
          ? 'Saving Wi-Fi setup'
          : 'Adding device to your account',
      description: _reconnecting
          ? 'The device confirmed its Wi-Fi connection. Saving its updated setup status.'
          : 'The Wi-Fi connection is complete. Yening Ecos is now associating this physical device with your account.',
      child: const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Text('Finishing setup…'),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedState(BuildContext context) {
    final info = _deviceInfo;

    final status = _provisionStatus;

    return _SetupCard(
      icon: Icons.check_circle_rounded,
      title: _reconnecting ? 'Wi-Fi updated' : 'Device setup complete',
      description: _reconnecting
          ? 'Your device is connected to the selected Wi-Fi and remains on your account.'
          : 'Your device’s Wi-Fi is configured and it is registered to your account.',
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (info != null)
            _DeviceIdentitySummary(deviceInfo: info, deviceType: _deviceType),
          if (status?.ipAddress != null) ...[
            const SizedBox(height: 16),
            _InfoRow(label: 'Device IP', value: status!.ipAddress!),
          ],
          if (status?.ssid != null) ...[
            const SizedBox(height: 12),
            _InfoRow(label: 'Connected Wi-Fi', value: status!.ssid!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return _SetupCard(
      icon: Icons.error_outline_rounded,
      title: 'Setup could not be completed',
      description:
          _errorMessage ?? 'Something went wrong while setting up the device.',
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isBusy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isBusy ? null : _retry,
                  child: Text(
                    _provisionStatus?.isConnected == true
                        ? (_reconnecting
                              ? 'Retry update'
                              : 'Retry Registration')
                        : 'Try Again',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _DeviceIdentitySummary extends StatelessWidget {
  const _DeviceIdentitySummary({
    required this.deviceInfo,
    required this.deviceType,
  });

  final LocalDeviceInfo deviceInfo;
  final DeviceTypeDefinition? deviceType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final typeName = deviceType?.deviceTypeName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            typeName?.isNotEmpty == true ? typeName! : deviceInfo.deviceName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Device ID', value: deviceInfo.deviceId),
          const SizedBox(height: 8),
          _InfoRow(label: 'Serial number', value: deviceInfo.serialNumber),
          const SizedBox(height: 8),
          _InfoRow(label: 'Device type', value: deviceInfo.deviceTypeId),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupStep {
  const _SetupStep({required this.number, required this.label});

  final int number;
  final String label;
}

enum _SetupStepState { upcoming, current, completed }

class _SetupStepIndicator extends StatelessWidget {
  const _SetupStepIndicator({required this.step, required this.state});

  final _SetupStep step;
  final _SetupStepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = switch (state) {
      _SetupStepState.completed => theme.colorScheme.primary,
      _SetupStepState.current => theme.colorScheme.primary,
      _SetupStepState.upcoming => theme.colorScheme.outline,
    };

    final isUpcoming = state == _SetupStepState.upcoming;

    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: isUpcoming
              ? theme.colorScheme.surfaceContainerHighest
              : color,
          child: state == _SetupStepState.completed
              ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
              : Text(
                  '${step.number}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isUpcoming
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onPrimary,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: state == _SetupStepState.current
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
