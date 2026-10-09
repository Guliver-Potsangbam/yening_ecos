import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/preferences/temperature_unit_preference.dart';
import '../../../core/preferences/telemetry_target_preference.dart';
import '../../../core/ui/local_time_format.dart';
import '../models/device_telemetry.dart';
import '../models/user_device.dart';
import 'user_device_card.dart';
import '../models/telemetry_target_range.dart';
import 'telemetry_target_control.dart';
import '../services/device_telemetry_service.dart';
import 'telemetry_gauge.dart';
import 'temperature_unit_selector.dart';

class DeviceTelemetryPanel extends StatefulWidget {
  const DeviceTelemetryPanel({
    super.key,
    required this.deviceId,
    this.telemetrySource,
    this.device,
    this.onDeviceTap,
    this.showSerialNumber = true,
    this.unitPreference,
    this.targetPreference,
    this.now,
  });
  final String deviceId;
  final UserDevice? device;
  final VoidCallback? onDeviceTap;
  final bool showSerialNumber;
  final DeviceTelemetrySource? telemetrySource;
  final TemperatureUnitPreference? unitPreference;
  final TelemetryTargetPreference? targetPreference;
  final DateTime Function()? now;

  @override
  State<DeviceTelemetryPanel> createState() => _DeviceTelemetryPanelState();
}

class _DeviceTelemetryPanelState extends State<DeviceTelemetryPanel> {
  late Stream<DeviceTelemetry> _readings;
  Timer? _freshnessTimer;
  TelemetryTargetPreference get _targets =>
      widget.targetPreference ?? TelemetryTargetPreference.instance;
  TemperatureUnitPreference get _units =>
      widget.unitPreference ?? TemperatureUnitPreference.instance;

