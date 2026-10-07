import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/device_details.dart';

typedef DeviceDetailsSource = Stream<DeviceDetailsState> Function(
  String deviceId,
);
typedef DeviceMetadataDocumentSource = Stream<Map<String, dynamic>?> Function(
  String collection,
  String documentId,
);

class DeviceDetailsState {
  const DeviceDetailsState.loading()
    : isLoading = true,
      details = null,
      typeLoading = false,
      typeUnavailable = false,
      message = null;

  const DeviceDetailsState.ready(
    this.details, {
    this.typeLoading = false,
    this.typeUnavailable = false,
  }) : isLoading = false,
       message = null;

  const DeviceDetailsState.unavailable({
    this.message = 'Device information is unavailable. Please try again.',
  }) : isLoading = false,
       details = null,
       typeLoading = false,
       typeUnavailable = false;

  final bool isLoading;
  final DeviceDetails? details;
  final bool typeLoading;
  final bool typeUnavailable;
  final String? message;
}

/// Device and model documents stay live independently from the RTDB readings.
/// A model lookup failure can never interrupt the telemetry subscription.
class DeviceDetailsService {
  DeviceDetailsService({
    this._firestore,
    this._auth,
    this._documentSource,
    this._accountChanges,
  });

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final DeviceMetadataDocumentSource? _documentSource;
  final Stream<String?>? _accountChanges;

  Stream<Map<String, dynamic>?> _document(String collection, String id) {
    if (_documentSource != null) return _documentSource(collection, id);
    return (_firestore ?? FirebaseFirestore.instance)
        .collection(collection)
        .doc(id)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  Stream<DeviceDetailsState> watchDevice(String deviceId) {
    final accounts =
        _accountChanges ??
        (_auth ?? FirebaseAuth.instance).authStateChanges().map(
          (user) => user?.uid,
        );
    return Stream<DeviceDetailsState>.multi((controller) {
      StreamSubscription<String?>? accountSubscription;
      StreamSubscription<Map<String, dynamic>?>? deviceSubscription;
      StreamSubscription<Map<String, dynamic>?>? typeSubscription;
      var active = true;
      var deviceGeneration = 0;
      var typeGeneration = 0;
      Map<String, dynamic>? deviceData;
      Map<String, dynamic>? typeData;
      String? typeId;
      var typeLoading = false;
      var typeUnavailable = false;

      void clearType() {
        ++typeGeneration;
        final old = typeSubscription;
        typeSubscription = null;
        if (old != null) unawaited(old.cancel());
        typeId = null;
        typeData = null;
        typeLoading = false;
        typeUnavailable = false;
      }

      void publish() {
        if (!active || deviceData == null) return;
        controller.add(
          DeviceDetailsState.ready(
            DeviceDetails.fromMaps(
              documentId: deviceId,
              deviceData: deviceData!,
              typeData: typeData,
            ),
            typeLoading: typeLoading,
            typeUnavailable: typeUnavailable,
          ),
        );
      }

      void unavailable(String message) {
        deviceData = null;
        clearType();
        if (active) {
          controller.add(DeviceDetailsState.unavailable(message: message));
        }
      }

      accountSubscription = accounts.distinct().listen(
        (uid) {
          final generation = ++deviceGeneration;
          final old = deviceSubscription;
          deviceSubscription = null;
          if (old != null) unawaited(old.cancel());
          deviceData = null;
          clearType();
          if (uid == null || deviceId.isEmpty || deviceId.contains('/')) {
            unavailable(
              'Device information is no longer available for this account.',
            );
            return;
          }
          controller.add(const DeviceDetailsState.loading());
          try {
            deviceSubscription = _document('devices', deviceId).listen(
              (data) {
                if (!active || generation != deviceGeneration) return;
                // Clear prior data if ownership is removed or a cached unclaimed
                // record arrives while an account or document changes.
                if (data == null ||
                    data['claimedByUid'] != uid ||
                    data['status'] == 'unclaimed') {
                  unavailable(
                    'Device information is no longer available for this account.',
                  );
                  return;
                }
                deviceData = data;
                final rawType = data['deviceTypeId'];
                final nextType = rawType is String ? rawType.trim() : '';
                if (typeId != nextType) {
                  clearType();
                  typeId = nextType;
                  if (nextType.isNotEmpty && !nextType.contains('/')) {
                    typeLoading = true;
                    final modelGeneration = typeGeneration;
                    try {
                      typeSubscription = _document('deviceTypes', nextType)
                          .listen(
                            (model) {
                              if (!active ||
                                  generation != deviceGeneration ||
                                  modelGeneration != typeGeneration) {
                                return;
                              }
                              typeLoading = false;
                              typeData = model;
                              typeUnavailable = model == null;
                              publish();
                            },
                            onError: (Object error) {
                              if (!active ||
                                  generation != deviceGeneration ||
                                  modelGeneration != typeGeneration) {
                                return;
                              }
                              typeLoading = false;
                              typeData = null;
                              typeUnavailable = true;
                              publish();
                            },
                          );
                    } catch (_) {
                      typeLoading = false;
                      typeUnavailable = true;
                    }
                  } else {
                    typeUnavailable = true;
                  }
                }
                publish();
              },
              onError: (Object error) {
                if (active && generation == deviceGeneration) {
                  unavailable(
                    'Device information could not be loaded. Check your connection and retry.',
                  );
                }
              },
            );
          } catch (_) {
            unavailable(
              'Device information could not be loaded. Please retry.',
            );
          }
        },
        onError: (Object error) {
          ++deviceGeneration;
          final old = deviceSubscription;
          deviceSubscription = null;
          if (old != null) unawaited(old.cancel());
          unavailable(
            'Device information is unavailable. Please sign in again.',
          );
        },
      );

      controller.onCancel = () async {
        active = false;
        ++deviceGeneration;
        ++typeGeneration;
        await accountSubscription?.cancel();
        await deviceSubscription?.cancel();
        await typeSubscription?.cancel();
      };
    });
  }
}
