import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/app/app.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('App starts with the system ${brightness.name} appearance', (
      tester,
    ) async {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          brightness;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      await tester.pumpWidget(const MyApp());
      expect(find.text('Smart Monitoring'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Smart Monitoring'))).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      // Dispose before the splash's delayed navigation reaches authentication.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
