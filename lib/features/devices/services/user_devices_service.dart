import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_device.dart';

class UserDevicesState {
  const UserDevicesState.loading() : isLoading = true, devices = const [];
  const UserDevicesState.loaded(this.devices) : isLoading = false;

  final bool isLoading;
  final List<UserDevice> devices;
}

class UserDevicesService {
  UserDevicesService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<UserDevicesState> watchCurrentUserDevices() {
    return Stream<UserDevicesState>.multi((controller) {
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? devices;
      var generation = 0;

      final auth = _auth
          .authStateChanges()
          .map((user) => user?.uid)
          .distinct()
          .listen((uid) {
            final currentGeneration = ++generation;
            final previous = devices;
            devices = null;
            if (previous != null) unawaited(previous.cancel());

            if (uid == null) {
              controller.add(const UserDevicesState.loaded([]));
              return;
            }
            // Clear the previous account's data while the new query loads.
            controller.add(const UserDevicesState.loading());
            // Registry ownership is authoritative. An older claim can lack the
            // denormalized users/{uid}/devices entry while still being owned.
            devices = _firestore
                .collection('devices')
                .where('claimedByUid', isEqualTo: uid)
                .snapshots()
                .listen(
                  (snapshot) {
                    if (currentGeneration != generation) return;
                    final owned = snapshot.docs
                        .map((doc) => UserDevice.fromMap(doc.id, doc.data()))
                        .toList();
                    owned.sort((a, b) {
                      final name = a.deviceName.toLowerCase().compareTo(
                        b.deviceName.toLowerCase(),
                      );
                      return name == 0
                          ? a.deviceId.compareTo(b.deviceId)
                          : name;
                    });
                    controller.add(
                      UserDevicesState.loaded(List.unmodifiable(owned)),
                    );
                  },
                  onError: (Object error, StackTrace stack) {
                    if (currentGeneration == generation) {
                      controller.addError(error, stack);
                    }
                  },
                );
          }, onError: controller.addError);

      controller.onCancel = () async {
        ++generation;
        await auth.cancel();
        await devices?.cancel();
      };
    });
  }
}
