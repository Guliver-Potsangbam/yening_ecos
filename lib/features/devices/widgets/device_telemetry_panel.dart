import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/preferences/temperature_unit_preference.dart';
import '../../../core/ui/local_time_format.dart';
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
    _freshnessTimer = Timer.periodic(const Duration(seconds: 2), (_) {
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

  String _sensorStatus(
    DeviceTelemetry reading,
    double? value,
    DateTime? updatedAt,
    bool fresh,
  ) {
    if (value == null || !value.isFinite || updatedAt == null) return 'Waiting';
    if (reading.isCloudConnected == false) return 'Reconnecting';
    if (reading.isOnline == false) return 'Offline';
    return fresh ? 'Live' : 'Stale';
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
            ? 'Device online'
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
                    'Sensor readings',
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
                  if (reading.lastSeen != null &&
                      reading.lastSeen!.millisecondsSinceEpoch > 0)
                    Tooltip(
                      message:
                          'Device connection heartbeat · ${formatLocalDateTime12(reading.lastSeen!)}',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Device seen: ${formatLocalTime12(reading.lastSeen!)}',
                              key: const ValueKey('telemetry-updated-time'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
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
                  // Equal compact rows on phones; equal columns when all
                  // three meters fit comfortably, including large text.
                  final columns =
                      constraints.maxWidth >= 240 * textScale * 3 + 24 ? 3 : 1;
                  final horizontal =
                      columns == 1 && constraints.maxWidth >= 320 * textScale;
                  final now = DateTime.now();
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
                    horizontal: horizontal,
                    updatedAt: reading.temperatureUpdatedAt,
                    updatedAtKey: const ValueKey('temperature-updated-time'),
                    freshnessLabel: _sensorStatus(
                      reading,
                      reading.temperatureCelsius,
                      reading.temperatureUpdatedAt,
                      reading.isTemperatureFreshAt(now),
                    ),
                  );
                  final humidity = TelemetryGauge(
                    key: const ValueKey('humidity-meter'),
                    label: 'Humidity',
                    value: reading.humidity,
                    horizontal: horizontal,
                    updatedAt: reading.humidityUpdatedAt,
                    updatedAtKey: const ValueKey('humidity-updated-time'),
                    freshnessLabel: _sensorStatus(
                      reading,
                      reading.humidity,
                      reading.humidityUpdatedAt,
                      reading.isHumidityFreshAt(now),
                    ),
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
                    horizontal: horizontal,
                    updatedAt: reading.lightUpdatedAt,
                    updatedAtKey: const ValueKey('light-updated-time'),
                    freshnessLabel: _sensorStatus(
                      reading,
                      reading.lightPercent,
                      reading.lightUpdatedAt,
                      reading.isLightFreshAt(now),
                    ),
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
                      SizedBox(width: gaugeWidth, child: temperature),
                      SizedBox(width: gaugeWidth, child: humidity),
                      SizedBox(width: gaugeWidth, child: light),
                    ],
                  );
                },
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
