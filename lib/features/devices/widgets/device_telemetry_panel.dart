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
    _freshnessTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
    if (age.inSeconds < 10) return 'Updated just now';
    if (age.inSeconds < 60) return 'Updated ${age.inSeconds}s ago';
    if (age.inMinutes < 60) return 'Updated ${age.inMinutes}m ago';
    if (age.inHours < 24) return 'Updated ${age.inHours}h ago';
    return 'Updated ${age.inDays}d ago';
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
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sensor readings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TemperatureUnitSelector(preference: _units),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: fresh && reading.hasReadings
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(status, style: theme.textTheme.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _updatedAt(reading.lastSeen),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final temperature = TelemetryGauge(
                    label: 'Temperature',
                    value: reading.temperatureCelsius == null
                        ? null
                        : unit.fromCelsius(reading.temperatureCelsius!),
                    unit: unit.symbol,
                    minimum: unit.fromCelsius(-40),
                    maximum: unit.fromCelsius(80),
                    color: Colors.deepOrange,
                    icon: Icons.thermostat_rounded,
                  );
                  final humidity = TelemetryGauge(
                    label: 'Humidity',
                    value: reading.humidity,
                    unit: '%',
                    minimum: 0,
                    maximum: 100,
                    color: Colors.blue,
                    icon: Icons.water_drop_rounded,
                  );
                  if (constraints.maxWidth < 280) {
                    return Column(
                      children: [
                        temperature,
                        const SizedBox(height: 20),
                        humidity,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: temperature),
                      const SizedBox(width: 16),
                      Expanded(child: humidity),
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
