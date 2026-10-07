import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/device_setup/models/wifi_network.dart';
import 'package:yening_ecos/features/device_setup/widgets/wifi_network_picker.dart';

void main() {
  const home = WifiNetwork(
    ssid: 'Home',
    rssi: -40,
    isOpen: false,
    isSupported: true,
    security: 'WPA2',
  );
  const office = WifiNetwork(
    ssid: 'Office',
    rssi: -50,
    isOpen: false,
    isSupported: false,
    security: 'Enterprise',
  );

  testWidgets('allows choosing a supported network and requesting a rescan', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    WifiNetwork? chosen;
    var scans = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: WifiNetworkPicker(
              networks: const [home, office],
              selected: null,
              manualEntry: false,
              scanning: false,
              enabled: true,
              ssidController: controller,
              onSelected: (value) => chosen = value,
              onScan: () => scans++,
              onToggleManual: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Scan again'));
    expect(scans, 1);
    await tester.tap(find.byType(DropdownButton<WifiNetwork>));
    await tester.pumpAndSettle();
    final unsupportedItem = find
        .byWidgetPredicate(
          (widget) =>
              widget is DropdownMenuItem<WifiNetwork> && widget.value == office,
        )
        .last;
    expect(
      tester.widget<DropdownMenuItem<WifiNetwork>>(unsupportedItem).enabled,
      isFalse,
    );
    await tester.tap(find.textContaining('Home · Strong').last);
    await tester.pumpAndSettle();
    expect(chosen, home);
  });

  testWidgets('keeps manual entry available when scanning is unsupported', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: WifiNetworkPicker(
              networks: const [],
              selected: null,
              manualEntry: true,
              scanning: false,
              enabled: true,
              ssidController: controller,
              onSelected: (_) {},
              onScan: () {},
              onToggleManual: () {},
              scanMessage: 'Enter the Wi-Fi name.',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Enter the Wi-Fi name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' Home ');
    expect(controller.text, ' Home ');
  });

  testWidgets('disables scan requests and network edits while scanning', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var scans = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: WifiNetworkPicker(
              networks: const [home],
              selected: null,
              manualEntry: true,
              scanning: true,
              enabled: true,
              ssidController: controller,
              onSelected: (_) {},
              onScan: () => scans++,
              onToggleManual: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Scanning…'));
    expect(scans, 0);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
  });
}
