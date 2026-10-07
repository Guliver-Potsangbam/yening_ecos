import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  ProfileService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentUserProfile() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();

    return snapshot.data();
  }

  Future<void> updateProfile({required String displayName}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user is available.');
    }

    final normalizedName = displayName.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    if (normalizedName.length > 100) {
      throw ArgumentError('Display name cannot exceed 100 characters.');
    }

    /*
     * Firestore is the application profile source of truth.
     */
    await _firestore.collection('users').doc(user.uid).set({
      'displayName': normalizedName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    /*
     * Keep Firebase Auth displayName synchronized as secondary
     * account metadata. UI should read the profile from Firestore.
     */
    try {
      await user.updateProfile(displayName: normalizedName);
    } catch (_) {
      /*
       * Firestore has already been successfully updated and is
       * the application source of truth, so an Auth profile sync
       * failure should not make the profile update appear failed.
       */
    }
  }
}
