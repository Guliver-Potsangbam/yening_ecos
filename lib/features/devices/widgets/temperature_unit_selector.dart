import 'package:flutter/material.dart';

import '../../../core/preferences/temperature_unit_preference.dart';

class TemperatureUnitSelector extends StatelessWidget {
  const TemperatureUnitSelector({super.key, this.preference});
  final TemperatureUnitPreference? preference;

  @override
  Widget build(BuildContext context) {
    final units = preference ?? TemperatureUnitPreference.instance;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TemperatureUnit>(
      valueListenable: units,
      builder: (context, unit, _) => SegmentedButton<TemperatureUnit>(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 9),
          ),
          textStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: 0.1)
                : scheme.surfaceContainerLow,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
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
