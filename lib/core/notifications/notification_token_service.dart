import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationTokenService {
  NotificationTokenService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _tokensCollection(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notificationTokens');
  }

  Future<void> saveToken({
    required String uid,
    required String installationId,
    required String token,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedInstallationId = installationId.trim();
    final normalizedToken = token.trim();

    if (normalizedUid.isEmpty ||
        normalizedInstallationId.isEmpty ||
        normalizedToken.isEmpty) {
      return;
    }

    await _tokensCollection(normalizedUid).doc(normalizedInstallationId).set({
      'token': normalizedToken,
      'platform': _platformName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeToken({
    required String uid,
    required String installationId,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedInstallationId = installationId.trim();

    if (normalizedUid.isEmpty || normalizedInstallationId.isEmpty) {
      return;
    }

    await _tokensCollection(normalizedUid)
        .doc(normalizedInstallationId)
        .delete();
  }

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