  @override
  void initState() {
    super.initState();
    _watch();
    unawaited(_targets.load(widget.deviceId));
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
        oldWidget.targetPreference != widget.targetPreference) {
      unawaited(_targets.load(widget.deviceId));
    }
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
    DateTime now,
  ) {
    final connection = reading.connectionStateAt(now);
    if (connection == DeviceConnectionState.reconnecting) return 'Reconnecting';
    if (connection == DeviceConnectionState.offline) return 'Offline';
    if (value == null || !value.isFinite || updatedAt == null) return 'Waiting';
    return fresh ? 'Live' : 'Stale';
  }

  String _metricStatus(
    TelemetryMetric metric,
    DeviceTelemetry reading,
    DateTime now,
  ) {
    final sample = switch (metric) {
      TelemetryMetric.temperature => (
        reading.temperatureCelsius,
        reading.temperatureUpdatedAt,
        reading.isTemperatureFreshAt(now),
      ),
      TelemetryMetric.humidity => (
        reading.humidity,
        reading.humidityUpdatedAt,
        reading.isHumidityFreshAt(now),
      ),
      TelemetryMetric.light => (
        reading.lightPercent,
        reading.lightUpdatedAt,
        reading.isLightFreshAt(now),
      ),
    };
    return _sensorStatus(reading, sample.$1, sample.$2, sample.$3, now);
  }

  Widget _targetControl(
    TelemetryMetric metric,
    TemperatureUnit unit,
    DeviceTelemetry reading,
    DateTime now,
  ) => TelemetryTargetControl(
    deviceId: widget.deviceId,
    metric: metric,
    preference: _targets,
    temperatureUnit: unit,
    value: switch (metric) {
      TelemetryMetric.temperature => reading.temperatureCelsius,
      TelemetryMetric.humidity => reading.humidity,
      TelemetryMetric.light => reading.lightPercent,
    },
    isLive: _metricStatus(metric, reading, now) == 'Live',
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviceTelemetry>(
      stream: _readings,
      builder: (context, snapshot) {
        final now = widget.now?.call() ?? DateTime.now();
        final reading =
            !snapshot.hasError &&
                snapshot.connectionState != ConnectionState.waiting
            ? snapshot.data
            : null;
        final details = _connectionDetails(
          context,
          reading,
          now,
          hasError: snapshot.hasError,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.device != null)
              UserDeviceCard(
                device: widget.device!,
                showSerialNumber: widget.showSerialNumber,
                onTap: widget.onDeviceTap,
                connectionDetails: details,
              )
            else
              details,
            const SizedBox(height: 14),
            _buildReadings(context, snapshot, now),
          ],
        );
      },
    );
  }

  Widget _connectionDetails(
    BuildContext context,
    DeviceTelemetry? reading,
    DateTime now, {
    required bool hasError,
  }) {
    final theme = Theme.of(context);
    final state = reading?.connectionStateAt(now);
    final label = hasError
        ? 'Connection unavailable'
        : reading == null
        ? 'Checking connection'
        : switch (state!) {
            DeviceConnectionState.online => 'Device online',
            DeviceConnectionState.offline => 'Device offline',
            DeviceConnectionState.reconnecting =>
              'Reconnecting to live readings',
            DeviceConnectionState.waiting =>
              reading.hasReadings
                  ? 'Waiting for device'
                  : 'Waiting for readings',
          };
    final dark = theme.brightness == Brightness.dark;
    final color = state == DeviceConnectionState.offline
        ? (dark ? const Color(0xFFF1C179) : const Color(0xFF8D5A16))
        : state == DeviceConnectionState.online
        ? (dark ? const Color(0xFF79DCCB) : const Color(0xFF176D60))
        : theme.colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          key: const ValueKey('device-connection-status'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state == DeviceConnectionState.offline
                    ? Icons.wifi_off_rounded
                    : Icons.sensors_rounded,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (reading?.lastSeen != null &&
            reading!.lastSeen!.millisecondsSinceEpoch > 0)
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
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReadings(
    BuildContext context,
    AsyncSnapshot<DeviceTelemetry> snapshot,
    DateTime now,
  ) {
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
    if (snapshot.connectionState == ConnectionState.waiting ||
        !snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final reading = snapshot.data!;
    final theme = Theme.of(context);
    final offline =
        reading.connectionStateAt(now) == DeviceConnectionState.offline;
    return AnimatedBuilder(
      animation: _targets,
      builder: (context, _) => ValueListenableBuilder<TemperatureUnit>(
        valueListenable: _units,
        builder: (context, unit, _) => Column(
          key: const ValueKey('sensor-readings-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sensor readings',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (offline) ...[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('offline-readings-notice'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color:
                        (theme.brightness == Brightness.dark
                                ? const Color(0xFFF1C179)
                                : const Color(0xFF8D5A16))
                            .withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 24,
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFFF1C179)
                          : const Color(0xFF8D5A16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Updates paused',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Showing last received values, not current conditions.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                // Equal compact rows on phones; equal columns when all
                // three meters fit comfortably, including large text.
                final columns = constraints.maxWidth >= 240 * textScale * 3 + 24
                    ? 3
                    : 1;
                final horizontal =
                    columns == 1 && constraints.maxWidth >= 320 * textScale;
                final temperature = TelemetryGauge(
                  key: const ValueKey('temperature-meter'),
                  label: 'Temperature',
                  targetRange: _targets
                      .rangeFor(widget.deviceId, TelemetryMetric.temperature)
                      ?.converted(unit.fromCelsius),
                  targetControl: _targetControl(
                    TelemetryMetric.temperature,
                    unit,
                    reading,
                    now,
                  ),
                  subtitle: 'Air temperature',
                  explanation: 'Air temperature. Use °C or °F to choose the display unit.',
                  semanticUnit: unit.symbol == '°C' ? 'Celsius' : 'Fahrenheit',
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
                  freshnessLabel: _metricStatus(
                    TelemetryMetric.temperature,
                    reading,
                    now,
                  ),
                );
                final humidity = TelemetryGauge(
                  key: const ValueKey('humidity-meter'),
                  label: 'Humidity',
                  targetRange: _targets.rangeFor(
                    widget.deviceId,
                    TelemetryMetric.humidity,
                  ),
                  targetControl: _targetControl(
                    TelemetryMetric.humidity,
                    unit,
                    reading,
                    now,
                  ),
                  subtitle: 'Relative humidity',
                  explanation: 'Relative humidity compares moisture in the air with saturation at the current temperature.',
                  semanticUnit: 'percent relative humidity',
                  value: reading.humidity,
                  horizontal: horizontal,
                  updatedAt: reading.humidityUpdatedAt,
                  updatedAtKey: const ValueKey('humidity-updated-time'),
                  freshnessLabel: _metricStatus(
                    TelemetryMetric.humidity,
                    reading,
                    now,
                  ),
                  unit: '% RH',
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
                  targetRange: _targets.rangeFor(
                    widget.deviceId,
                    TelemetryMetric.light,
                  ),
                  targetControl: _targetControl(
                    TelemetryMetric.light,
                    unit,
                    reading,
                    now,
                  ),
                  subtitle: 'Relative brightness',
                  explanation: 'Relative brightness between the sensor’s dark (0%) and bright (100%) reference levels. This percentage is not a lux measurement.',
                  semanticUnit: 'percent relative brightness',
                  statusLabel: reading.lightLabel,
                  value: reading.lightPercent,
                  horizontal: horizontal,
                  updatedAt: reading.lightUpdatedAt,
                  updatedAtKey: const ValueKey('light-updated-time'),
                  freshnessLabel: _metricStatus(
                    TelemetryMetric.light,
                    reading,
                    now,
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
      ),
    );
  }
}
