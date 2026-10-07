import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/preferences/temperature_unit_preference.dart';
import '../models/device_telemetry.dart';
import '../services/device_telemetry_service.dart';
import 'telemetry_gauge.dart';
import 'temperature_unit_selector.dart';

class DeviceTelemetryPanel extends StatefulWidget {
  const DeviceTelemetryPanel({
    super.key,
    required this.deviceId,
    this.telemetrySource,
    this.unitPreference,
  });
  final String deviceId;
  final DeviceTelemetrySource? telemetrySource;
  final TemperatureUnitPreference? unitPreference;

  @override
  State<DeviceTelemetryPanel> createState() => _DeviceTelemetryPanelState();
}

class _DeviceTelemetryPanelState extends State<DeviceTelemetryPanel> {
  late Stream<DeviceTelemetry> _readings;
  Timer? _freshnessTimer;
  TemperatureUnitPreference get _units =>
      widget.unitPreference ?? TemperatureUnitPreference.instance;

  @override
  void initState() {
    super.initState();
    _watch();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  void _watch() {
    try {
      _readings =
          (widget.telemetrySource ?? DeviceTelemetryService().watchDevice)(
            widget.deviceId,
          );
    } catch (error, stack) {
      _readings = Stream.error(error, stack);
    }
  }

  @override
  void didUpdateWidget(DeviceTelemetryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId ||
        oldWidget.telemetrySource != widget.telemetrySource) {
      _watch();
    }
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    super.dispose();
  }

  String _updatedAt(DateTime? seen) {
    if (seen == null) return 'Waiting for a device update';
    final age = DateTime.now().difference(seen);
    if (age.inSeconds < 1) return 'Updated just now';
    if (age.inSeconds < 60) return 'Updated ${age.inSeconds}s ago';
    if (age.inMinutes < 60) return 'Updated ${age.inMinutes}m ago';
    if (age.inHours < 24) return 'Updated ${age.inHours}h ago';
    return 'Updated ${age.inDays}d ago';
  }

  String _updateTime(DateTime seen) {
    final local = seen.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'Last update: ${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviceTelemetry>(
      stream: _readings,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final denied =
              error is FirebaseException && error.code == 'permission-denied';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                denied ? 'Your account cannot access this device’s readings.' : 'Unable to load live readings. Check your internet connection.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(_watch),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry readings'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final reading = snapshot.data!;
        final theme = Theme.of(context);
        final fresh = reading.isFreshAt(DateTime.now());
        final status = !reading.hasReadings
            ? 'Waiting for readings'
            : reading.isCloudConnected == false
            ? 'Reconnecting to live readings'
            : reading.isOnline == false
            ? 'Offline'
            : fresh
            ? 'Live'
            : 'No recent updates';
        return ValueListenableBuilder<TemperatureUnit>(
          valueListenable: _units,
          builder: (context, unit, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Measurements',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (fresh && reading.hasReadings
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant)
                              .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: fresh && reading.hasReadings
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            status,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final minimumWidth = 136 * textScale;
                  final columns =
                      constraints.maxWidth >= 600 &&
                          constraints.maxWidth >= minimumWidth * 3 + 24
                      ? 3
                      : constraints.maxWidth >= minimumWidth * 2 + 12
                      ? 2
                      : 1;
                  final temperature = TelemetryGauge(
                    key: const ValueKey('temperature-meter'),
                    label: 'Temperature',
                    value: reading.temperatureCelsius == null
                        ? null
                        : unit.fromCelsius(reading.temperatureCelsius!),
                    unit: unit.symbol,
                    minimum: unit.fromCelsius(-40),
                    maximum: unit.fromCelsius(80),
                    lowThreshold: unit.fromCelsius(20),
                    highThreshold: unit.fromCelsius(35),
                    color: const Color(0xFF218A72),
                    icon: Icons.thermostat_rounded,
                    trailing: TemperatureUnitSelector(preference: _units),
                    horizontal:
                        columns < 3 && constraints.maxWidth >= 300 * textScale,
                  );
                  final humidity = TelemetryGauge(
                    key: const ValueKey('humidity-meter'),
                    label: 'Humidity',
                    value: reading.humidity,
                    unit: '%',
                    minimum: 0,
                    maximum: 100,
                    lowThreshold: 40,
                    highThreshold: 70,
                    color: const Color(0xFF218A72),
                    icon: Icons.water_drop_rounded,
                  );
                  final light = TelemetryGauge(
                    key: const ValueKey('light-meter'),
                    label: 'Light',
                    statusLabel: reading.lightLabel,
                    value: reading.lightPercent,
                    unit: '%',
                    minimum: 0,
                    maximum: 100,
                    lowThreshold: 23,
                    highThreshold: 45,
                    lowColor: const Color(0xFF64748B),
                    color: const Color(0xFF218A72),
                    icon: Icons.light_mode_rounded,
                  );
                  final gaugeWidth =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: columns == 2 ? constraints.maxWidth : gaugeWidth,
                        child: temperature,
                      ),
                      SizedBox(width: gaugeWidth, child: humidity),
                      SizedBox(width: gaugeWidth, child: light),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    _updatedAt(reading.lastSeen),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (reading.lastSeen != null &&
                      reading.lastSeen!.millisecondsSinceEpoch > 0)
                    Text(
                      _updateTime(reading.lastSeen!),
                      key: const ValueKey('telemetry-updated-time'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (!reading.hasReadings) ...[
                const SizedBox(height: 16),
                const Text(
                  'Readings will appear when your device sends its first sensor update.',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
