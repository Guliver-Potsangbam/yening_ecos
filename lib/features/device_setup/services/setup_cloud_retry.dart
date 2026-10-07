import 'dart:async';

/// Allows read operations to recover while cloud connections reopen after
/// leaving the device AP. Validation and permission errors fail immediately.
Future<T> retrySetupCloudRead<T>(
  Future<T> Function() read, {
  required bool Function(Object) isRetryable,
  bool Function()? isCancelled,
  Duration retryDelay = const Duration(seconds: 1),
  Duration attemptTimeout = const Duration(seconds: 6),
  int maxAttempts = 3,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (isCancelled?.call() == true) {
      throw StateError('Device verification was cancelled.');
    }
    try {
      return await read().timeout(attemptTimeout);
    } catch (error) {
      if (attempt == maxAttempts - 1 || !isRetryable(error)) rethrow;
    }
    await Future<void>.delayed(retryDelay * (attempt + 1));
  }
  throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Must be positive.');
}
