import 'package:flutter/material.dart';

import '../../../core/preferences/temperature_unit_preference.dart';

class TemperatureUnitSelector extends StatelessWidget {
  const TemperatureUnitSelector({super.key, this.preference});
  final TemperatureUnitPreference? preference;

  @override
  Widget build(BuildContext context) {
    final units = preference ?? TemperatureUnitPreference.instance;
    return ValueListenableBuilder<TemperatureUnit>(
      valueListenable: units,
      builder: (context, unit, _) => SegmentedButton<TemperatureUnit>(
        segments: const [
          ButtonSegment(
            value: TemperatureUnit.celsius,
            label: Text('°C'),
            tooltip: 'Celsius',
          ),
          ButtonSegment(
            value: TemperatureUnit.fahrenheit,
            label: Text('°F'),
            tooltip: 'Fahrenheit',
          ),
        ],
        selected: {unit},
        showSelectedIcon: false,
        onSelectionChanged: (selected) async {
          try {
            await units.setUnit(selected.single);
          } catch (_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unit changed. Your preference could not be saved for next time.',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
