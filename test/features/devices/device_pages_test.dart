import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/devices/devices_page.dart';
import 'package:yening_ecos/features/devices/models/user_device.dart';
import 'package:yening_ecos/features/devices/services/user_devices_service.dart';
import 'package:yening_ecos/features/home/home_page.dart';
import 'package:yening_ecos/features/home/widgets/home_empty_state.dart';

void main() {
  const device = UserDevice(
    deviceId: 'YEC-DEV-000001',
    deviceName: 'EnviroSense Basic',
    serialNumber: 'SN-001',
    deviceTypeId: 'envirosense_basic_v1',
  );

  for (final home in [true, false]) {
    final page = home ? 'Home' : 'Devices';
    testWidgets('$page shows owned devices and updates when the list changes', (
      tester,
    ) async {
      final stream = StreamController<UserDevicesState>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: home
                ? HomePage(devicesStream: stream.stream)
                : DevicesPage(devicesStream: stream.stream),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      stream.add(const UserDevicesState.loaded([device]));
      await tester.pump();
      expect(find.text('EnviroSense Basic'), findsOneWidget);
      expect(find.text('YEC-DEV-000001'), findsOneWidget);
      expect(find.byType(HomeEmptyState), findsNothing);
      expect(find.text('No devices connected'), findsNothing);
      expect(find.text('Added to your account'), findsOneWidget);
      stream.add(
        const UserDevicesState.loaded([
          device,
          UserDevice(
            deviceId: 'device-2',
            deviceName: 'Kitchen',
            serialNumber: '',
            deviceTypeId: 'envirosense_basic_v1',
          ),
        ]),
      );
      await tester.pump();
      expect(find.text('Kitchen'), findsOneWidget);
    });

    testWidgets(
      '$page shows loading and failures without claiming the account is empty',
      (tester) async {
        final stream = StreamController<UserDevicesState>();
        addTearDown(stream.close);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: home
                  ? HomePage(devicesStream: stream.stream)
                  : DevicesPage(devicesStream: stream.stream),
            ),
          ),
        );
        stream.add(const UserDevicesState.loading());
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(HomeEmptyState), findsNothing);
        stream.addError(StateError('permission denied'));
        await tester.pump();
        expect(
          find.textContaining('Unable to load your devices'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('No devices connected'), findsNothing);
        expect(find.byType(HomeEmptyState), findsNothing);
        stream.add(const UserDevicesState.loaded([device]));
        await tester.pump();
        expect(find.text('EnviroSense Basic'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );
  }

  testWidgets('Devices replaces its empty state as soon as a claim arrives', (
    tester,
  ) async {
    final stream = StreamController<UserDevicesState>();
    addTearDown(stream.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicesPage(devicesStream: stream.stream)),
      ),
    );
    stream.add(const UserDevicesState.loaded([]));
    await tester.pump();
    expect(find.text('No devices connected'), findsOneWidget);
    stream.add(const UserDevicesState.loaded([device]));
    await tester.pump();
    expect(find.text('No devices connected'), findsNothing);
    expect(find.text('EnviroSense Basic'), findsOneWidget);
  });
}
