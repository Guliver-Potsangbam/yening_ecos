import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class UserProfileException implements Exception {
  const UserProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Creates the user's profile if it does not already exist.
  ///
  /// For an existing profile, only authentication-owned
  /// fields are synchronized. The Firestore displayName
  /// remains the application profile's source of truth.
  Future<void> ensureProfile({required User user}) async {
    final profileReference = _usersCollection.doc(user.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(profileReference);

        if (snapshot.exists) {
          transaction.update(profileReference, {
            'email': user.email,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return;
        }

        transaction.set(profileReference, {
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw UserProfileException(_messageFor(e));
    }
  }

  /// Updates the application profile stored in Firestore.
  Future<void> updateProfile({
    required User user,
    required String displayName,
  }) async {
    final name = displayName.trim();

    if (name.isEmpty) {
      throw const UserProfileException('Please enter your name.');
    }

    final profileReference = _usersCollection.doc(user.uid);

    try {
      final snapshot = await profileReference.get();

      if (snapshot.exists) {
        await profileReference.update({
          'email': user.email,
          'displayName': name,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return;
      }

      // Recovery path if the profile document
      // somehow does not exist.
      await profileReference.set({
        'email': user.email,
        'displayName': name,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw UserProfileException(_messageFor(e));
    }
  }

  /// Reads the profile once.
  Future<UserProfile?> getProfile(String uid) async {
    try {
      final snapshot = await _usersCollection.doc(uid).get();

      if (!snapshot.exists) {
        return null;
      }

      return UserProfile.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw UserProfileException(_messageFor(e));
    }
  }

  /// Continuously watches the user's Firestore profile.
  ///
  /// Any change to users/{uid} will cause a new
  /// UserProfile to be emitted.
  Stream<UserProfile?> watchProfile(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return UserProfile.fromFirestore(snapshot);
    });
  }

  /// Reads the currently authenticated user's profile once.
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    return getProfile(user.uid);
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to access your profile.';

      case 'unavailable':
        return 'Unable to reach the server. Please check your internet connection.';

      case 'deadline-exceeded':
        return 'The request took too long. Please try again.';

      case 'not-found':
        return 'Your profile could not be found.';

      default:
        return error.message ??
            'Unable to save your profile. Please try again.';
    }
  }
}
