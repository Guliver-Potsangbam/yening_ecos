import 'package:flutter/material.dart';

import '../../../core/preferences/telemetry_target_preference.dart';
import '../../../core/preferences/temperature_unit_preference.dart';
import '../models/telemetry_target_range.dart';

class TelemetryTargetControl extends StatelessWidget {
  const TelemetryTargetControl({
    super.key,
    required this.deviceId,
    required this.metric,
    required this.preference,
    required this.temperatureUnit,
    required this.value,
    required this.isLive,
  });
  final String deviceId;
  final TelemetryMetric metric;
  final TelemetryTargetPreference preference;
  final TemperatureUnit temperatureUnit;
  final double? value;
  final bool isLive;

  String get _unit => metric == TelemetryMetric.temperature
      ? temperatureUnit.symbol
      : metric == TelemetryMetric.humidity
      ? '% RH'
      : '%';
  double _display(double value) => metric == TelemetryMetric.temperature
      ? temperatureUnit.fromCelsius(value)
      : value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = preference.rangeFor(deviceId, metric);
    final valid =
        value != null &&
        value!.isFinite &&
        value! >= metric.minimum &&
        value! <= metric.maximum;
    final position = range == null || !isLive || !valid
        ? null
        : range.position(value!);
    final distance = position == null ? 0.0 : range!.distance(value!);
    final difference = metric == TelemetryMetric.temperature
        ? temperatureUnit.differenceFromCelsius(distance)
        : distance;
    final caption = range == null
        ? 'Set target'
        : position == null
        ? 'Edit target'
        : position == TargetPosition.within
        ? 'Edit target'
        : '${difference < .1 ? '<0.1' : difference.toStringAsFixed(1)} ${metric == TelemetryMetric.temperature ? _unit : 'pp'} ${position == TargetPosition.below ? 'below' : 'above'}';
    final bounds = range == null
        ? 'Not set'
        : '${_display(range.minimum).toStringAsFixed(1)}–${_display(range.maximum).toStringAsFixed(1)} $_unit';
    final color = position == null
        ? theme.colorScheme.onSurfaceVariant
        : position == TargetPosition.within
        ? theme.colorScheme.primary
        : theme.colorScheme.brightness == Brightness.dark
        ? const Color(0xFFF1C179)
        : const Color(0xFF8D5A16);
    void edit() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TargetEditor(
        deviceId: deviceId,
        metric: metric,
        preference: preference,
        temperatureUnit: temperatureUnit,
      ),
    );
    return Semantics(
      button: true,
      label: '${metric.label} target: $bounds. $caption. Edit target.',
      excludeSemantics: true,
      onTap: edit,
      child: InkWell(
        key: ValueKey('edit-target-${metric.name}'),
        onTap: edit,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 48 * MediaQuery.textScalerOf(context).scale(1),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target range',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bounds,
                      key: ValueKey('target-range-${metric.name}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  caption,
                  key: ValueKey('target-distance-${metric.name}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetEditor extends StatefulWidget {
  const _TargetEditor({
    required this.deviceId,
    required this.metric,
    required this.preference,
    required this.temperatureUnit,
  });
  final String deviceId;
  final TelemetryMetric metric;
  final TelemetryTargetPreference preference;
  final TemperatureUnit temperatureUnit;
  @override
  State<_TargetEditor> createState() => _TargetEditorState();
}

class _TargetEditorState extends State<_TargetEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late final TelemetryTargetRange? _original;
  late final String _initialMinimum;
  late final String _initialMaximum;
  bool _saving = false;
  String? _error;
  bool get _temperature => widget.metric == TelemetryMetric.temperature;
  String get _unit => _temperature
      ? widget.temperatureUnit.symbol
      : widget.metric == TelemetryMetric.humidity
      ? '% RH'
      : '%';
  double _display(double value) =>
      _temperature ? widget.temperatureUnit.fromCelsius(value) : value;
  double? _canonical(String text, double? original, String initial) {
    if (original != null && text.trim() == initial) return original;
    final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite) return null;
    return _temperature && widget.temperatureUnit == TemperatureUnit.fahrenheit
        ? (parsed - 32) * 5 / 9
        : parsed;
  }

  double? get _low =>
      _canonical(_minimum.text, _original?.minimum, _initialMinimum);
  double? get _high =>
      _canonical(_maximum.text, _original?.maximum, _initialMaximum);

  @override
  void initState() {
    super.initState();
    _original = widget.preference.rangeFor(widget.deviceId, widget.metric);
    _initialMinimum = _original == null
        ? ''
        : _display(_original.minimum).toStringAsFixed(1);
    _initialMaximum = _original == null
        ? ''
        : _display(_original.maximum).toStringAsFixed(1);
    _minimum = TextEditingController(text: _initialMinimum);
    _maximum = TextEditingController(text: _initialMaximum);
  }

  @override
  void dispose() {
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  String? _validate(double? value) {
    if (value == null) return 'Enter a number';
    if (value < widget.metric.minimum || value > widget.metric.maximum) {
      return 'Use ${_display(widget.metric.minimum).toStringAsFixed(1)}–${_display(widget.metric.maximum).toStringAsFixed(1)} $_unit';
    }
    return null;
  }

  Future<void> _save({bool remove = false}) async {
    if (!remove && !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.preference.setRange(
        widget.deviceId,
        widget.metric,
        remove ? null : TelemetryTargetRange(_low!, _high!),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your target. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.metric.label} target',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close target settings',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the range you want for this environment. Use limits suited to your crop and growth stage.',
              ),
              const SizedBox(height: 8),
              Text(
                'Saved on this phone for your account and this device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.metric == TelemetryMetric.light) ...[
                const SizedBox(height: 8),
                const Text(
                  'Brightness is a relative percentage for this sensor, not lux.',
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('target-minimum'),
                controller: _minimum,
                enabled: !_saving,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: true,
                  signed: _temperature,
                ),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Minimum',
                  suffixText: _unit,
                  border: const OutlineInputBorder(),
                ),
                validator: (_) => _validate(_low),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('target-maximum'),
                controller: _maximum,
                enabled: !_saving,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: true,
                  signed: _temperature,
                ),
                decoration: InputDecoration(
                  labelText: 'Maximum',
                  suffixText: _unit,
                  border: const OutlineInputBorder(),
                ),
                validator: (_) =>
                    _validate(_high) ??
                    (_low != null && _high! <= _low!
                        ? 'Maximum must be greater than minimum'
                        : null),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : () => _save(),
                  child: Text(_saving ? 'Saving…' : 'Save target'),
                ),
              ),
              if (_original != null)
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : () => _save(remove: true),
                    child: const Text('Remove target'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
