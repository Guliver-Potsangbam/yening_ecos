import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/device_setup/services/setup_cloud_retry.dart';

void main() {
  bool retryable(Object error) =>
      error is TimeoutException ||
      (error is FirebaseException &&
          (error.code == 'unavailable' || error.code == 'deadline-exceeded'));

  test(
    'retries temporary cloud disconnects while connections recover',
    () async {
      var calls = 0;
      final result = await retrySetupCloudRead(
        () async {
          calls++;
          if (calls < 3) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          }
          return 'registered-device';
        },
        isRetryable: retryable,
        retryDelay: Duration.zero,
      );
      expect(result, 'registered-device');
      expect(calls, 3);
    },
  );

  test('never retries denied access to registry records', () async {
    var calls = 0;
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await expectLater(
      retrySetupCloudRead(
        () async {
          calls++;
          throw error;
        },
        isRetryable: retryable,
        retryDelay: Duration.zero,
      ),
      throwsA(same(error)),
    );
    expect(calls, 1);
  });

  test('bounds attempts and preserves the final cloud failure', () async {
    var calls = 0;
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'deadline-exceeded',
    );
    await expectLater(
      retrySetupCloudRead(
        () async {
          calls++;
          throw error;
        },
        isRetryable: retryable,
        retryDelay: Duration.zero,
      ),
      throwsA(same(error)),
    );
    expect(calls, 3);
  });

  test('recovers from a read timeout without hanging verification', () async {
    var calls = 0;
    final pending = Completer<String>();
    final result = await retrySetupCloudRead(
      () {
        calls++;
        return calls == 1 ? pending.future : Future.value('registered-device');
      },
      isRetryable: retryable,
      retryDelay: Duration.zero,
      attemptTimeout: const Duration(milliseconds: 10),
    );
    expect(result, 'registered-device');
    expect(calls, 2);
    pending.complete('late-result');
  });

  test('does not issue further cloud reads when setup is closed', () async {
    var calls = 0;
    await expectLater(
      retrySetupCloudRead(
        () async {
          calls++;
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        },
        isRetryable: retryable,
        retryDelay: Duration.zero,
        isCancelled: () => calls > 0,
      ),
      throwsStateError,
    );
    expect(calls, 1);
  });
}
