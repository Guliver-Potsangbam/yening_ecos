import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/devices/models/telemetry_target_range.dart';

/// On-phone monitoring targets scoped to the signed-in account and device.
/// This is shared by Home and Device Details; it does not create cloud writes.
class TelemetryTargetPreference extends ChangeNotifier {
  TelemetryTargetPreference({
    String? Function()? currentUserUid,
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _currentUserUid = currentUserUid ?? _firebaseUid,
       _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static final instance = TelemetryTargetPreference();
  final String? Function() _currentUserUid;
  final Future<SharedPreferences> Function() _loadPreferences;
  final _cache = <String, Map<TelemetryMetric, TelemetryTargetRange>>{};
  final _loads = <String, Future<void>>{};
  Future<void> _writes = Future.value();
  bool _disposed = false;

  static String? _firebaseUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String? _key(String deviceId) {
    final uid = _currentUserUid();
    if (uid == null || uid.isEmpty || deviceId.isEmpty) return null;
    return 'telemetry_targets_v1.${jsonEncode([uid, deviceId])}';
  }

  TelemetryTargetRange? rangeFor(String deviceId, TelemetryMetric metric) =>
      _cache[_key(deviceId)]?[metric];

  Future<void> load(String deviceId) async {
    final key = _key(deviceId);
    if (key == null || _cache.containsKey(key)) return;
    try {
      await _loads.putIfAbsent(key, () async {
        try {
          final preferences = await _loadPreferences();
          // A completed save wins over an earlier in-flight read.
          _cache.putIfAbsent(key, () => _decode(preferences.getString(key)));
          if (!_disposed) notifyListeners();
        } catch (_) {
          // Targets remain unset when local storage cannot be read. Saving still
          // reports a failure, rather than displaying a range that was not saved.
        }
      });
    } finally {
      _loads.remove(key);
    }
  }

  Future<void> setRange(
    String deviceId,
    TelemetryMetric metric,
    TelemetryTargetRange? range,
  ) {
    final key = _key(deviceId);
    if (key == null) {
      return Future.error(StateError('Sign in to save a target.'));
    }
    if (range != null && !range.isValidFor(metric)) {
      return Future.error(ArgumentError('Invalid target range.'));
    }
    // Serialize edits across views; each write reads the latest complete record.
    _writes = _writes.catchError((Object _) {}).then((_) async {
      final preferences = await _loadPreferences();
      final ranges = _decode(preferences.getString(key));
      if (range == null) {
        ranges.remove(metric);
      } else {
        ranges[metric] = range;
      }
      final saved = await preferences.setString(
        key,
        jsonEncode({
          'version': 1,
          'ranges': {
            for (final entry in ranges.entries)
              entry.key.name: entry.value.toJson(),
          },
        }),
      );
      if (!saved) throw StateError('Target could not be saved.');
      _cache[key] = Map.unmodifiable(ranges);
      if (!_disposed) notifyListeners();
    });
    return _writes;
  }

  Map<TelemetryMetric, TelemetryTargetRange> _decode(String? text) {
    try {
      final data = text == null ? null : jsonDecode(text);
      if (data is! Map || data['version'] != 1 || data['ranges'] is! Map) {
        return {};
      }
      final result = <TelemetryMetric, TelemetryTargetRange>{};
      for (final metric in TelemetryMetric.values) {
        final range = TelemetryTargetRange.fromJson(
          data['ranges'][metric.name],
          metric,
        );
        if (range != null) result[metric] = range;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
