import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yening_ecos/app/navigation/main_navigation_shell.dart';
import 'package:yening_ecos/core/notifications/notification_registration_service.dart';
import 'package:yening_ecos/core/preferences/temperature_unit_preference.dart';
import 'package:yening_ecos/core/ui/app_theme.dart';
import 'package:yening_ecos/features/auth/services/auth_service.dart';
import 'package:yening_ecos/features/auth/widgets/auth_gate.dart';
import 'package:yening_ecos/features/device_setup/add_device_page.dart';
import 'package:yening_ecos/features/devices/device_details_page.dart';
import 'package:yening_ecos/features/devices/devices_page.dart';
import 'package:yening_ecos/features/devices/models/device_telemetry.dart';
import 'package:yening_ecos/features/devices/models/user_device.dart';
import 'package:yening_ecos/features/devices/services/user_devices_service.dart';
import 'package:yening_ecos/features/profile/data/profile_service.dart';
import 'package:yening_ecos/features/profile/profile_page.dart';

import '../features/devices/support/firebase_fakes.dart';

void main() {
  for (final page in ['Add Device', 'Device details', 'Profile']) {
    testWidgets(
      '$page preserves Devices and Home state through back gestures',
      (tester) async {
        final harness = _Harness();
        await harness.mount(tester);
        addTearDown(harness.dispose);
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar, skipOffstage: false),
            matching: find.text('Devices'),
          ),
        );
        await tester.pumpAndSettle();
        final shellState = tester.state(find.byType(MainNavigationShell));

        Future<void> open() async {
          if (page == 'Profile') {
            await tester.tap(find.byTooltip('Profile'));
          } else {
            await tester.tap(
              find.text(
                page == 'Add Device' ? 'Add Device' : 'EnviroSense Basic',
              ),
            );
          }
          await tester.pumpAndSettle();
        }

        void expectPage() {
          expect(
            find.byType(switch (page) {
              'Add Device' => AddDevicePage,
              'Profile' => ProfilePage,
              _ => DeviceDetailsPage,
            }),
            findsOneWidget,
          );
        }

        void expectDevices() {
          expect(
            tester.state(find.byType(MainNavigationShell, skipOffstage: false)),
            same(shellState),
          );
          expect(
            tester
                .widget<NavigationBar>(
                  find.byType(NavigationBar, skipOffstage: false),
                )
                .selectedIndex,
            1,
          );
          expect(harness.homeStarts, 1);
          expect(harness.homeDisposals, 0);
          expect(harness.auth.streamReads, 1);
          expect(harness.notifications.users, ['owner']);
        }

        await open();
        expectPage();
        // Media/theme/ancestor rebuilds must not replace the signed-in shell.
        harness.rebuild.value++;
        await tester.pump();
        await tester.pumpAndSettle();
        final pageBounds = tester.getRect(find.byType(BackButton));
        await _backGesture(tester, 'startBackGesture');
        await _backGesture(tester, 'updateBackGestureProgress');
        expect(
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .userGestureInProgress,
          isFalse,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.getRect(find.byType(BackButton)),
          pageBounds,
          reason: 'Gesture progress must not move or shrink the page',
        );
        await _backGesture(tester, 'cancelBackGesture');
        await tester.pumpAndSettle();
        expectPage();
        expectDevices();
        if (page == 'Profile') expect(harness.profile.streamReads, 1);
        await _backGesture(tester, 'startBackGesture');
        await _backGesture(tester, 'updateBackGestureProgress');
        expect(
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .userGestureInProgress,
          isFalse,
        );
        await _backGesture(tester, 'commitBackGesture');
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsNothing);
        expectDevices();

        await open();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expectDevices();
        await open();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expectDevices();
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'Home, Devices and Alerts stay fixed during cancelled back gestures',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      addTearDown(harness.dispose);
      for (final section in ['Home', 'Devices', 'Alerts']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(section),
          ),
        );
        await tester.pumpAndSettle();
        final bounds = tester.getRect(find.byType(MainNavigationShell));
        final index = tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .selectedIndex;
        await _backGesture(tester, 'startBackGesture');
        await _backGesture(tester, 'updateBackGestureProgress');
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getRect(find.byType(MainNavigationShell)), bounds);
        await _backGesture(tester, 'cancelBackGesture');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index,
        );
        expect(harness.homeStarts, 1);
      }
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'changing the signed-in account clears the previous shell state',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      addTearDown(harness.dispose);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar, skipOffstage: false),
          matching: find.text('Devices'),
        ),
      );
      await tester.pumpAndSettle();
      harness.auth.events.add(_User('another-owner'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationBar>(
              find.byType(NavigationBar, skipOffstage: false),
            )
            .selectedIndex,
        0,
      );
      expect(harness.homeStarts, 2);
      expect(harness.homeDisposals, 1);
      expect(harness.notifications.users, ['owner', 'another-owner']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Profile keeps its subscription during parent rebuilds', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: harness.rebuild,
        builder: (_, _, _) => MaterialApp(
          home: ProfilePage(
            auth: harness.firebaseAuth,
            authService: harness.auth,
            profileService: harness.profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Owner'), findsNWidgets(2));
    harness.rebuild.value++;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(harness.profile.streamReads, 1);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _backGesture(WidgetTester tester, String method) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(
        method,
        method == 'startBackGesture' || method == 'updateBackGestureProgress'
            ? <String, dynamic>{
                'touchOffset': <double>[5, 300],
                'progress': method == 'startBackGesture' ? 0.0 : 0.4,
                'swipeEdge': 0,
              }
            : null,
      ),
    ),
    (_) {},
  );
  await tester.pump();
}

class _Harness {
  final rebuild = ValueNotifier(0);
  final auth = _Auth();
  final notifications = _Notifications();
  final profile = _Profile();
  final firebaseAuth = TestAuth()..currentUser = _User('owner');
  final units = TemperatureUnitPreference();
  var homeStarts = 0;
  var homeDisposals = 0;

  Future<void> mount(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await units.load();
    const device = UserDevice(
      deviceId: 'device-1',
      deviceName: 'EnviroSense Basic',
      serialNumber: 'SN-001',
      deviceTypeId: 'envirosense_basic_v1',
    );
    List<Widget> pages() => <Widget>[
      _HomeProbe(onStart: () => homeStarts++, onDispose: () => homeDisposals++),
      DevicesPage(
        devicesStream: Stream.value(const UserDevicesState.loaded([device])),
        telemetrySource: (_) => Stream.value(
          DeviceTelemetry(
            temperatureCelsius: 25,
            humidity: 60,
            lightPercent: 75,
            isOnline: true,
            lastSeen: DateTime.now(),
          ),
        ),
        unitPreference: units,
      ),
      const Text('Alerts'),
    ];
    await tester.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: rebuild,
        builder: (_, _, _) => MaterialApp(
          theme: AppTheme.light(),
          home: AuthGate(
            authService: auth,
            notificationRegistrationService: notifications,
            unauthenticatedBuilder: (_) => const Text('Signed out'),
            authenticatedBuilder: (_) => MainNavigationShell(
              authService: auth,
              pages: pages(),
              profileBuilder: (_) => ProfilePage(
                auth: firebaseAuth,
                authService: auth,
                profileService: profile,
              ),
            ),
          ),
        ),
      ),
    );
    auth.events.add(_User('owner'));
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    rebuild.dispose();
    units.dispose();
    await auth.events.close();
    await firebaseAuth.changes.close();
  }
}

class _Auth implements AuthService {
  final events = StreamController<User?>.broadcast();
  var streamReads = 0;
  @override
  Stream<User?> get authStateChanges {
    streamReads++;
    // Match FirebaseAuth: each getter call produces a distinct mapped stream.
    return events.stream.map((user) => user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications implements NotificationRegistrationService {
  final users = <String>[];
  @override
  Future<void> initializeForUser({required String uid}) async => users.add(uid);
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile implements ProfileService {
  var streamReads = 0;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentUserProfile() {
    streamReads++;
    return Stream.value(
      TestDocumentSnapshot({
        'displayName': 'Owner',
        'email': 'owner@example.com',
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User extends TestUser {
  _User(super.uid);
  @override
  String get displayName => 'Owner';
  @override
  String get email => 'owner@example.com';
}

class _HomeProbe extends StatefulWidget {
  const _HomeProbe({required this.onStart, required this.onDispose});
  final VoidCallback onStart;
  final VoidCallback onDispose;
  @override
  State<_HomeProbe> createState() => _HomeProbeState();
}

class _HomeProbeState extends State<_HomeProbe> {
  @override
  void initState() {
    super.initState();
    widget.onStart();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Home content');
}
