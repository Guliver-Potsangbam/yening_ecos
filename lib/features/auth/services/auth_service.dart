import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/notifications/notification_registration_service.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    NotificationRegistrationService? notificationRegistrationService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _notificationRegistrationService =
           notificationRegistrationService ??
           NotificationRegistrationService.instance;

  final FirebaseAuth _auth;

  final NotificationRegistrationService _notificationRegistrationService;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<User?> get userChanges => _auth.userChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<User> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const AuthException('No authenticated user was found.');
    }

    final name = displayName.trim();

    if (name.isEmpty) {
      throw const AuthException('Please enter your name.');
    }

    try {
      await user.updateDisplayName(name);
      await user.reload();

      final updatedUser = _auth.currentUser;

      if (updatedUser == null) {
        throw const AuthException(
          'Your account could not be loaded after updating the name.',
        );
      }

      return updatedUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;

    if (user != null) {
      await _notificationRegistrationService.unregisterForUser(uid: user.uid);
    }

    await _auth.signOut();
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'user-not-found':
        return 'No account was found with this email address.';

      case 'wrong-password':
        return 'The password is incorrect.';

      case 'invalid-credential':
        return 'The email or password is incorrect.';

      case 'email-already-in-use':
        return 'An account already exists with this email address.';

      case 'weak-password':
        return 'The password is too weak.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'operation-not-allowed':
        return 'Email and password sign-in is not enabled.';

      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}
