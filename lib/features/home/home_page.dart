import 'package:flutter/material.dart';

import 'package:yening_ecos/features/alerts/alerts_page.dart';
import 'package:yening_ecos/features/auth/services/auth_service.dart';
import 'package:yening_ecos/features/devices/data/customer_devices.dart';
import 'package:yening_ecos/features/devices/data/mock_device_catalog.dart';
import 'package:yening_ecos/features/devices/models/device_models.dart';
import 'package:yening_ecos/features/profile/profile_page.dart';
import 'package:yening_ecos/features/settings/settings_page.dart';
import 'package:yening_ecos/features/devices/devices_page.dart';
import 'package:yening_ecos/features/home/data/home_trend_data.dart';
import 'package:yening_ecos/features/home/widgets/home_app_bar.dart';
import 'package:yening_ecos/features/home/widgets/home_app_drawer.dart';
import 'package:yening_ecos/features/home/widgets/home_dashboard.dart';
import 'package:yening_ecos/features/home/widgets/home_navigation_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedNavIndex = 0;
  int _selectedDeviceIndex = 0;
  String _selectedRange = '24H';

  String? _registeredFcmToken;

  List<CustomerDevice> get _customerDevices => CustomerDevices.currentCustomer;

  CustomerDevice get _selectedDevice => _customerDevices[_selectedDeviceIndex];

  DeviceDefinition? get _selectedDeviceDefinition =>
      MockDeviceCatalog.deviceByTypeId(_selectedDevice.deviceTypeId);

  DeviceVariant? get _selectedVariant =>
      _selectedDeviceDefinition?.variantById(_selectedDevice.variantId);

  String get _pageTitle {
    return switch (_selectedNavIndex) {
      1 => 'My Devices',
      2 => 'Alerts',
      3 => 'Profile',
      _ => 'Overview',
    };
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onNavigationChanged(int index) {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _selectedNavIndex = index;
    });
  }

  void _onDeviceSelected(int index) {
    setState(() {
      _selectedDeviceIndex = index;
      _selectedNavIndex = 0;
      _selectedRange = '24H';
    });
  }

  void _onRangeChanged(String range) {
    setState(() {
      _selectedRange = range;
    });
  }

  void _showDeviceSelector() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text(
                  'Your devices',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ...List.generate(_customerDevices.length, (index) {
                final device = _customerDevices[index];

                final definition = MockDeviceCatalog.deviceByTypeId(
                  device.deviceTypeId,
                );

                final variant = definition?.variantById(device.variantId);

                if (definition == null || variant == null) {
                  return const SizedBox.shrink();
                }

                return ListTile(
                  selected: index == _selectedDeviceIndex,
                  leading: CircleAvatar(child: Icon(definition.icon)),
                  title: Text(device.deviceName),
                  subtitle: Text(
                    '${definition.name} ${variant.name} • ${device.serialNumber}',
                  ),
                  trailing: index == _selectedDeviceIndex
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    _onDeviceSelected(index);
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_customerDevices.isEmpty) {
      return Scaffold(
        appBar: HomeAppBar(title: _pageTitle, isHome: _selectedNavIndex == 0),
        drawer: _buildDrawer(),
        body: const Center(child: Text('No devices found for this account.')),
        bottomNavigationBar: HomeNavigationBar(
          selectedIndex: _selectedNavIndex,
          onDestinationSelected: _onNavigationChanged,
        ),
      );
    }

    return Scaffold(
      appBar: HomeAppBar(title: _pageTitle, isHome: _selectedNavIndex == 0),
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          HomeDashboard(
            device: _selectedDevice,
            deviceDefinition: _selectedDeviceDefinition!,
            variant: _selectedVariant!,
            chartData: homeTrendData,
            selectedRange: _selectedRange,
            onRangeChanged: _onRangeChanged,
            onSwitchDevice: _showDeviceSelector,
            onViewAllAlerts: () {
              setState(() {
                _selectedNavIndex = 2;
              });
            },
          ),
          const DevicesPage(),
          const AlertsPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: HomeNavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: _onNavigationChanged,
      ),
    );
  }

  Widget _buildDrawer() {
    return HomeAppDrawer(
      devices: _customerDevices,
      selectedDeviceIndex: _selectedDeviceIndex,
      onDashboardSelected: () {
        setState(() {
          _selectedNavIndex = 0;
        });
      },
      onDevicesSelected: () {
        setState(() {
          _selectedNavIndex = 1;
        });
      },
      onAlertsSelected: () {
        setState(() {
          _selectedNavIndex = 2;
        });
      },
      onProfileSelected: () {
        setState(() {
          _selectedNavIndex = 3;
        });
      },
      onDeviceSelected: _onDeviceSelected,
      onSettingsSelected: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsPage()));
      },
      onSignOutSelected: () => AuthService().signOut(),
    );
  }
}
